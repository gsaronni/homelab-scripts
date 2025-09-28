#!/bin/bash
# BG3 Save Game Sync Script
# Version: 3.3
# Added log retention
# Added backup copies
# Date: 20250421
# Description: Synchronizes Baldur's Gate 3 save games between local and remote servers

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
readonly SCRIPT_VERSION="v3.3"
readonly SCRIPT_DATE="20250421"

# Remote server configuration
readonly REMOTE_HOST="zimacopy"
readonly REMOTE_IP="192.168.1.212"

# Detect user - consolidated function used for both logging and paths
detect_user() {
  if [ -d "/mnt/c/Users/Mujika" ]; then
    echo "Mujika"
  elif [ -d "/mnt/c/Users/owlcub" ]; then
    echo "owlcub"
  else
    echo "unknown"
  fi
}

# Get username for logging and paths
readonly DETECTED_USER=$(detect_user)

# Log configuration
readonly LOG_DIR="/mnt/d/gaming/scr/logs"
readonly LOG_FILE="${LOG_DIR}/$(date +%Y.%m.%d.%H.%M.%S)_sync_BG3Lu_${DETECTED_USER}.log"

# Rsync configuration
readonly RSYNC_CMD="rsync"
readonly RSYNC_OPTS="--delete --log-file=${LOG_FILE}" 
readonly RSYNC_FLAGS="-avhiPm$([[ "$DRY_RUN" == "true" ]] && echo "n")"

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
log_info "Checking for old log files (120+ days) in ${LOG_DIR}"
oldest_log=$(find "${LOG_DIR}" -name "*.log" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | head -1 | cut -d' ' -f2-)
if [ -n "$oldest_log" ]; then
  oldest_date=$(stat -c %y "$oldest_log" | cut -d' ' -f1)
  cleanup_date=$(date -d "+120 days" '+%Y-%m-%d')
  log_info "Oldest log is from: ${oldest_date}, no logs to delete until: ${cleanup_date}"
  
  old_logs=$(find "${LOG_DIR}" -name "*.log" -mtime +120 2>/dev/null)
  if [ -n "$old_logs" ]; then
    old_log_count=$(echo "$old_logs" | wc -l)
    log_info "Deleting ${old_log_count} old log files"
    find "${LOG_DIR}" -name "*.log" -mtime +120 -delete 2>/dev/null
  fi
else
  log_info "No existing log files found"
fi

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
 _  _    ___  _  _   
| || |  / _ \| || |  
| || |_| | | | || |_ 
|__   _| |_| |__   _|
   |_|  \___/   |_|  
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
     _                 _     _           _      
 ___(_)_ __ ___   __ _| |__ | | __ _  __| | ___ 
|_  / | '_ ` _ \ / _` | '_ \| |/ _` |/ _` |/ _ \
 / /| | | | | | | (_| | |_) | | (_| | (_| |  __/
/___|_|_| |_| |_|\__,_|_.__/|_|\__,_|\__,_|\___|
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

# Create backup of save files using simple copy
create_backup() {
  if [ "$DRY_RUN" = true ]; then
    log_info "Dry-run mode: Skipping backup creation for ${1}"
    return 0
  fi
  
  local source_path="$1"
  local backup_name="$2"
  local timestamp=$(date '+%Y%m%d.%H%M%S')
  local backup_base_dir="/mnt/c/Users/${DETECTED_USER}/Documents/BG3_Backups"
  local backup_dir="${backup_base_dir}/${backup_name}"
  local backup_folder="${backup_dir}/backup_${timestamp}"
  
  # Only create backup if source has files
  if [ ! -d "$source_path" ] || [ "$(find "$source_path" -type f 2>/dev/null | wc -l)" -eq 0 ]; then
    log_info "No files to backup in ${source_path}"
    return 0
  fi
  
  mkdir -p "$backup_dir"
  
  log_info "Creating backup: ${backup_folder}"
  if cp -r "$source_path" "$backup_folder" 2>/dev/null; then
    log_info "Backup created successfully: ${backup_folder}"
  else
    log_warning "Failed to create backup of ${source_path}"
    return 1
  fi
  
  # Clean up old backups (keep last 3)
  local retention=3
  local backups=($(find "$backup_dir" -maxdepth 1 -type d -name "backup_*" -printf '%T@ %p\n' | sort -n | cut -d' ' -f2-))
  
  if [ ${#backups[@]} -gt $retention ]; then
    local to_delete=$((${#backups[@]} - retention))
    log_info "Cleaning up ${to_delete} old backups (keeping last ${retention})"
    for ((i=0; i<to_delete; i++)); do
      rm -rf "${backups[$i]}"
      log_info "Removed old backup: $(basename "${backups[$i]}")"
    done
  fi
}

# Compare timestamps and sync in the appropriate direction
compare_and_sync() {
  local local_dir="$1"
  local remote_dir="$2"
  local dir_name="$3"  # Just for logging (e.g., "saves" or "mods")
  
  # Ensure both directories exist
  ensure_directory_exists "${local_dir}" "false"
  ensure_directory_exists "${remote_dir}" "true"
  
  # Check if directories have content
  local local_file_count=$(find "${local_dir}" -type f 2>/dev/null | wc -l)
  local remote_file_count=$(ssh "${REMOTE_HOST}" "find '${remote_dir}' -type f 2>/dev/null | wc -l")
  
  log_info "Local ${dir_name} contains ${local_file_count} files"
  log_info "Remote ${dir_name} contains ${remote_file_count} files"
  
  # Handle empty directory cases
  if [ "${local_file_count}" -eq 0 ] && [ "${remote_file_count}" -gt 0 ]; then
    log_info "Local ${dir_name} is empty but remote has files, syncing from remote"
    create_backup "${local_dir}" "${dir_name}_local"
    ${RSYNC_CMD} ${RSYNC_FLAGS} "${REMOTE_HOST}:${remote_dir%/}/" "${local_dir}" ${RSYNC_OPTS}
    return
  elif [ "${local_file_count}" -gt 0 ] && [ "${remote_file_count}" -eq 0 ]; then
    log_info "Remote ${dir_name} is empty but local has files, syncing from local"
    create_backup "${local_dir}" "${dir_name}_local"
    ${RSYNC_CMD} ${RSYNC_FLAGS} "${local_dir%/}/" "${REMOTE_HOST}:${remote_dir}" ${RSYNC_OPTS}
    return
  elif [ "${local_file_count}" -eq 0 ] && [ "${remote_file_count}" -eq 0 ]; then
    log_info "Both ${dir_name} directories are empty, nothing to sync"
    return
  fi
  
  # Get modification times of the most recent files (not directories)
  local local_time=0
  local local_time_human="No files found"
  local local_latest_file="No files found"
  
  if [ "${local_file_count}" -gt 0 ]; then
    local latest_local_file=$(find "${local_dir}" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)
    local_time=$(stat -c %Y "${latest_local_file}")
    local_time_human=$(stat -c %y "${latest_local_file}")
    local_latest_file=$(ls -l "${latest_local_file}")
  fi
  
  local remote_time=0
  local remote_time_human="No files found"
  local remote_latest_file="No files found"
  
  if [ "${remote_file_count}" -gt 0 ]; then
    local latest_remote_file=$(ssh "${REMOTE_HOST}" "find '${remote_dir}' -type f -printf '%T@ %p\\n' | sort -n | tail -1 | cut -d' ' -f2-")
    remote_time=$(ssh "${REMOTE_HOST}" "stat -c %Y '${latest_remote_file}'")
    remote_time_human=$(ssh "${REMOTE_HOST}" "stat -c %y '${latest_remote_file}'")
    remote_latest_file=$(ssh "${REMOTE_HOST}" "ls -l '${latest_remote_file}'")
  fi
  
  # Log the times for comparison
  log_info "Local ${dir_name} latest file timestamp: ${local_time} (${local_time_human})"
  log_info "Local latest file: ${local_latest_file}"
  log_info "Remote ${dir_name} latest file timestamp: ${remote_time} (${remote_time_human})"
  log_info "Remote latest file: ${remote_latest_file}"
  
  # Compare and sync based on the most recent file timestamps
  if [ "${local_time}" -gt "${remote_time}" ]; then
    log_info "Local ${dir_name} files more recent, syncing to remote"
    create_backup "${local_dir}" "${dir_name}_local"
    ${RSYNC_CMD} ${RSYNC_FLAGS} "${local_dir%/}/" "${REMOTE_HOST}:${remote_dir}" ${RSYNC_OPTS}
  elif [ "${local_time}" -lt "${remote_time}" ]; then
    log_info "Remote ${dir_name} files more recent, syncing to local"
    create_backup "${local_dir}" "${dir_name}_local"
    ${RSYNC_CMD} ${RSYNC_FLAGS} "${REMOTE_HOST}:${remote_dir%/}/" "${local_dir}" ${RSYNC_OPTS}
  else
    log_info "Both ${dir_name} directories have files with the same timestamps, nothing to sync"
  fi
}

# ==============================================
# MAIN SCRIPT
# ==============================================

main() {
  log_info "==== Starting ${SCRIPT_NAME} ${SCRIPT_VERSION} (${SCRIPT_DATE}) ===="
  log_info "Detected user: ${DETECTED_USER}"
  
  # Handle "unknown" user case
  if [ "${DETECTED_USER}" = "unknown" ]; then
    log_error "Could not detect supported user profile (only Mujika and owlcub are supported)."
    cat << "EOF"
 _   _       _                                _   _           _     _ _ _ 
| | | |_ __ | | ___ __   _____      ___ __   | | | | ___  ___| |_  | | | |
| | | | '_ \| |/ / '_ \ / _ \ \ /\ / / '_ \  | |_| |/ _ \/ __| __| | | | |
| |_| | | | |   <| | | | (_) \ V  V /| | | | |  _  | (_) \__ \ |_  |_|_|_|
 \___/|_| |_|_|\_\_| |_|\___/ \_/\_/ |_| |_| |_| |_|\___/|___/\__| (_|_|_)
EOF
    error_exit "Script only supports Mujika and owlcub user profiles. Exiting."
  fi
  
  # Define paths
  readonly LOCAL_BASE_PATH="/mnt/c/Users/${DETECTED_USER}/AppData/Local/Larian Studios/Baldur's Gate 3"
  readonly REMOTE_BASE_PATH="/mnt/luoyang/bck/zimablade/svgm/baldursGate3Lu"
  readonly SAVES_PATH="PlayerProfiles/Public/Savegames/Story"
  readonly MODS_PATH="Mods"
  
  # Check remote connectivity
  if ! check_remote_connectivity; then
    error_exit "Failed to connect to remote server"
  fi
  
  # Ensure base directories exist
  ensure_directory_exists "${LOCAL_BASE_PATH}" "false" || error_exit "Failed to verify or create local base path"
  ensure_directory_exists "${REMOTE_BASE_PATH}" "true" || error_exit "Failed to verify or create remote base path"
  
  # Ensure full path directories exist (now handled in compare_and_sync)
  
  # Run mode indicator
  if [ "$DRY_RUN" = true ]; then
    log_info "*** RUNNING IN DRY-RUN MODE - NO CHANGES WILL BE MADE ***"
  else
    log_info "*** LIVE MODE - CHANGES WILL BE APPLIED ***"
  fi

  # Sync saves
  log_info "===== Synchronizing saves ====="
  compare_and_sync "${LOCAL_BASE_PATH}/${SAVES_PATH}" "${REMOTE_BASE_PATH}/${SAVES_PATH}" "saves"
  
  # Sync mods
  log_info "===== Synchronizing mods ====="
  compare_and_sync "${LOCAL_BASE_PATH}/${MODS_PATH}" "${REMOTE_BASE_PATH}/${MODS_PATH}" "mods"
  
  log_info "==== Sync completed successfully ===="
  if [ "$DRY_RUN" = true ]; then
    log_info "REMINDER: Script ran in DRY-RUN mode - no files were actually modified"
  fi
}

# Run the main function
main

#sed -i 's/\r$//' sync_BG3_lu.sh