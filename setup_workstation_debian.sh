#!/bin/bash

# Debian/Ubuntu Setup Script 
# Version: 2.0 - 2025 Edition
# Last updated: 2025-07-28

echo "=== DEBIAN/UBUNTU SETUP SCRIPT STARTED ==="
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
LOG_FILE="$USER_HOME/debian_setup_$(date +%Y%m%d_%H%M%S).log"
INSTALL_SUCCESS=()
INSTALL_FAILED=()

# Detect distribution
DISTRO=""
if grep -qi ubuntu /etc/os-release; then
    DISTRO="ubuntu"
    echo "Detected: Ubuntu"
elif grep -qi debian /etc/os-release; then
    DISTRO="debian"
    echo "Detected: Debian"
else
    DISTRO="unknown"
    echo "Detected: Unknown Debian-based distribution"
fi

# Function to check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Logging functions (Arch-style)
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

# Package installation with error tracking
install_single_package() {
  local package="$1"
  
  log "Attempting to install: $package"
  if apt-get install -y "$package" >> "$LOG_FILE" 2>&1; then
    # Verify installation
    if dpkg -l "$package" &>/dev/null; then
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

# Snap package installation
install_snap_package() {
  local package="$1"
  
  log "Attempting to install snap: $package"
  if snap install "$package" >> "$LOG_FILE" 2>&1; then
    # Verify installation
    if snap list "$package" &>/dev/null; then
      echo "🎉 SNAP SUCCESS: $package installed and verified!"
      echo "🎉 SNAP SUCCESS: $package installed and verified!" >> "$LOG_FILE"
      INSTALL_SUCCESS+=("$package (snap)")
      return 0
    else
      echo "💥 SNAP FAILED: $package installation verification failed!"
      echo "💥 SNAP FAILED: $package installation verification failed!" >> "$LOG_FILE"
      INSTALL_FAILED+=("$package (snap)")
      return 1
    fi
  else
    echo "💥 SNAP FAILED: Could not install $package!"
    echo "💥 SNAP FAILED: Could not install $package!" >> "$LOG_FILE"
    INSTALL_FAILED+=("$package (snap)")
    return 1
  fi
}

# Flatpak package installation
install_flatpak_package() {
  local package="$1"
  local package_id="$2"
  
  log "Attempting to install flatpak: $package"
  if flatpak install -y flathub "$package_id" >> "$LOG_FILE" 2>&1; then
    # Verify installation
    if flatpak list | grep -q "$package_id"; then
      echo "🎉 FLATPAK SUCCESS: $package installed and verified!"
      echo "🎉 FLATPAK SUCCESS: $package installed and verified!" >> "$LOG_FILE"
      INSTALL_SUCCESS+=("$package (flatpak)")
      return 0
    else
      echo "💥 FLATPAK FAILED: $package installation verification failed!"
      echo "💥 FLATPAK FAILED: $package installation verification failed!" >> "$LOG_FILE"
      INSTALL_FAILED+=("$package (flatpak)")
      return 1
    fi
  else
    echo "💥 FLATPAK FAILED: Could not install $package!"
    echo "💥 FLATPAK FAILED: Could not install $package!" >> "$LOG_FILE"
    INSTALL_FAILED+=("$package (flatpak)")
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

# Setup package manager for GUI apps
setup_gui_package_manager() {
    log "Setting up GUI package manager..."
    
    if [[ "$DISTRO" == "ubuntu" ]]; then
        # Ubuntu: Use snap (pre-installed)
        if command_exists snap; then
            log "Using snap for GUI applications (Ubuntu detected)"
            GUI_PKG_MANAGER="snap"
        else
            warning "Snap not found on Ubuntu, installing..."
            if apt-get install -y snapd >> "$LOG_FILE" 2>&1; then
                GUI_PKG_MANAGER="snap"
                log "Snap installed successfully"
            else
                error "Failed to install snap, falling back to flatpak"
                GUI_PKG_MANAGER="flatpak"
            fi
        fi
    else
        # Debian: Prefer flatpak
        if ! command_exists flatpak; then
            log "Installing flatpak for GUI applications (Debian detected)"
            if apt-get install -y flatpak >> "$LOG_FILE" 2>&1; then
                flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
                GUI_PKG_MANAGER="flatpak"
                log "Flatpak installed and configured"
            else
                error "Failed to install flatpak, trying snap"
                if apt-get install -y snapd >> "$LOG_FILE" 2>&1; then
                    GUI_PKG_MANAGER="snap"
                    log "Snap installed as fallback"
                else
                    error "Both flatpak and snap failed to install"
                    GUI_PKG_MANAGER="none"
                fi
            fi
        else
            GUI_PKG_MANAGER="flatpak"
            log "Using flatpak for GUI applications (Debian detected)"
        fi
    fi
}

# PowerShell installation
install_powershell() {
    apt-get install -y wget apt-transport-https software-properties-common
    wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb
    dpkg -i packages-microsoft-prod.deb
    apt-get update
    add-apt-repository universe -y
    apt-get install -y powershell
    rm -f packages-microsoft-prod.deb
}

# VSCodium installation
install_vscodium() {
    wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
        | gpg --dearmor \
        | dd of=/usr/share/keyrings/vscodium-archive-keyring.gpg
    echo 'deb [ signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg ] https://download.vscodium.com/debs vscodium main' \
        | tee /etc/apt/sources.list.d/vscodium.list
    apt-get update
    apt-get install -y codium
}

# Sublime Text installation
install_sublime() {
    apt-get install -y software-properties-common apt-transport-https wget ca-certificates
    wget -qO- https://download.sublimetext.com/sublimehq-pub.gpg | gpg --dearmor | tee /usr/share/keyrings/sublime.gpg
    echo 'deb [signed-by=/usr/share/keyrings/sublime.gpg] https://download.sublimetext.com/ apt/stable/' | tee -a /etc/apt/sources.list.d/sublime-text.list
    apt-get update
    apt-get install -y sublime-text sublime-merge
}

# Surfshark VPN installation
install_surfshark() {
    curl -f https://downloads.surfshark.com/linux/debian-install.sh --output surfshark-install.sh
    chmod +x surfshark-install.sh
    ./surfshark-install.sh
    rm -f surfshark-install.sh
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

# jrnl installation
install_jrnl() {
    # Install pipx if not present
    if ! command_exists pipx; then
        apt-get install -y pipx
    fi
    
    # Install jrnl via pipx as actual user
    sudo -u "$ACTUAL_USER" pipx install jrnl
    sudo -u "$ACTUAL_USER" pipx ensurepath
}

# Install GUI applications based on detected package manager
install_gui_apps() {
    log "Installing GUI applications using $GUI_PKG_MANAGER..."
    
    if [[ "$GUI_PKG_MANAGER" == "snap" ]]; then
        install_snap_package "discord"
        install_snap_package "telegram-desktop"
        # Add more snap packages here if needed
        
    elif [[ "$GUI_PKG_MANAGER" == "flatpak" ]]; then
        install_flatpak_package "Discord" "com.discordapp.Discord"
        install_flatpak_package "Telegram" "org.telegram.desktop"
        install_flatpak_package "VLC" "org.videolan.VLC"
        install_flatpak_package "Anki" "net.ankiweb.Anki"
        
    else
        warning "No GUI package manager available, skipping GUI apps"
    fi
}

# Install main packages
install_main_packages() {
    log "=== STARTING PACKAGE INSTALLATION ==="
    
    # Update system first
    log "Updating system..."
    if apt-get update && apt-get upgrade -y >> "$LOG_FILE" 2>&1; then
        echo "🎉 SUCCESS: System update completed!"
        echo "🎉 SUCCESS: System update completed!" >> "$LOG_FILE"
        INSTALL_SUCCESS+=("System Update")
    else
        echo "💥 FAILED: System update failed!"
        echo "💥 FAILED: System update failed!" >> "$LOG_FILE"
        INSTALL_FAILED+=("System Update")
    fi
    
    # Package arrays
    BASIC_APPS=(
        "kitty" "shotcut" "gramps" "keepassxc" "p7zip-full" "foliate" 
        "pipx" "vim" "task" "liferea" "quiterss" "htop" "fastfetch" 
        "vlc" "taskwarrior" "python3-pip" "neovim" "alacritty"
    )
    
    CLI_TOOLS=(
        "bat" "fd-find" "ripgrep" "duf" "ranger" "dust" "fzf" 
        "jq" "git-delta" "lazygit" "hyperfine"
    )
    
    DEV_TOOLS=(
        "git" "curl" "wget" "tree" "tmux" "screen" "build-essential"
    )
    
    SYSTEM_UTILS=(
        "lm-sensors" "btop" "ncdu" "software-properties-common" 
        "apt-transport-https" "ca-certificates" "gnupg" "lsb-release"
    )
    
    # Install each category
    echo "Installing Basic Applications..."
    log "Installing Basic Applications packages..."
    for package in "${BASIC_APPS[@]}"; do
        install_single_package "$package"
    done
    
    echo "Installing Modern CLI Tools..."
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
    
    # Install starship prompt
    log "Installing Starship prompt..."
    if curl -sS https://starship.rs/install.sh | sh -s -- -y >> "$LOG_FILE" 2>&1; then
        echo "🎉 SUCCESS: Starship prompt installed!"
        echo "🎉 SUCCESS: Starship prompt installed!" >> "$LOG_FILE"
        INSTALL_SUCCESS+=("Starship prompt")
    else
        echo "💥 FAILED: Could not install Starship prompt!"
        echo "💥 FAILED: Could not install Starship prompt!" >> "$LOG_FILE"
        INSTALL_FAILED+=("Starship prompt")
    fi
    
    log "=== PACKAGE INSTALLATION COMPLETE ==="
}

# Apply custom configurations
apply_custom_configs() {
    log "Applying custom configurations..."
    echo "Applying custom configurations..."
    
    # Create necessary directories as actual user
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
    
    # Add aliases to .bashrc
    if ! grep -q "Package management alias" "$USER_HOME/.bashrc"; then
        echo "Adding aliases to .bashrc..."
        cat >> "$USER_HOME/.bashrc" << 'EOF'

# Package management alias
alias pkgu='sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get autoremove -y && sudo snap refresh'
alias ll='ls -la'
alias gitb='bash ~/hrb/gitUpdateroutine.sh'

# Modern CLI aliases
alias cat='bat --paging=never'
alias find='fd'
alias grep='rg'
alias du='dust'

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
        echo "🎉 SUCCESS: Starship prompt added to .bashrc!"
        echo "🎉 SUCCESS: Starship prompt added to .bashrc!" >> "$LOG_FILE"
        INSTALL_SUCCESS+=("Starship configuration")
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
        echo "1. Search for packages: apt search <package-name>"
        echo "2. Try manual installation: sudo apt install <package-name>"
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
        echo "Distribution: $DISTRO"
        echo "GUI Package Manager: $GUI_PKG_MANAGER"
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
    log "=== STARTING DEBIAN/UBUNTU SETUP ==="
    
    # Setup package manager for GUI apps
    setup_gui_package_manager
    
    # Install main packages
    install_main_packages
    
    # Install GUI applications
    install_gui_apps
    
    echo "Installing specific applications..."
    track_function "install_vscodium" "VSCodium"
    track_function "install_sublime" "Sublime Text"
    track_function "install_powershell" "PowerShell"
    track_function "install_surfshark" "Surfshark VPN"
    track_function "install_jrnl" "jrnl"
    track_function "install_starship" "starship"
    
    # Apply custom configurations
    track_function "apply_custom_configs" "Custom Configurations"
    
    # Final system update and cleanup
    log "Final system cleanup..."
    apt-get autoremove -y >> "$LOG_FILE" 2>&1
    if [[ "$GUI_PKG_MANAGER" == "snap" ]]; then
        snap refresh >> "$LOG_FILE" 2>&1
    fi
    
    print_installation_summary
    
    echo "=== SETUP COMPLETE ==="
    echo "Please restart your terminal or run 'source ~/.bashrc'"
    
    if command_exists fastfetch; then
        echo "System info:"
        fastfetch
    fi
    
    log "=== DEBIAN/UBUNTU SETUP COMPLETED ==="
}

# Run main function
main "$@"
