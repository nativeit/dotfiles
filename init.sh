#!/bin/bash

# Exit on any error
set -euo pipefail

# Color definitions for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
fi

echo "###################################################################################"
echo "Setup starting..."
echo ""
echo "IMPORTANT: New user details will be req'd following the initial setup."
echo ""
echo "Please be patient, this may take some time :)"
echo "###################################################################################"

# INSTALL UPDATES + APTITUDE
log "Updating system packages..."
apt update || error "Failed to update package lists"
apt full-upgrade -y || error "Failed to upgrade packages"
apt install -y aptitude || error "Failed to install aptitude"

# INSTALL UTILS + DEPS
log "Installing essential utilities and dependencies..."
PACKAGES=(
    sudo ack apt-show-versions apt-transport-https bc ca-certificates
    cowsay cron curl fzf git git-flow gpg gpg-agent gpgconf gpgv
    htop iftop iotop lolcat lsd lshw mc net-tools psmisc pwgen
    ssh-tools task-ssh-server tree ufw wget zip zsh zsh-common zsh-doc
    fonts-powerline fonts-roboto fonts-droid-fallback neofetch
)

for package in "${PACKAGES[@]}"; do
    if ! dpkg -l | grep -q "^ii  $package "; then
        log "Installing $package..."
        aptitude install -y "$package" || warn "Failed to install $package"
    else
        log "$package is already installed"
    fi
done

# Install eza (modern replacement for ls)
log "Installing eza..."
if ! command -v eza &> /dev/null; then
    mkdir -p /etc/apt/keyrings || error "Failed to create keyrings directory"
    
    if wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | gpg --dearmor -o /etc/apt/keyrings/gierens.gpg; then
        echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | tee /etc/apt/sources.list.d/gierens.list
        chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
        apt update || warn "Failed to update package lists for eza"
        apt install -y eza || warn "Failed to install eza"
    else
        warn "Failed to add eza repository, skipping installation"
    fi
else
    log "eza is already installed"
fi

# SETUP FILES & DIRS
log "Setting up directories and files..."

# Function to create directories safely
create_dir() {
    local dir="$1"
    local permissions="$2"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || error "Failed to create directory: $dir"
        chmod "$permissions" "$dir"
        log "Created directory: $dir"
    fi
}

# Function to create files safely
create_file() {
    local file="$1"
    local permissions="$2"
    if [[ ! -f "$file" ]]; then
        touch "$file" || error "Failed to create file: $file"
        chmod "$permissions" "$file"
        log "Created file: $file"
    fi
}

# Create directories for root
create_dir "/root/.ssh" "700"
create_dir "/root/.config" "755"
create_dir "/root/.local" "755"

# Create directories for skel (new users)
create_dir "/etc/skel/.ssh" "700"
create_dir "/etc/skel/.config" "755"
create_dir "/etc/skel/.local" "755"
create_dir "/etc/skel/.local/bin" "755"

# Create files
create_file "/root/.ssh/authorized_keys" "600"
create_file "/root/.zlogin" "644"
create_file "/etc/skel/.ssh/authorized_keys" "600"
create_file "/etc/skel/.zlogin" "644"

# ADD ALIASES
log "Creating user aliases..."
cat > /etc/skel/.aliases.local << 'EOF'
# ~/.aliases.local: User-defined aliases
# This file is sourced by .bashrc and .zshrc

# ZSH config aliases
alias zshrc='nano ~/.zshrc'
alias zshconfig='nano ~/.zshrc'
alias ohmyzshrc='nano ~/.oh-my-zsh'
alias ohmyzshconfig='nano ~/.oh-my-zsh'

# Modern ls replacements (eza preferred, fallback to traditional ls with colors)
if command -v eza &> /dev/null; then
    alias ls='eza -ha --icons --group-directories-first --color-scale'
    alias l='eza -hal --icons --group-directories-first --color-scale'
    alias ll='l'
    alias tree='eza -Thal --icons --group-directories-first --color-scale'
else
    alias ls='ls --color=auto -hal'
    alias l='ls -hal'
    alias ll='l'
fi

# Editor aliases
alias bashrc='nano ~/.bashrc'
alias nanorc='nano ~/.nanorc'
alias nanoconfig='nano ~/.nanorc'
alias e='${EDITOR:-nano}'
alias v='${VISUAL:-nano}'

# System aliases
alias ln='ln -v'
alias mkdir='mkdir -p'
alias diff='diff --color'
alias clr='clear; echo Currently logged in on $TTY, as $USERNAME in directory $PWD.'

# Package management
alias app='aptitude -y'

# Git aliases
alias g=git
alias gitclone='git clone --recurse-submodules'
alias gc='git clone --recurse-submodules'
alias gitsub='git submodule add'

# Grep aliases
alias egrep='grep -E --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox}'
alias fgrep='grep -F --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox}'

# Path utilities
alias path='echo $PATH | tr -s ":" "\n"'

# Directory navigation shortcuts
alias 1='cd -1'
alias 2='cd -2'
alias 3='cd -3'
alias 4='cd -4'
alias 5='cd -5'
alias 6='cd -6'
alias 7='cd -7'
alias 8='cd -8'
alias 9='cd -9'

# Sudo alias
alias _='sudo '

# Development shortcuts
alias repos='cd ~/dev/git'
EOF

# SETUP LINUS RANTS
log "Setting up Linus Rants..."
if [[ ! -d /opt/linusrants ]]; then
    if git clone --recursive https://github.com/bhayward93/Linus-rants-ZSH.git /opt/linusrants; then
        chmod -R 644 /opt/linusrants
        
        # Create the linusrants wrapper script
        cat > /opt/linusrants.sh << 'EOF'
#!/bin/bash
# Linus Rants wrapper script
COWFILE="${1:-calvin}"
RANTS_FILE="/opt/linusrants/rants.tsv"

if [[ -f "$RANTS_FILE" ]]; then
    shuf -n 1 "$RANTS_FILE" | cut -f6 | cowsay -f "$COWFILE" | lolcat
else
    echo "Linus rants file not found!"
fi
EOF
        
        chmod +x /opt/linusrants.sh
        
        # Create symlinks safely
        [[ ! -e /usr/local/bin/linusrants ]] && ln -s /opt/linusrants.sh /usr/local/bin/linusrants
        [[ ! -e /usr/local/bin/cowsay ]] && ln -s /usr/games/cowsay /usr/local/bin/
        [[ ! -e /usr/local/bin/lolcat ]] && ln -s /usr/games/lolcat /usr/local/bin/
        [[ ! -e /usr/local/bin/cowthink ]] && ln -s /usr/games/cowthink /usr/local/bin/
        
        log "Linus Rants installed successfully"
    else
        warn "Failed to clone Linus Rants repository"
    fi
else
    log "Linus Rants already installed"
fi

# SETUP .zlogin FOR USERS' DEFAULTS
log "Setting up user .zlogin..."
cat > /etc/skel/.zlogin << 'EOF'
#!/bin/zsh
# Default user login script

clear
if command -v linusrants &> /dev/null; then
    linusrants calvin
fi

printf '=======================================\n'
printf '\n'
printf "###   Welcome %s!   ###\n" "$USER"
printf '\n'
printf '=======================================\n'
printf '\n'
printf 'Drink responsibly.™\n'
printf '\n'
EOF

# SETUP .zlogin for ROOT
log "Setting up root .zlogin..."
cat > /root/.zlogin << 'EOF'
#!/bin/zsh
# Root user login script

clear
if command -v neofetch &> /dev/null; then
    neofetch --ascii_distro "${ASCII_DISTRO:-auto}"
fi

printf '\n'
printf '| ------------------------ |\n'
printf '|                          |\n'
printf '|   !!! YOU ARE ROOT !!!   |\n'
printf '|                          |\n'
printf '| ======================== |\n'
printf '\n'
printf 'Drink responsibly.™\n'
printf '\n'
EOF

# ADD SUDO USER
log "Setting up SSH users group..."
groupadd -f sshusers

system_add_user() {
    local sudo_user sudo_pw sudo_pw_enc user_shell ssh_key
    
    # ASK FOR USERNAME
    echo -n "Username? [native]: "
    read -r sudo_user
    sudo_user="${sudo_user:-native}"
    
    # Validate username
    if [[ ! "$sudo_user" =~ ^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$ ]]; then
        error "Invalid username format"
    fi
    
    log "Username is set to: ${sudo_user}"

    # ASK FOR PASSWORD
    echo -n "Password? [changeme123]: "
    read -r -s sudo_pw
    echo # New line after hidden input
    sudo_pw="${sudo_pw:-changeme123}"
    
    # Generate encrypted password
    sudo_pw_enc=$(openssl passwd -1 "$sudo_pw")
    if [[ $? -ne 0 ]]; then
        error "Failed to encrypt password"
    fi
    
    log "Password is set!"

    # ASK FOR USER SHELL
    echo -n "Preferred Shell? [/usr/bin/zsh]: "
    read -r user_shell
    user_shell="${user_shell:-/usr/bin/zsh}"
    
    # Validate shell exists
    if [[ ! -x "$user_shell" ]]; then
        warn "Shell $user_shell not found, falling back to /bin/bash"
        user_shell="/bin/bash"
    fi
    
    log "Shell is set to: ${user_shell}"

    # CREATE USER
    if id "$sudo_user" &>/dev/null; then
        warn "User $sudo_user already exists"
    else
        useradd -p "$sudo_pw_enc" --create-home --shell "$user_shell" --user-group --groups sudo "$sudo_user" || error "Failed to create user"
        usermod -aG sshusers "$sudo_user" || warn "Failed to add user to sshusers group"
        log "User $sudo_user created successfully"
    fi

    # ADD USER TO SUDOERS PASSWORDLESS
    if [[ ! -f /etc/sudoers.orig ]]; then
        cp /etc/sudoers /etc/sudoers.orig || error "Failed to backup sudoers file"
    fi
    
    if ! grep -q "^$sudo_user ALL=(ALL) NOPASSWD: ALL" /etc/sudoers; then
        echo "$sudo_user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers || error "Failed to add user to sudoers"
        log "User has been added to sudoers with passwordless sudo!"
    fi

    # ASK FOR USER'S SSH KEY, IF LEFT BLANK GENERATE NEW KEY PAIR
    echo -n "SSH public key (leave blank to generate): "
    read -r ssh_key
    
    # Ensure user home directory and .ssh directory exist
    create_dir "/home/$sudo_user" "755"
    create_dir "/home/$sudo_user/.ssh" "700"
    chown -R "$sudo_user:$sudo_user" "/home/$sudo_user"
    
    if [[ -z "$ssh_key" ]]; then
        log "Generating new SSH key pair..."
        if sudo -u "$sudo_user" ssh-keygen -t ed25519 -f "/home/$sudo_user/.ssh/id_ed25519" -N "" -C "$sudo_user@$(hostname)"; then
            ssh_key=$(cat "/home/$sudo_user/.ssh/id_ed25519.pub")
            warn "IMPORTANT: Copy the private SSH key to somewhere safe!"
            echo "Private key location: /home/$sudo_user/.ssh/id_ed25519"
        else
            error "Failed to generate SSH key"
        fi
    fi
    
    # Add SSH key to authorized_keys
    echo "$ssh_key" > "/home/$sudo_user/.ssh/authorized_keys"
    chmod 600 "/home/$sudo_user/.ssh/authorized_keys"
    chown "$sudo_user:$sudo_user" "/home/$sudo_user/.ssh/authorized_keys"
    log "SSH key has been added to authorized_keys!"
    
    # Export for use in other functions
    export SUDO_USER="$sudo_user"
}

# Call the user creation function
system_add_user

# Install Z shell extensions for the new user
log "Installing Z shell extensions for $SUDO_USER..."
if command -v curl &> /dev/null; then
    sudo -u "$SUDO_USER" sh -c "$(curl -fsSL https://get.zshell.dev)" -- || warn "Failed to install Z shell extensions"
else
    warn "curl not available, skipping Z shell extensions installation"
fi

# Setup .zshrc file
if [[ ! -f "/home/$SUDO_USER/.zshrc" ]]; then
        log "Creating backup of ~/.zshrc..."
        mv /home/"$SUDO_USER"/.zshrc /home/"$SUDO_USER"/.zshrc.backup 
fi
log "Creating ~/.zshrc..."
touch /home/"$SUDO_USER"/.zshrc
cat > /home/"$SUDO_USER"/.zshrc << 'EOF'
# ZSH configuration file

# Initialize Zi
if [[ -r "/home/native/.config/zi/init.zsh" ]]; then
  source "/home/native/.config/zi/init.zsh" && zzinit
fi

# Enable Zi
typeset -A ZI
ZI[BIN_DIR]="${HOME}/.zi/bin"
source "${ZI[BIN_DIR]}/zi.zsh"

# Enable Zi completions
autoload -Uz _zi
(( ${+_comps} )) && _comps[zi]=_zi

# Set prompt (w/Git status when in ~/dev/projects)
zi nocd for \
  atload'!promptinit; typeset -g PSSHORT=0; prompt sprint3 yellow red green blue' \
    z-shell/zprompts

# Source env files
source ~/.aliases.dev && source ~/.aliases.local

# Add EZA (if installed)
export _EZA_PARAMS=('--header' '--all' '--long' '--git' '--group' '--group-directories-first' '--time-style=long-iso' '--color-scale=all' '--icons')
export eza_params=('--header' '--all' '--long' '--git' '--group' '--group-directories-first' '--time-style=long-iso' '--color-scale=all' '--icons')
alias ls='eza $eza_params'
alias l='eza --git-ignore $eza_params'
alias ll='eza --all --header --long $eza_params'
alias llm='eza --all --header --long --sort=modified $eza_params'
alias la='eza -lbhHigUmuSa'
alias lx='eza -lbhHigUmuSa@'
alias lt='eza --tree $eza_params'
alias tree='eza --tree $eza_params'

zi wait lucid for \
  has'eza' atinit'AUTOCD=0' \
    z-shell/zsh-eza
export AUTOCD=0

# Load ZBrowse variable browser (use: Ctrl-B)
zi load z-shell/ZUI
zi load z-shell/zbrowse

# Load Zi Console
zi load z-shell/zi-console

# Load Zi CMD Architect
zi load z-shell/zsh-cmd-architect

# Load Zi Convey
zi load z-shell/zconvey

# Load Zi Complete
zi load z-shell/zzcomplete

# Export user binary dirs
if [[ -r "/home/native/dev/scripts" ]]; then
  export PATH="/home/native/dev/scripts:$PATH"
fi
if [[ -r "/home/native/opt" ]]; then
  export PATH="/home/native/opt:$PATH"
fi
if [[ -r "/home/native/.local/bin" ]]; then
  export PATH="/home/native/.local/bin:$PATH" 
fi

# Hooks for direnv
eval "$(direnv hook zsh)"
EOF

system_configure_sshd() {
    log "Configuring SSH daemon..."
    
    # Backup original config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.orig || error "Failed to backup SSH config"
    
    # Create improved SSH configuration
    cat > /etc/ssh/sshd_config << 'EOF'
# Improved SSH configuration for security

# Network
Port 22
AddressFamily any
ListenAddress 0.0.0.0
ListenAddress ::

# Protocol and encryption
Protocol 2

# Authentication
LoginGraceTime 60
PermitRootLogin prohibit-password
StrictModes yes
MaxAuthTries 3
MaxSessions 10

# Public key authentication
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

# Password authentication (disabled for security)
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no

# Kerberos and GSSAPI
KerberosAuthentication no
GSSAPIAuthentication no

# Other authentication methods
HostbasedAuthentication no
IgnoreRhosts yes

# Forwarding
AllowTcpForwarding yes
AllowStreamLocalForwarding yes
GatewayPorts no
X11Forwarding yes
X11DisplayOffset 10
X11UseLocalhost yes

# Logging
SyslogFacility AUTH
LogLevel INFO

# Connection settings
ClientAliveInterval 300
ClientAliveCountMax 2
TCPKeepAlive yes

# Restrict access
AllowGroups sshusers

# Subsystems
Subsystem sftp /usr/lib/openssh/sftp-server

# PAM
UsePAM yes

# Banner
#Banner /etc/issue.net

# Accept environment variables
AcceptEnv LANG LC_*
EOF

    # Test configuration
    if sshd -t; then
        log "SSH configuration is valid"
    else
        error "SSH configuration is invalid, restoring original"
    fi
}
# Call SSH configuration
system_configure_sshd

# SETUP FIREWALL
system_security_ufw_install() {
    log "Configuring UFW firewall..."
    
    # Enable logging temporarily for setup
    ufw --force logging on
    
    # Set defaults
    ufw --force default deny incoming
    ufw --force default allow outgoing
    
    # Allow SSH with rate limiting
    ufw allow ssh/tcp
    ufw limit ssh/tcp
    
    log "UFW has been configured!"
    
    # Enable UFW
    ufw --force enable
    
    # Disable verbose logging for production
    ufw logging off
    
    # Enable UFW service
    systemctl enable ufw || warn "Failed to enable UFW service"
    
    log "Firewall setup complete"
}
# Call firewall setup
system_security_ufw_install

# Setup development environment
setup_development_environment() {
    log "Setting up development environment for $SUDO_USER..."
    
    local user_home="/home/$SUDO_USER"
    local scripts_dir="$user_home/.scripts"
    local nano_dir="$user_home/.nano"
    
    # Check for scripts directory
    if [[ ! -d "$scripts_dir" ]]; then
        log "Creating scripts directory..."
        sudo -u "$SUDO_USER" mkdir -p "$scripts_dir"
        
        # Note: Remove the hardcoded private key for security
        # Users should add their own deploy keys manually
        warn "Deploy keys should be added manually for security reasons"
    fi
    
    # Install enhanced nanorc if not present
    if [[ ! -d "$nano_dir" ]]; then
        log "Installing enhanced nano configuration..."
        if sudo -u "$SUDO_USER" wget -q https://raw.githubusercontent.com/scopatz/nanorc/master/install.sh -O- | sudo -u "$SUDO_USER" bash; then
            # Add nanorc include to user's nanorc
            if [[ -d "$nano_dir" ]]; then
                echo "include $nano_dir/*.nanorc" | sudo -u "$SUDO_USER" tee "$user_home/.nanorc" > /dev/null
            fi
            log "Enhanced nano configuration installed"
        else
            warn "Failed to install enhanced nano configuration"
        fi
    fi
}
# Call development environment setup
setup_development_environment

# WRAP UP
log "Finalizing setup..."

# Set correct permissions for Linus rants
if [[ -d /opt/linusrants ]]; then
    chmod -R 755 /opt/linusrants
fi

# Restart SSH service to apply new configuration
if systemctl restart ssh; then
    log "SSH service restarted successfully"
else
    warn "Failed to restart SSH service"
fi

# Display a fun message if available
if command -v linusrants &> /dev/null && [[ -f /usr/share/cowsay/cows/calvin.cow ]]; then
    linusrants calvin || echo "Welcome to your new Debian server!"
else
    echo "Welcome to your new Debian server!"
fi

echo ""
echo "###################################################################################"
log "Setup complete!"
echo ""
echo "Summary of changes:"
echo "- System packages updated and essential utilities installed"
echo "- User '$SUDO_USER' created with sudo privileges"
echo "- SSH daemon configured for security (key-based auth only)"
echo "- UFW firewall configured and enabled"
echo "- Development tools and aliases configured"
echo ""
echo "IMPORTANT NOTES:"
echo "- SSH password authentication is DISABLED for security"
echo "- Only users in 'sshusers' group can SSH to this server"
echo "- UFW firewall is active (SSH access is allowed)"
echo "- A system reboot is recommended to ensure all changes take effect"
echo "###################################################################################"
echo ""
