#!/bin/bash
# Auto Game Save Sync Script
# Version: 1.0
# Date: 20250928
# Description: Automatically detects installed games and syncs save files using JSON database
# Supports Steam, GOG, Epic Games, and BattleNet

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

# Game installation paths
readonly GAMES_BASE_PATH="/mnt/d/vdg"
readonly GAME_DB_FILE="$(dirname "$0")/game_database.json"

# Store-specific paths
declare -A STORE_PATHS=(
    ["Steam"]="${GAMES_BASE_PATH}/Steam/steamapps/common"
    ["GOG"]="${GAMES_BASE_PATH}/GOG"
    ["EpicGames"]="${GAMES_BASE_PATH}/EpicGames"
    ["BattleNet"]="${GAMES_BASE_PATH}/BattleNet"
)

# Folders to ignore when scanning for games
readonly IGNORE_FOLDERS=("dwd" "download" "downloads" "temp" "cache" "backup" "backups")

# Detect user - must be hardcoded for each machine
detect_user() {
  if [ -d "/mnt/c/Users/greintek" ]; then
    echo "greintek"
  elif [ -d "/mnt/c/Users/Mujika" ]; then
    echo "Mujika"
  elif [ -d "/mnt/c/Users/owlcub" ]; then
    echo "owlcub"
  else
    echo "unknown"
  fi
}

# Get username for paths
readonly DETECTED_USER=$(detect_user)

# Windows paths based on detected user
readonly wBlade="/mnt/c"
readonly wBlade_u="$wBlade/Users/$DETECTED_USER"
readonly wBlade_uL="$wBlade_u/AppData/Local"
readonly wBlade_uR="$wBlade_u/AppData/Roaming"
readonly wBlade_d="$wBlade_u/Documents"
readonly wBlade_dMy="$wBlade_d/My Games"
readonly wBlade_S="$wBlade_u/Saved Games"

# Remote base path
readonly REMOTE_BASE_PATH="/mnt/luoyang/bck/zimablade/svgm"

# Log configuration
readonly LOG_DIR="/mnt/d/gaming/scr/logs"
readonly LOG_FILE="${LOG_DIR}/$(date +%Y.%m.%d.%H.%M.%S)_auto_game_sync_${DETECTED_USER}.log"

# Backup configuration
readonly BACKUP_DIR="${wBlade_d}/GameSyncBackups"
readonly BACKUP_RETENTION=3

# Rsync configuration
readonly RSYNC_CMD="rsync"
readonly RSYNC_OPTS="--log-file=${LOG_FILE}" 
readonly RSYNC_FLAGS="-avhiPm${DRY_RUN:+n}"

# ==============================================
# LOGGING FUNCTIONS
# ==============================================

readonly LOG_INFO="INFO"
readonly LOG_WARNING="WARNING" 
readonly LOG_ERROR="ERROR"

mkdir -p "${LOG_DIR}"

log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  
  echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

log_info() { log "${LOG_INFO}" "$1"; }
log_warning() { log "${LOG_WARNING}" "$1" >&2; }
log_error() { log "${LOG_ERROR}" "$1" >&2; }

error_exit() {
  log_error "$1"
  exit 1
}

# Clean up old log files
cleanup_old_logs() {
  log_info "Checking for old log files (120+ days) in ${LOG_DIR}"
  
  local old_logs=$(find "${LOG_DIR}" -name "*_auto_game_sync_*.log" -mtime +120 2>/dev/null)
  if [ -n "$old_logs" ]; then
    local old_log_count=$(echo "$old_logs" | wc -l)
    log_info "Deleting ${old_log_count} old log files"
    find "${LOG_DIR}" -name "*_auto_game_sync_*.log" -mtime +120 -delete 2>/dev/null
  else
    log_info "No old log files found (older than 120 days)"
  fi
}

# ==============================================
# HELPER FUNCTIONS
# ==============================================

# Check if required tools are available
check_dependencies() {
  if ! command -v jq &> /dev/null; then
    log_error "jq is required but not installed."
    log_error "Install with: sudo apt-get install jq"
    error_exit "Missing dependency: jq"
  fi
  
  if ! command -v bc &> /dev/null; then
    log_error "bc is required but not installed."
    log_error "Install with: sudo apt-get install bc"
    error_exit "Missing dependency: bc"
  fi
}

# Check if game database exists
check_database_exists() {
  if [ ! -f "$GAME_DB_FILE" ]; then
    log_error "Game database not found: ${GAME_DB_FILE}"
    log_error "Please create the game database file first."
    error_exit "Missing game database file. Exiting."
  fi
}

# Check connectivity to remote host
check_remote_connectivity() {
  log_info "Testing connection to ${REMOTE_HOST} (${REMOTE_IP})"
  
  if ! ping -c 1 "${REMOTE_IP}" &> /dev/null; then
    log_error "Cannot ping ${REMOTE_HOST} at ${REMOTE_IP}"
    return 1
  fi
  
  if ! ssh -q "${REMOTE_HOST}" "echo Connection successful" &> /dev/null; then
    log_error "SSH connection to ${REMOTE_HOST} failed"
    return 1
  fi
  
  if ! ssh -q "${REMOTE_HOST}" "command -v rsync &> /dev/null"; then
    log_error "rsync not found on ${REMOTE_HOST}"
    return 1
  fi
  
  log_info "Connection to ${REMOTE_HOST} successful"
  return 0
}

# Scan for installed games in a specific store
scan_store_games() {
  local store="$1"
  local store_path="${STORE_PATHS[$store]}"
  local games=()
  
  if [ ! -d "$store_path" ]; then
    log_warning "Store path ${store_path} not found for ${store}"
    return
  fi
  
  log_info "Scanning ${store} games in ${store_path}"
  
  # Find all subdirectories (game folders), excluding ignored folders
  while IFS= read -r -d '' game_folder; do
    local game_name=$(basename "$game_folder")
    
    # Skip ignored folders
    local skip=false
    for ignore_pattern in "${IGNORE_FOLDERS[@]}"; do
      if [[ "$game_name" == "$ignore_pattern" ]]; then
        skip=true
        break
      fi
    done
    
    if [ "$skip" = false ]; then
      games+=("$game_name")
    fi
  done < <(find "$store_path" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null || true)
  
  log_info "Found ${#games[@]} games in ${store}: ${games[*]}"
  
  # Return games array (bash doesn't support returning arrays, so we'll use global)
  declare -g -a "FOUND_GAMES_${store}=(\"\${games[@]}\")"
}

# Expand variables in path (like $wBlade_uR)
expand_path_variables() {
  local path="$1"
  # Replace path variables
  path="${path//\$wBlade_uR/$wBlade_uR}"
  path="${path//\$wBlade_uL/$wBlade_uL}"
  path="${path//\$wBlade_d/$wBlade_d}"
  path="${path//\$wBlade_dMy/$wBlade_dMy}"
  path="${path//\$wBlade_S/$wBlade_S}"
  path="${path//\$wBlade_u/$wBlade_u}"
  path="${path//\$wBlade/$wBlade}"
  echo "$path"
}

# Create backup of save files
create_backup() {
  if [ "$DRY_RUN" = true ]; then
    log_info "Dry-run mode: Skipping backup creation"
    return 0
  fi
  
  local save_path="$1"
  local game_name="$2"
  local timestamp=$(date '+%Y%m%d.%H%M%S')
  local backup_dir="${BACKUP_DIR}/${game_name}"
  local backup_file="${backup_dir}/backup_${timestamp}.tar.gz"
  
  mkdir -p "$backup_dir"
  
  if [ -d "$save_path" ] && [ "$(find "$save_path" -type f | head -1)" ]; then
    tar -czf "$backup_file" -C "$(dirname "$save_path")" "$(basename "$save_path")" 2>/dev/null
    log_info "Created backup: ${backup_file}"
    
    # Clean up old backups
    local backups=($(find "$backup_dir" -name "backup_*.tar.gz" -printf '%T@ %p\n' | sort -n | cut -d' ' -f2-))
    if [ ${#backups[@]} -gt $BACKUP_RETENTION ]; then
      local to_delete=$((${#backups[@]} - BACKUP_RETENTION))
      for ((i=0; i<to_delete; i++)); do
        rm -f "${backups[$i]}"
        log_info "Removed old backup: $(basename "${backups[$i]}")"
      done
    fi
  fi
}

# Sync game saves bidirectionally
sync_game_saves() {
  local game_name="$1"
  local platform="$2"
  local save_path="$3"
  local remote_folder="$4"
  
  local expanded_save_path=$(expand_path_variables "$save_path")
  local remote_path="${REMOTE_BASE_PATH}/${remote_folder}"
  
  log_info "===== Syncing ${game_name} (${platform}) ====="
  log_info "Local path: ${expanded_save_path}"
  log_info "Remote path: ${remote_path}"
  
  # Check if local save path exists
  if [ ! -d "$expanded_save_path" ]; then
    log_warning "Local save path does not exist: ${expanded_save_path}"
    log_info "Creating local directory and syncing from remote if available"
    mkdir -p "$expanded_save_path"
  fi
  
  # Ensure remote directory exists
  if ! ssh "${REMOTE_HOST}" "[ -d '${remote_path}' ]"; then
    log_info "Creating remote directory: ${remote_path}"
    ssh "${REMOTE_HOST}" "mkdir -p '${remote_path}'"
  fi
  
  # Check if either location has files
  local local_file_count=$(find "$expanded_save_path" -type f 2>/dev/null | wc -l)
  local remote_file_count=$(ssh "${REMOTE_HOST}" "find '${remote_path}' -type f 2>/dev/null | wc -l")
  
  log_info "Local files: ${local_file_count}, Remote files: ${remote_file_count}"
  
  # Handle empty directory cases
  if [ "$local_file_count" -eq 0 ] && [ "$remote_file_count" -gt 0 ]; then
    log_info "Syncing from remote (local is empty)"
    ${RSYNC_CMD} ${RSYNC_FLAGS} "${REMOTE_HOST}:${remote_path}/" "$expanded_save_path" ${RSYNC_OPTS}
    return
  elif [ "$local_file_count" -gt 0 ] && [ "$remote_file_count" -eq 0 ]; then
    log_info "Syncing to remote (remote is empty)"
    create_backup "$expanded_save_path" "${game_name}_${platform}"
    ${RSYNC_CMD} ${RSYNC_FLAGS} "$expanded_save_path/" "${REMOTE_HOST}:${remote_path}" ${RSYNC_OPTS}
    return
  elif [ "$local_file_count" -eq 0 ] && [ "$remote_file_count" -eq 0 ]; then
    log_info "Both directories are empty, nothing to sync"
    return
  fi
  
  # Compare timestamps for bidirectional sync
  local local_time=0
  local remote_time=0
  
  if [ "$local_file_count" -gt 0 ]; then
    local latest_local=$(find "$expanded_save_path" -type f -printf '%T@ %p\n' | sort -n | tail -1)
    local_time=$(echo "$latest_local" | cut -d' ' -f1)
    local local_file=$(echo "$latest_local" | cut -d' ' -f2-)
    local local_time_human=$(stat -c %y "$local_file")
    log_info "Latest local file: $(basename "$local_file") (${local_time_human})"
  fi
  
  if [ "$remote_file_count" -gt 0 ]; then
    local latest_remote=$(ssh "${REMOTE_HOST}" "find '${remote_path}' -type f -printf '%T@ %p\\n' | sort -n | tail -1")
    remote_time=$(echo "$latest_remote" | cut -d' ' -f1)
    local remote_file=$(echo "$latest_remote" | cut -d' ' -f2-)
    local remote_time_human=$(ssh "${REMOTE_HOST}" "stat -c %y '${remote_file}'")
    log_info "Latest remote file: $(basename "$remote_file") (${remote_time_human})"
  fi
  
  # Sync based on newest timestamp
  if (( $(echo "$local_time > $remote_time" | bc -l) )); then
    log_info "Local files are newer - syncing to remote"
    create_backup "$expanded_save_path" "${game_name}_${platform}"
    ${RSYNC_CMD} ${RSYNC_FLAGS} "$expanded_save_path/" "${REMOTE_HOST}:${remote_path}" ${RSYNC_OPTS}
  elif (( $(echo "$local_time < $remote_time" | bc -l) )); then
    log_info "Remote files are newer - syncing to local"
    create_backup "$expanded_save_path" "${game_name}_${platform}"
    ${RSYNC_CMD} ${RSYNC_FLAGS} "${REMOTE_HOST}:${remote_path}/" "$expanded_save_path" ${RSYNC_OPTS}
  else
    log_info "Files have identical timestamps - no sync needed"
  fi
}

# Match installed games against database
match_games_in_database() {
  local found_games=()
  local unknown_games=()
  
  # Iterate through each store
  for store in "${!STORE_PATHS[@]}"; do
    scan_store_games "$store"
    
    # Get the found games for this store
    local -n store_games="FOUND_GAMES_${store}"
    
    for installed_game in "${store_games[@]}"; do
      local matched=false
      
      # Check against database
      local game_count=$(jq -r '.games | keys | length' "$GAME_DB_FILE")
      for ((i=0; i<game_count; i++)); do
        local db_game=$(jq -r ".games | keys[$i]" "$GAME_DB_FILE")
        
        # Check if this game has the current platform
        if jq -e ".games[\"$db_game\"].platforms[\"$store\"]" "$GAME_DB_FILE" >/dev/null 2>&1; then
          local folder_names=$(jq -r ".games[\"$db_game\"].platforms[\"$store\"].folder_names[]" "$GAME_DB_FILE")
          
          # Case-insensitive matching
          while IFS= read -r folder_name; do
            if [[ "${installed_game,,}" == "${folder_name,,}" ]]; then
              log_info "Matched: ${installed_game} (${store}) -> ${db_game}"
              found_games+=("${db_game}|${store}")
              matched=true
              break
            fi
          done <<< "$folder_names"
          
          if [ "$matched" = true ]; then
            break
          fi
        fi
      done
      
      if [ "$matched" = false ]; then
        unknown_games+=("${installed_game} (${store})")
        log_warning "Unknown game found: ${installed_game} in ${store}"
      fi
    done
  done
  
  # Report findings
  log_info "Found ${#found_games[@]} games to sync: ${found_games[*]}"
  if [ ${#unknown_games[@]} -gt 0 ]; then
    log_warning "Found ${#unknown_games[@]} unknown games:"
    for unknown in "${unknown_games[@]}"; do
      log_warning "  - $unknown"
    done
    log_warning "Please add these games to ${GAME_DB_FILE} if you want them synced"
  fi
  
  # Sync found games
  for game_entry in "${found_games[@]}"; do
    local db_game=$(echo "$game_entry" | cut -d'|' -f1)
    local platform=$(echo "$game_entry" | cut -d'|' -f2)
    
    local save_path=$(jq -r ".games[\"$db_game\"].platforms[\"$platform\"].save_path" "$GAME_DB_FILE")
    local remote_folder=$(jq -r ".games[\"$db_game\"].platforms[\"$platform\"].remote_folder" "$GAME_DB_FILE")
    
    sync_game_saves "$db_game" "$platform" "$save_path" "$remote_folder"
  done
}

# ==============================================
# MAIN SCRIPT
# ==============================================

main() {
  log_info "==== Starting ${SCRIPT_NAME} ${SCRIPT_VERSION} (${SCRIPT_DATE}) ===="
  log_info "Detected user: ${DETECTED_USER}"
  
  # Handle unknown user
  if [ "$DETECTED_USER" = "unknown" ]; then
    log_error "Unknown user detected. Supported users: greintek, Mujika, owlcub"
    log_error "Please add your username to the detect_user() function in this script."
    error_exit "Unsupported user profile. Exiting."
  fi
  
  # Run mode indicator
  if [ "$DRY_RUN" = true ]; then
    log_info "*** RUNNING IN DRY-RUN MODE - NO CHANGES WILL BE MADE ***"
  else
    log_info "*** LIVE MODE - CHANGES WILL BE APPLIED ***"
  fi
  
  # Clean up old logs
  cleanup_old_logs
  
  # Check dependencies
  check_dependencies
  
  # Check database exists
  check_database_exists
  
  # Check remote connectivity
  if ! check_remote_connectivity; then
    error_exit "Failed to connect to remote server"
  fi
  
  # Match and sync games
  match_games_in_database
  
  log_info "==== Auto game sync completed successfully ===="
  if [ "$DRY_RUN" = true ]; then
    log_info "REMINDER: Script ran in DRY-RUN mode - no files were actually modified"
  fi
}

# Run the main function
main