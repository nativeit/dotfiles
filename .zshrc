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
