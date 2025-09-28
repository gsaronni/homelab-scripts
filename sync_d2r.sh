#!/bin/bash
# Diablo II Resurrected Save Game Sync Script
# Version: 1.0
# Date: 20250928
# Description: Synchronizes Diablo II Resurrected save games between local and remote servers
# Supports granular per-file syncing for multi-character gaming across machines

# Set strict error handling
set -euo pipefail

# Parse command line arguments for dry run mode
DRY_RUN=false  # Default to live mode
for arg in "$@"; do
  case $arg in
    -n|--dry)
      DRY_RUN=true
      ;;
    *)
      echo "Usage: $0 [-n|--dry]"
      echo "  -n, --dry: Run in dry-run mode"
      echo "  (default: live mode - performs actual sync operations)"
      exit 1
      ;;
  esac
done

# ==============================================
# CONFIGURATION
# ==============================================

# Script metadata
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="v1.0"
readonly SCRIPT_DATE="20250928"

# Remote server configuration
readonly REMOTE_HOST="zimacopy"
readonly REMOTE_IP="192.168.1.212"

# Hardcoded paths for Diablo II Resurrected
readonly LOCAL_SAVE_PATH="/mnt/c/Users/greintek/Saved Games/Diablo II Resurrected/"
readonly REMOTE_SAVE_PATH="/mnt/luoyang/bck/zimablade/svgm/diablo2resurrected"

# Log configuration
readonly LOG_DIR="/mnt/d/gaming/scr/logs"
readonly LOG_FILE="${LOG_DIR}/$(date +%Y.%m.%d.%H.%M.%S)_sync_d2r.log"

# Backup configuration
readonly BACKUP_DIR="${LOCAL_SAVE_PATH}/backups"
readonly BACKUP_RETENTION=3  # Keep versions per file

# Rsync configuration
readonly RSYNC_CMD="rsync"
readonly RSYNC_OPTS="--log-file=${LOG_FILE}" 
readonly RSYNC_FLAGS="-avhiPm${DRY_RUN:+n}"  # Adds 'n' if DRY_RUN is true

# Skip list for files that should not be synced
readonly SKIP_PATTERNS=("Settings.json")

# File type descriptions for logging
declare -A FILE_DESCRIPTIONS=(
    [".d2s"]="Character Save Data"
    [".ctl"]="Character Control File"
    [".ma0"]="Character Map Data"
    [".key"]="Character Key Bindings"
    [".map"]="Character Map Info"
    [".d2i"]="Shared Stash Data"
)

# ==============================================
# LOGGING FUNCTIONS
# ==============================================

# Log levels
readonly LOG_INFO="INFO"
readonly LOG_WARNING="WARNING" 
readonly LOG_ERROR="ERROR"

# Make sure log directory exists
mkdir -p "${LOG_DIR}"

log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  
  echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

log_info() {
  log "${LOG_INFO}" "$1"
}

log_warning() {
  log "${LOG_WARNING}" "$1" >&2
}

log_error() {
  log "${LOG_ERROR}" "$1" >&2
}

error_exit() {
  log_error "$1"
  exit 1
}

# Clean up old log files (120 days retention)
cleanup_old_logs() {
  log_info "Checking for old log files (120+ days) in ${LOG_DIR}"
  local oldest_log=$(find "${LOG_DIR}" -name "*_sync_d2r.log" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | head -1 | cut -d' ' -f2-)
  
  if [ -n "$oldest_log" ]; then
    local oldest_date=$(stat -c %y "$oldest_log" | cut -d' ' -f1)
    local cleanup_date=$(date -d "+120 days" '+%Y-%m-%d')
    log_info "Oldest log is from: ${oldest_date}, no logs to delete until: ${cleanup_date}"
    
    local old_logs=$(find "${LOG_DIR}" -name "*_sync_d2r.log" -mtime +120 2>/dev/null)
    if [ -n "$old_logs" ]; then
      old_log_count=$(echo "$old_logs" | wc -l)
      log_info "Deleting ${old_log_count} old log files"
      find "${LOG_DIR}" -name "*_sync_d2r.log" -mtime +120 -delete 2>/dev/null
    fi
  else
    log_info "No existing D2R log files found"
  fi
}

# ==============================================
# HELPER FUNCTIONS
# ==============================================

# Check connectivity to remote host
check_remote_connectivity() {
  log_info "Testing connection to ${REMOTE_HOST} (${REMOTE_IP})"
  
  # Check if host is pingable
  if ! ping -c 1 "${REMOTE_IP}" &> /dev/null; then
    log_error "Cannot ping ${REMOTE_HOST} at ${REMOTE_IP}"
    cat << "EOF"
 _____      _ _          _   _ 
|  ___|___ (_) | ___  __| | | |
| |_ / _` || | |/ _ \/ _` | | |
|  _| (_| || | |  __/ (_| | |_|
|_|  \__,_||_|_|\___|\__,_| (_)
EOF
    return 1
  fi
  
  # Check SSH connectivity
  if ! ssh -q "${REMOTE_HOST}" "echo Connection successful" &> /dev/null; then
    log_error "SSH connection to ${REMOTE_HOST} failed"
    return 1
  fi
  
  # Check if rsync is available on remote
  if ! ssh -q "${REMOTE_HOST}" "command -v rsync &> /dev/null"; then
    log_error "rsync not found on ${REMOTE_HOST}"
    return 1
  fi
  
  log_info "Connection to ${REMOTE_HOST} successful"
  cat << "EOF"
 ____  ____  ____    ____                        _ 
|  _ \|___ \|  _ \  / ___| _   _ _ __   ___ _ __| |
| | | | __) | |_) | \___ \| | | | '_ \ / __| '__| |
| |_| |/ __/|  _ <   ___) | |_| | | | | (__| |  |_|
|____/|_____|_| \_\ |____/ \__, |_| |_|\___|_|  (_)
                           |___/                   
EOF
  return 0
}

# Ensure a directory exists (both local and remote)
ensure_directory_exists() {
  local dir="$1"
  local is_remote="$2"  # true or false
  
  if [ "${is_remote}" = "true" ]; then
    log_info "Checking if ${dir} exists on remote server"
    if ssh "${REMOTE_HOST}" "[ -d \"${dir}\" ]"; then
      log_info "Directory ${dir} exists on remote server"
    else
      log_info "Directory ${dir} does not exist on remote server. Creating..."
      if ! ssh "${REMOTE_HOST}" "mkdir -p \"${dir}\""; then
        log_error "Failed to create directory ${dir} on remote server"
        return 1
      fi
      log_info "Directory ${dir} created successfully on remote server"
    fi
  else
    log_info "Checking if ${dir} exists locally"
    if [ -d "${dir}" ]; then
      log_info "Directory ${dir} exists locally"
    else
      log_info "Directory ${dir} does not exist locally. Creating..."
      if ! mkdir -p "${dir}"; then
        log_error "Failed to create directory ${dir} locally"
        return 1
      fi
      log_info "Directory ${dir} created successfully locally"
    fi
  fi
  
  return 0
}

# Get file description based on extension
get_file_description() {
  local filename="$1"
  local extension="${filename##*.}"
  local basename="${filename%.*}"
  
  # Handle special cases
  if [[ "$filename" == "SharedStash"* ]]; then
    if [[ "$filename" == *"SoftCore"* ]]; then
      echo "Shared Stash (Softcore)"
    elif [[ "$filename" == *"HardCore"* ]]; then
      echo "Shared Stash (Hardcore)"
    else
      echo "Shared Stash"
    fi
  elif [[ -n "${FILE_DESCRIPTIONS[.${extension}]}" ]]; then
    echo "${basename} - ${FILE_DESCRIPTIONS[.${extension}]}"
  else
    echo "${filename} - Unknown File Type"
  fi
}

# Create progressive backup of a file
create_backup() {
  if [ "$DRY_RUN" = true ]; then
    log_info "Dry-run mode: Skipping backup creation"
    return 0
  fi
  local filepath="$1"
  local filename=$(basename "$filepath")
  local timestamp=$(date '+%Y%m%d.%H%M%S')
  local backup_file="${BACKUP_DIR}/${filename}.backup.${timestamp}"
  
  # Ensure backup directory exists
  mkdir -p "${BACKUP_DIR}"
  
  if [ -f "$filepath" ]; then
    cp "$filepath" "$backup_file"
    log_info "Created backup: ${backup_file}"
    
    # Clean up old backups for this file (keep only last BACKUP_RETENTION versions)
    local file_backups=$(find "${BACKUP_DIR}" -name "${filename}.backup.*" -type f -printf '%T@ %p\n' | sort -n | cut -d' ' -f2-)
    local backup_count=$(echo "$file_backups" | wc -l)
    
    if [ "$backup_count" -gt "$BACKUP_RETENTION" ]; then
      local to_delete=$((backup_count - BACKUP_RETENTION))
      echo "$file_backups" | head -n "$to_delete" | while read -r old_backup; do
        rm -f "$old_backup"
        log_info "Removed old backup: $(basename "$old_backup")"
      done
    fi
  fi
}

# Get file size in a human-readable format
get_file_size() {
  local filepath="$1"
  local is_remote="$2"
  
  if [ "${is_remote}" = "true" ]; then
    ssh "${REMOTE_HOST}" "stat -c %s '${filepath}' 2>/dev/null" | numfmt --to=iec 2>/dev/null || echo "0"
  else
    stat -c %s "${filepath}" 2>/dev/null | numfmt --to=iec 2>/dev/null || echo "0"
  fi
}

# Check if file should be skipped
should_skip_file() {
  local filename="$1"
  
  for pattern in "${SKIP_PATTERNS[@]}"; do
    if [[ "$filename" == $pattern ]]; then
      return 0  # Skip this file
    fi
  done
  return 1  # Don't skip
}

# Granular file sync - compares and syncs individual files
granular_file_sync() {
  local local_file="$1"
  local remote_file="$2"
  local filename=$(basename "$local_file")
  local file_desc=$(get_file_description "$filename")
  
  log_info "===== Analyzing ${filename} (${file_desc}) ====="
  
  if should_skip_file "$filename"; then
    log_info "${filename}: Skipping (matches skip pattern) - ${file_desc}"
    return 0
  fi

  # Check if files exist
  local local_exists=false
  local remote_exists=false
  
  [ -f "$local_file" ] && local_exists=true
  ssh "${REMOTE_HOST}" "[ -f '${remote_file}' ]" 2>/dev/null && remote_exists=true
  
  # Handle cases where files don't exist on one side
  if [ "$local_exists" = false ] && [ "$remote_exists" = false ]; then
    log_info "${filename}: No file exists locally or remotely - skipping"
    return 0
  elif [ "$local_exists" = false ] && [ "$remote_exists" = true ]; then
    log_info "${filename}: File exists only on remote - syncing to local"
    local remote_size=$(get_file_size "$remote_file" "true")
    log_info "Remote file size: ${remote_size}"
    ${RSYNC_CMD} ${RSYNC_FLAGS} "${REMOTE_HOST}:${remote_file}" "$local_file" ${RSYNC_OPTS}
    return 0
  elif [ "$local_exists" = true ] && [ "$remote_exists" = false ]; then
    log_info "${filename}: File exists only locally - syncing to remote"
    local local_size=$(get_file_size "$local_file" "false")
    log_info "Local file size: ${local_size}"
    create_backup "$local_file"
    ${RSYNC_CMD} ${RSYNC_FLAGS} "$local_file" "${REMOTE_HOST}:${remote_file}" ${RSYNC_OPTS}
    return 0
  fi
  
  # Both files exist - compare timestamps and sizes
  local local_time=$(stat -c %Y "$local_file")
  local local_time_human=$(stat -c %y "$local_file")
  local local_size=$(get_file_size "$local_file" "false")
  
  local remote_time=$(ssh "${REMOTE_HOST}" "stat -c %Y '${remote_file}'")
  local remote_time_human=$(ssh "${REMOTE_HOST}" "stat -c %y '${remote_file}'")
  local remote_size=$(get_file_size "$remote_file" "true")
  
  log_info "Local:  ${local_time_human} | Size: ${local_size}"
  log_info "Remote: ${remote_time_human} | Size: ${remote_size}"
  
  # Compare timestamps and sync accordingly
  if [ "${local_time}" -gt "${remote_time}" ]; then
    log_info "${filename}: Local file is newer - syncing to remote"
    create_backup "$local_file"
    ${RSYNC_CMD} ${RSYNC_FLAGS} "$local_file" "${REMOTE_HOST}:${remote_file}" ${RSYNC_OPTS}
  elif [ "${local_time}" -lt "${remote_time}" ]; then
    log_info "${filename}: Remote file is newer - syncing to local"
    create_backup "$local_file"
    ${RSYNC_CMD} ${RSYNC_FLAGS} "${REMOTE_HOST}:${remote_file}" "$local_file" ${RSYNC_OPTS}
  else
    log_info "${filename}: Files have identical timestamps - no sync needed"
    # Double-check sizes for paranoia
    if [ "$local_size" != "$remote_size" ]; then
      log_warning "${filename}: Same timestamp but different sizes! Local: ${local_size}, Remote: ${remote_size}"
    fi
  fi
}

# Sync all Diablo II Resurrected save files granularly
sync_d2r_saves() {
  log_info "===== Starting granular Diablo II Resurrected save sync ====="
  
  # Get list of all save files in local directory
  local all_files=()
  
  # Add existing local files (all files except directories)
  if [ -d "$LOCAL_SAVE_PATH" ]; then
    while IFS= read -r -d '' file; do
      all_files+=("$(basename "$file")")
    done < <(find "$LOCAL_SAVE_PATH" -maxdepth 1 -type f -print0 2>/dev/null || true)
  fi
  
  # Add existing remote files
  local remote_files=$(ssh "${REMOTE_HOST}" "find '${REMOTE_SAVE_PATH}' -maxdepth 1 -type f -printf '%f\\n' 2>/dev/null || true")
  if [ -n "$remote_files" ]; then
    while IFS= read -r file; do
      # Only add if not already in array
      if [[ ! " ${all_files[@]} " =~ " ${file} " ]]; then
        all_files+=("$file")
      fi
    done <<< "$remote_files"
  fi
  
  log_info "Found ${#all_files[@]} unique save files to analyze"
  
  # Sync each file individually
  for filename in "${all_files[@]}"; do
    local local_file="${LOCAL_SAVE_PATH}/${filename}"
    local remote_file="${REMOTE_SAVE_PATH}/${filename}"
    granular_file_sync "$local_file" "$remote_file"
  done
  
  log_info "===== Granular sync completed ====="
}

# ==============================================
# MAIN SCRIPT
# ==============================================

main() {
  log_info "==== Starting ${SCRIPT_NAME} ${SCRIPT_VERSION} (${SCRIPT_DATE}) ===="
  log_info "Local save path: ${LOCAL_SAVE_PATH}"
  log_info "Remote save path: ${REMOTE_SAVE_PATH}"
  
  # Run mode indicator
  if [ "$DRY_RUN" = true ]; then
    log_info "*** RUNNING IN DRY-RUN MODE - NO CHANGES WILL BE MADE ***"
  else
    log_info "*** LIVE MODE - CHANGES WILL BE APPLIED ***"
  fi

  # Clean up old logs first
  cleanup_old_logs
  
  # Check remote connectivity
  if ! check_remote_connectivity; then
    error_exit "Failed to connect to remote server"
  fi
  
  # Ensure directories exist
  ensure_directory_exists "${LOCAL_SAVE_PATH}" "false" || error_exit "Failed to verify or create local save path"
  ensure_directory_exists "${REMOTE_SAVE_PATH}" "true" || error_exit "Failed to verify or create remote save path"
  ensure_directory_exists "${BACKUP_DIR}" "false" || error_exit "Failed to verify or create backup directory"
  
  # Perform granular sync
  sync_d2r_saves
  
  log_info "==== Diablo II Resurrected sync completed successfully ===="
  if [ "$DRY_RUN" = true ]; then
    log_info "REMINDER: Script ran in DRY-RUN mode - no files were actually modified"
  fi
}

# Run the main function
main