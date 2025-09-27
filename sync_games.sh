#! /bin/bash

# - 20220405_v5
#  - added csc folder download & upload
# 20220809
# - added Horizon and direct upload of savegames
# 20220823 v2.2.0
# - added Cuphead and Mortal shell
# - Commented The Witcher 3
# - Do I need to improve the extra functions in order to quickly download everything I need?
# 20221226 v2.2.1
# - Added callisto, daysgone and elden ring 
# - edited xinyang new folder path
# 20231201 v2.2.2
# - xinyang is now elderOwl
# - refining and checking
# 20231204 v3
# - Implemented declarative array
# 20240426 v3.1
# - Added Horizon Forbidden West
# - Added Dying Light 2
# 20241102 v3.2
# - adapted to owlbear
# - Needed features: 
#   - Check which server is online
#   - Make a local copy
#   - Make a backup of this folder somehow
#   - Make it a recurrent task

# General save paths
wOwlbear="/mnt/c"
wOwlbear_u="$wOwlbear/Users/owlbear"
wOwlbear_uL="$wOwlbear_u/AppData/Local"
wOwlbear_uR="$wOwlbear_u/AppData/Roaming"
wOwlbear_d="$wOwlbear_u/Documents"
wOwlbear_dMy="$wOwlbear_d/My Games"
wOwlbear_S="$wOwlbear_u/Saved Games"

# Vars
# Global variable to accumulate warning messages
warning_messages=""
local="/mnt/d/root"
greenskull="greenskull:/mnt/xinyang/bck/live" 
zimablade="zimablade:/mnt/pantainos/bck"

# Check if greenskull is online
if ping -c 1 192.168.1.211 &> /dev/null; then
  server=$greenskull
  # Print the skull in green using ANSI escape codes
  echo -e "\e[32m  _____  \n /     \\ \n| () () |\n \  ^  / \n  |||||  \n  |||||  \e[0m"
  echo "greenskull is online"
elif ping -c 1 192.168.1.210 &> /dev/null; then
  server=$zimablade
  echo -e " __v_\n(____\/{"
  echo "zimablade is online"
else 
  cat << "EOF"
 _  _    ___  _  _   
| || |  / _ \| || |  
| || |_| | | | || |_ 
|__   _| |_| |__   _|
   |_|  \___/   |_|  

EOF
  echo "Neither server is online"
  server=local
fi

bck_games="$server/svgmOwlbear" 
today=$(date +%Y.%m.%d.%H.%M.%S)_"${server%%:*}"_bck_games.log # my time variable
log_path="$local/scr/logs/$today" 

# Define game paths in an associative array with custom destination paths
declare -A game_paths=(
  #["highOnLife"]="$wOwlbear_uL/Oregon/Saved/SaveGames/"
  ["stateOfDecay2"]="$wOwlbear_uL/StateOfDecay2/Saved/SaveGames/"
  #["darkSoulsIII"]="$wOwlbear_uR/DarkSoulsIII/0110000102d383a1/"
  ["darkSoulsR"]="$wOwlbear_d/NBGI/DARK SOULS REMASTERED/47416225/"
  ["eldenRing"]="$wOwlbear_uR/EldenRing/76561198007681953/"
  ["daysGone"]="$wOwlbear_uL/BendGame/Saved/76561198007681953/SaveGames/"
  ["callisto"]="$wOwlbear_uL/CallistoProtocol/Saved/SaveGames/"
  ["tLoUI"]="$wOwlbear_S/The Last of Us Part I/users/47416225/savedata/"
  #["sackboy"]="$wOwlbear_S/Sackboy/Steam/SaveGames/"
  ["horizon2"]="$wOwlbear_d/Horizon Forbidden West Complete Edition/76561198994464186/"
  ["projectCars"]="$wOwlbear/Program Files (x86)/Steam/userdata/47416225/234630/local/project cars/profiles/"
  ["dyingLight2"]="$wOwlbear_d/dying light 2/out/-save_backups/"
  ["massEffectLegendary"]="$wOwlbear_d/BioWare/Mass Effect Legendary Edition/Save/"
  ["mortalShell"]="$wOwlbear_dMy/MortalShell/Dungeonhaven/Saved/Savegames/"
  #["dyingLight"]="$wOwlbear_d/DyingLight/out/save"
  ["baldursGate3"]="$wOwlbear_uL/Larian Studios/Baldur's Gate 3/PlayerProfiles/"
  #["northgard"]="$wOwlbear/g/GOG/Northgard/save"
  ["riftbreaker"]="$wOwlbear_d/The Riftbreaker/campaignV2/"
  # ... add more games here
)

# Game paths with default destination
game_default=(
  "$wOwlbear_u/Saved Games/Diablo II Resurrected"
  "$wOwlbear_d/Project CARS 2/savegame/47416225/project cars 2"
  "$wOwlbear_dMy/Skyrim Special Edition"
  "$wOwlbear_dMy/Skyrim Special Edition GOG"
  "$wOwlbear_uR/Cuphead"
  "$wOwlbear_d/Electronic Arts/Dead Space"
  #"$wOwlbear_d/Horizon Zero Dawn"
  #"$wOwlbear_d/BioWare/Dragon Age"
  #"$wOwlbear_dMy/Fallout4"
  "$wOwlbear_S/Quantic Dream/Detroit Become Human"
  #"$wOwlbear_d/Witcher 2/gamesaves"
  #"$wOwlbear_d/The Witcher 3/gamesaves"
  #diabloIII="$wOwlbear/" everything is on Blizzard's servers
  # ... add more source paths here
)

# Function to perform rsync for a game
rsync_game() {
  local source_path="$1"
  local destination_path="$2"

  common="$bck_games/$destination_path"
  doneness="$destination_path"

  if [ -d "$source_path" ]; then
    if [ -z "$destination_path" ]; then
    # If the destination_path is not provided, set a default common destination
      common="$bck_games"
      doneness=$(basename "$source_path")
    fi
    if [ "$server" == "local" ]; then
      common="$local/bck/svgm/$destination_path"
    fi
    rsync -avhiPm "$source_path" "$common" --delete --log-file=$log_path
    echo "rsync -avhiPmn "$source_path" "$common" --delete --log-file=$log_path" | tee -a $log_path
    echo -e "\n ============================================================================================== \n $doneness done! \n ==============================================================================================" | tee -a $log_path
  else
    warning_messages+="Warning: $source_path not found for $destination_path.\n"
  fi

}

# Iterate through all games and perform rsync
for game_name in "${!game_paths[@]}" "${game_default[@]}"; do
  if [[ -v game_paths["$game_name"] ]]; then
    # Custom games
    source_path="${game_paths[$game_name]}"
    rsync_game "$source_path" "$game_name"
  else
    # Default games
    rsync_game "$game_name"
  fi
done

# Print the warning messages at the end if they exist
if [ -n "$warning_messages" ]; then
  echo -e "$warning_messages" | tee -a "$log_path"  # Log the warning to the log file and print to the terminal
fi

#wGames
echo $(date +%H:%M:%S)
