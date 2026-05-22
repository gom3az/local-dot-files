# =========================================
# Environment (Ported from .bashrc)
# =========================================
export JAVA_HOME=/opt/android-studio/jbr
export PATH="$JAVA_HOME/bin:$HOME/.local/bin:$HOME/bin:/home/test/.opencode/bin:/opt/gradle/gradle-9.2.0/bin:/opt/intellij/bin:$HOME/.npm-global/bin:$PATH"
export EDITOR=nvim
export VISUAL=nvim

# Rootless Docker
export DOCKER_HOST=unix:///run/user/1001/docker.sock
export PATH="$HOME/.local/bin:$PATH"

# =========================================
# Zsh Quality of Life
# =========================================
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
setopt SHARE_HISTORY
setopt APPEND_HISTORY

# Fix for Home/End keys in Fedora terminal
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line

# =========================================
# Prompt Engine
# =========================================
# If you want to keep Oh My Posh:
# eval "$(oh-my-posh init zsh --config /home/test/.cache/oh-my-posh/themes/agnoster.omp.json)"

# OR, if you want to try Starship (it's faster in Zsh):
eval "$(starship init zsh)"

# =========================================
# Sourcing bash-style fragments
# =========================================
# If you have aliases in ~/.bashrc.d, Zsh can usually source them fine:
if [ -d ~/.bashrc.d ]; then
  for rc in ~/.bashrc.d/*; do
    [ -f "$rc" ] && source "$rc"
  done
fi

# =========================================
# Plugins (Requires: sudo dnf install zsh-autosuggestions zsh-syntax-highlighting)
# =========================================

# 1. Load Autosuggestions (Fish-like grey text)
if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# 2. Load Syntax Highlighting (Must be loaded LAST)
if [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
# =========================================
# Advanced Completion Settings
# =========================================
# The quotes around the asterisk and patterns prevent the "* not found" error
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}' 'r:|[._-]=* r:|=*' 'l:|=*'

# Better arrow-key navigation in the Tab menu
bindkey '^[[Z' reverse-menu-complete  # Shift-Tab to go backwards

# ==========================
# ZSH History Configuration
# ==========================

# Where to save the history
HISTFILE=~/.zsh_history

# How many commands to load into memory
HISTSIZE=10000 

# How many commands to save to the file
SAVEHIST=10000 

# Core history options
setopt APPEND_HISTORY        # Append to history file instead of replacing it
setopt SHARE_HISTORY         # Share history across all active zsh sessions
setopt INC_APPEND_HISTORY    # Save commands to the history file immediately

# Quality-of-Life history options (Optional but recommended)
setopt HIST_IGNORE_ALL_DUPS  # Remove older duplicate commands from history
setopt HIST_IGNORE_SPACE     # Don't save commands that start with a space
setopt HIST_REDUCE_BLANKS    # Remove superfluous blanks before saving

