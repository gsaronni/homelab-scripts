#!/bin/bash

# Fedora Setup Script - With LLogging
# No fancy colors, just works with beautiful output

echo "=== FEDORA SETUP SCRIPT STARTED ==="
echo "Time: $(date)"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: This script must be run as root (use sudo)!"
  exit 1
fi

# Get the actual user (not root)
if [[ -n "$SUDO_USER" ]]; then
  ACTUAL_USER="$SUDO_USER"
else
  ACTUAL_USER=$(getent passwd 1000 | cut -d: -f1)
fi

USER_HOME="/home/$ACTUAL_USER"

if [[ -z "$ACTUAL_USER" ]]; then
  echo "ERROR: Could not determine actual user"
  exit 1
fi

echo "Setting up environment for user: $ACTUAL_USER"

# Initialize logging and failure tracking
LOG_FILE="$USER_HOME/fedora_setup_$(date +%Y%m%d_%H%M%S).log"
INSTALL_SUCCESS=()
INSTALL_FAILED=()

# Function to check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Logging function (Arch-style)
log() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo "✅ $message"
    echo "✅ $message" >> "$LOG_FILE"
}

error() {
    local message="[ERROR] $1"
    echo "❌ $message" >&2
    echo "❌ $message" >> "$LOG_FILE"
}

warning() {
    local message="[WARNING] $1"
    echo "⚠️  $message"
    echo "⚠️  $message" >> "$LOG_FILE"
}

# Package installation with error tracking (Arch-style)
install_single_package() {
  local package="$1"
  
  log "Attempting to install: $package"
  if dnf install "$package" -y >> "$LOG_FILE" 2>&1; then
    # Verify installation
    if rpm -q "$package" &>/dev/null; then
      echo "🎉 SUCCESS: $package installed and verified!"
      echo "🎉 SUCCESS: $package installed and verified!" >> "$LOG_FILE"
      INSTALL_SUCCESS+=("$package")
      return 0
    else
      echo "💥 FAILED: $package installation verification failed!"
      echo "💥 FAILED: $package installation verification failed!" >> "$LOG_FILE"
      INSTALL_FAILED+=("$package")
      return 1
    fi
  else
    echo "💥 FAILED: Could not install $package!"
    echo "💥 FAILED: Could not install $package!" >> "$LOG_FILE"
    INSTALL_FAILED+=("$package")
    return 1
  fi
}

# Function wrapper for tracking function success/failure
track_function() {
  local func_name="$1"
  local display_name="$2"
  
  log "Starting: $display_name"
  echo "Installing $display_name..."
  
  if $func_name >> "$LOG_FILE" 2>&1; then
    log "✓ SUCCESS: $display_name completed"
    INSTALL_SUCCESS+=("$display_name")
    echo "$display_name installed successfully"
  else
    error "✗ FAILED: $display_name failed"
    INSTALL_FAILED+=("$display_name")
    echo "$display_name installation failed"
  fi
}

# Sublime Text Environment
sublime_environment() {
  rpm -v --import https://download.sublimetext.com/sublimehq-rpm-pub.gpg
  
  cat > /etc/yum.repos.d/sublime-text.repo << EOF
[sublime-text]
name=Sublime Text
baseurl=https://download.sublimetext.com/rpm/stable/x86_64/
gpgkey=https://download.sublimetext.com/sublimehq-rpm-pub.gpg
gpgcheck=1
enabled=1
EOF
  
  dnf install sublime-merge sublime-text -y
}

# VSCodium
install_vscodium() {
  rpmkeys --import https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg
  
  cat > /etc/yum.repos.d/vscodium.repo << EOF
[gitlab.com_paulcarroty_vscodium_repo]
name=download.vscodium.com
baseurl=https://download.vscodium.com/rpms/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg
metadata_expire=1h
EOF
  
  dnf update -y
  dnf install codium -y
}

# Doom Emacs
install_doom_emacs() {
  dnf install emacs pandoc ShellCheck git ripgrep fd-find -y
  
  sudo -u "$ACTUAL_USER" bash -c "
      [[ -d '$USER_HOME/.emacs.d' ]] && rm -rf '$USER_HOME/.emacs.d'
      [[ -d '$USER_HOME/.config/emacs' ]] && rm -rf '$USER_HOME/.config/emacs'
      
      mkdir -p '$USER_HOME/.config'
      git clone --depth 1 https://github.com/doomemacs/doomemacs '$USER_HOME/.config/emacs'
      '$USER_HOME/.config/emacs/bin/doom' install --force
      
      if ! grep -q '.config/emacs/bin' '$USER_HOME/.bashrc'; then
          echo 'export PATH=\"\$HOME/.config/emacs/bin:\$PATH\"' >> '$USER_HOME/.bashrc'
      fi
  "
}

# Spotify
install_spotify() {
  curl -o /etc/yum.repos.d/fedora-spotify.repo https://negativo17.org/repos/fedora-spotify.repo
  dnf install spotify-client -y
}

# NvChad
install_nvchad() {
  dnf install neovim git ripgrep fd-find -y
  
  sudo -u "$ACTUAL_USER" bash -c "
      if [[ -d '$USER_HOME/.config/nvim' ]]; then
          mv '$USER_HOME/.config/nvim' '$USER_HOME/.config/nvim.backup.\$(date +%Y%m%d_%H%M%S)'
      fi
      
      mkdir -p '$USER_HOME/.config'
      git clone https://github.com/NvChad/NvChad '$USER_HOME/.config/nvim' --depth 1
      mkdir -p '$USER_HOME/.config/nvim/lua/custom'
  "
}

# Telegram
install_telegram() {
  dnf install "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" -y
  dnf install "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" -y
  dnf install telegram -y
}

# PowerShell
install_powershell() {
  TEMP_DIR=$(mktemp -d)
  cd "$TEMP_DIR"
  
  LATEST_URL=$(curl -s https://api.github.com/repos/PowerShell/PowerShell/releases/latest | \
                grep "browser_download_url.*el.*x86_64.*rpm" | \
                cut -d '"' -f 4 | head -n 1)
  
  if [[ -z "$LATEST_URL" ]]; then
      echo "ERROR: Could not find PowerShell RPM"
      return 1
  fi
  
  wget -O powershell-latest.rpm "$LATEST_URL"
  rpm -Uvh powershell-latest.rpm
  
  cd /
  rm -rf "$TEMP_DIR"
  
  if command_exists pwsh; then
      echo "PowerShell installed: $(pwsh --version)"
  else
      echo "ERROR: PowerShell installation failed"
      return 1
  fi
}

install_starship() {
  # https://starship.rs/
  # depencency https://www.nerdfonts.com/
  if command_exists starship; then
    echo "Starship already installed: $(starship --version)"
    return 0
  fi

  if curl -sS https://starship.rs/install.sh | sh -s -- -y; then
    if command_exists starship; then
      echo "Starship installed: $(starship --version)"
      return 0
    fi
  fi

  echo "ERROR: Starship installation failed"
  return 1
}

# Brave Browser
install_brave() {
  dnf install dnf-plugins-core -y
  dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
  dnf install brave-browser -y
}

# Install main packages
install_main_packages() {
  log "=== STARTING PACKAGE INSTALLATION ==="
  echo "Updating system..."
  
  log "Updating system..."
  if dnf update -y >> "$LOG_FILE" 2>&1; then
    echo "🎉 SUCCESS: System update completed!"
    echo "🎉 SUCCESS: System update completed!" >> "$LOG_FILE"
    INSTALL_SUCCESS+=("System Update")
  else
    echo "💥 FAILED: System update failed!"
    echo "💥 FAILED: System update failed!" >> "$LOG_FILE"
    INSTALL_FAILED+=("System Update")
  fi
  
  # Enable RPM Fusion
  log "Enabling RPM Fusion repositories..."
  dnf install "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" -y >> "$LOG_FILE" 2>&1
  dnf install "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" -y >> "$LOG_FILE" 2>&1
  
  # Package arrays
  BASIC_APPS=(
    "shotcut" "kitty" "alacritty" "gramps" "keepassxc" "p7zip" 
    "foliate" "vim" "neovim" "taskwarrior" "liferea" "fastfetch"
  )
  
  CLI_TOOLS=(
    "bat" "fd-find" "ripgrep" "duf" "ranger" "htop" "dust" 
    "procs" "fzf" "jq" "git-delta" "lazygit" "hyperfine"
  )
  
  DEV_TOOLS=(
    "git" "curl" "wget" "tree" "tmux" "screen"
  )
  
  SYSTEM_UTILS=(
    "lm_sensors" "btop" "ncdu"
  )
  
  # Install each category individually
  echo "Installing Basic Applications..."
  log "Installing Basic Applications packages..."
  for package in "${BASIC_APPS[@]}"; do
    install_single_package "$package"
  done
  
  echo "Installing CLI Tools..."
  log "Installing Modern CLI Tools packages..."
  for package in "${CLI_TOOLS[@]}"; do
    install_single_package "$package"
  done
  
  echo "Installing Development Tools..."
  log "Installing Development Tools packages..."
  for package in "${DEV_TOOLS[@]}"; do
    install_single_package "$package"
  done
  
  echo "Installing System Utilities..."
  log "Installing System Utilities packages..."
  for package in "${SYSTEM_UTILS[@]}"; do
    install_single_package "$package"
  done
  
  log "=== PACKAGE INSTALLATION COMPLETE ==="
}

# Flatpak apps
install_flatpak_apps() {
  log "Installing Flatpak applications..."
  
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  
  local flatpak_apps=("VLC" "Discord" "Anki")
  local flatpak_ids=("org.videolan.VLC" "com.discordapp.Discord" "net.ankiweb.Anki")
  
  for i in "${!flatpak_apps[@]}"; do
    log "Attempting to install: ${flatpak_apps[$i]}"
    echo "Installing ${flatpak_apps[$i]}..."
    if flatpak install -y flathub "${flatpak_ids[$i]}" >> "$LOG_FILE" 2>&1; then
      echo "🎉 SUCCESS: ${flatpak_apps[$i]} installed and verified!"
      echo "🎉 SUCCESS: ${flatpak_apps[$i]} installed and verified!" >> "$LOG_FILE"
      INSTALL_SUCCESS+=("${flatpak_apps[$i]}")
    else
      echo "💥 FAILED: Could not install ${flatpak_apps[$i]}!"
      echo "💥 FAILED: Could not install ${flatpak_apps[$i]}!" >> "$LOG_FILE"
      INSTALL_FAILED+=("${flatpak_apps[$i]}")
    fi
  done
  
  log "Flatpak apps installation completed"
}

# Apply custom configs
apply_custom_configs() {
  log "Applying custom configurations..."
  echo "Applying custom configurations..."
  
  sudo -u "$ACTUAL_USER" mkdir -p "$USER_HOME/.config/kitty"
  sudo -u "$ACTUAL_USER" mkdir -p "$USER_HOME/.config/alacritty"
  sudo -u "$ACTUAL_USER" mkdir -p "$USER_HOME/.config/jrnl"
  sudo -u "$ACTUAL_USER" mkdir -p "$USER_HOME/.ssh"

  chmod 700 "$USER_HOME/.ssh"
  chown "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME/.ssh"
  
  # Copy custom configuration files
  log "Copying configuration files..."
  local configs=(
      "vim.vimrc:.vimrc"
      "kitty.conf:.config/kitty/kitty.conf" 
      "alacritty.toml:.config/alacritty/alacritty.toml"
      "jrnl.yaml:.config/jrnl/jrnl.yaml"
      "sample_ssh_config:.ssh/config"
      "starship/ultimate.toml:.config/starship.toml"
  )
  
  for config in "${configs[@]}"; do
    IFS=':' read -r source_file dest_path <<< "$config"
    source_path="$USER_HOME/shp/scr/setup/apps/$source_file"
    dest_full_path="$USER_HOME/$dest_path"
    
    if [[ -f "$source_path" ]]; then
      cp "$source_path" "$dest_full_path"
      chown "$ACTUAL_USER:$ACTUAL_USER" "$dest_full_path"
      if [[ "$dest_path" == *".ssh/config" ]]; then
        chmod 600 "$dest_full_path"
      fi
      echo "🎉 SUCCESS: $source_file config copied and verified!"
      echo "🎉 SUCCESS: $source_file config copied and verified!" >> "$LOG_FILE"
      INSTALL_SUCCESS+=("$source_file config")
    else
      echo "💥 FAILED: $source_file not found, skipping!"
      echo "💥 FAILED: $source_file not found, skipping!" >> "$LOG_FILE"
      INSTALL_FAILED+=("$source_file config")
    fi
  done

  # Add aliases if not present
  if ! grep -q "Package management alias" "$USER_HOME/.bashrc"; then
      echo "Adding aliases to .bashrc..."
      cat >> "$USER_HOME/.bashrc" << 'EOF'

# Package management alias
alias pkgu='sudo dnf update && sudo dnf upgrade -y && sudo dnf autoremove -y && sudo flatpak update'
alias ll='ls -la'
alias emacs='emacs -nw'

EOF
      echo "🎉 SUCCESS: Aliases added to .bashrc!"
      echo "🎉 SUCCESS: Aliases added to .bashrc!" >> "$LOG_FILE"
      INSTALL_SUCCESS+=("Bash aliases")
  else
      log "Aliases already present in .bashrc"
  fi
  
  # Initialize starship if installed
  if command_exists starship; then
      if ! grep -q "starship init bash" "$USER_HOME/.bashrc"; then
          echo 'eval "$(starship init bash)"' >> "$USER_HOME/.bashrc"
          echo "🎉 SUCCESS: Starship prompt added!"
          echo "🎉 SUCCESS: Starship prompt added!" >> "$LOG_FILE"
          INSTALL_SUCCESS+=("Starship prompt")
      fi
  fi
  
  chown "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME/.bashrc"
  log "Custom configurations applied successfully"
}

# Print installation summary (Arch-style)
print_installation_summary() {
    echo ""
    echo "=============================================="
    echo "           INSTALLATION SUMMARY"
    echo "=============================================="
    
    if [[ ${#INSTALL_SUCCESS[@]} -gt 0 ]]; then
        echo "✓ SUCCESSFULLY INSTALLED (${#INSTALL_SUCCESS[@]} items):"
        for app in "${INSTALL_SUCCESS[@]}"; do
            echo "  ✓ $app"
        done
        echo ""
    fi
    
    if [[ ${#INSTALL_FAILED[@]} -gt 0 ]]; then
        echo "✗ FAILED TO INSTALL (${#INSTALL_FAILED[@]} items):"
        for app in "${INSTALL_FAILED[@]}"; do
            echo "  ✗ $app"
        done
        echo ""
        echo "To troubleshoot failed installations:"
        echo "1. Search for packages: dnf search <package-name>"
        echo "2. Try manual installation: sudo dnf install <package-name>"
        echo "3. Check if package exists in repositories"
        echo "4. Look for alternative package names"
        echo ""
    fi
    
    # Calculate success rate
    local total=$((${#INSTALL_SUCCESS[@]} + ${#INSTALL_FAILED[@]}))
    if [[ $total -gt 0 ]]; then
        local success_rate=$((${#INSTALL_SUCCESS[@]} * 100 / total))
        echo "Installation Success Rate: $success_rate% ($total total items)"
    fi
    echo "=============================================="
    
    # Save detailed log
    {
        echo "=== Installation Summary - $(date) ==="
        echo "Total items: $total"
        if [[ $total -gt 0 ]]; then
            echo "Success Rate: $success_rate%"
        fi
        echo ""
        echo "Successfully installed:"
        for app in "${INSTALL_SUCCESS[@]}"; do
            echo "  ✓ $app"
        done
        echo ""
        echo "Failed installations:"
        for app in "${INSTALL_FAILED[@]}"; do
            echo "  ✗ $app"
        done
        echo ""
    } >> "$LOG_FILE"
    
    echo "📄 Detailed log saved to: $LOG_FILE"
}

# Main execution
main() {
  log "=== STARTING FEDORA SETUP ==="
  
  install_main_packages
  
  track_function "install_flatpak_apps" "Flatpak Applications"
  
  echo "Installing specific applications..."
  track_function "install_vscodium" "VSCodium"
  track_function "sublime_environment" "Sublime Text"
  track_function "install_telegram" "Telegram"
  track_function "install_powershell" "PowerShell"
  track_function "install_brave" "Brave Browser"
  track_function "install_doom_emacs" "Doom Emacs"
  track_function "install_nvchad" "NvChad"
  track_function "install_spotify" "Spotify"
  track_function "install_starship" "starship"
  
  track_function "apply_custom_configs" "Custom Configurations"
  
  print_installation_summary
  
  echo "=== SETUP COMPLETE ==="
  echo "Please restart your terminal or run 'source ~/.bashrc'"
  
  if command_exists fastfetch; then
      echo "System info:"
      fastfetch
  fi
  
  log "=== FEDORA SETUP COMPLETED ==="
}

# Run it
echo "Running main setup..."
main "$@"
echo "=== ALL DONE ==="
