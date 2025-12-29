# .zshrc - Zsh configuration for full stack development

# ============================================================================
# PATH Configuration
# ============================================================================
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.local/bin:$PATH"

# Homebrew (macOS)
if [[ -d "/opt/homebrew/bin" ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
fi

# Node.js (nvm)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Python (pyenv)
if command -v pyenv 1>/dev/null 2>&1; then
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
fi

# Ruby (rbenv)
if command -v rbenv 1>/dev/null 2>&1; then
    eval "$(rbenv init - zsh)"
fi

# Go
export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"

# Rust
export PATH="$HOME/.cargo/bin:$PATH"

# ============================================================================
# History Configuration
# ============================================================================
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY          # Write the history file in the ':start:elapsed;command' format
setopt INC_APPEND_HISTORY        # Write to the history file immediately, not when the shell exits
setopt SHARE_HISTORY             # Share history between all sessions
setopt HIST_IGNORE_DUPS          # Don't record an entry that was just recorded again
setopt HIST_IGNORE_ALL_DUPS      # Delete old recorded entry if new entry is a duplicate
setopt HIST_FIND_NO_DUPS         # Do not display a line previously found
setopt HIST_IGNORE_SPACE         # Don't record an entry starting with a space
setopt HIST_SAVE_NO_DUPS         # Don't write duplicate entries in the history file
setopt HIST_REDUCE_BLANKS        # Remove superfluous blanks before recording entry
setopt HIST_VERIFY               # Don't execute immediately upon history expansion

# ============================================================================
# Shell Options
# ============================================================================
setopt AUTO_CD                   # Go to folder path without using cd
setopt AUTO_PUSHD                # Push the old directory onto the stack on cd
setopt PUSHD_IGNORE_DUPS         # Do not store duplicates in the stack
setopt PUSHD_SILENT              # Do not print the directory stack after pushd or popd
setopt CORRECT                   # Spelling correction
setopt CDABLE_VARS               # Change directory to a path stored in a variable
setopt EXTENDED_GLOB             # Use extended globbing syntax

# ============================================================================
# Completion Configuration
# ============================================================================
autoload -Uz compinit
if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'  # Case insensitive tab completion
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"    # Colored completion
zstyle ':completion:*' rehash true                          # automatically find new executables in path
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache

# ============================================================================
# Prompt Configuration
# ============================================================================
autoload -Uz vcs_info
precmd() { vcs_info }

zstyle ':vcs_info:git:*' formats ' (%b)'
setopt PROMPT_SUBST

# Colors
autoload -U colors && colors

# Prompt
PROMPT='%F{cyan}%n@%m%f:%F{blue}%~%f%F{yellow}${vcs_info_msg_0_}%f %# '

# ============================================================================
# Environment Variables
# ============================================================================
export EDITOR='vim'
export VISUAL='vim'
export PAGER='less'
export LESS='-R'
export LANG='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'

# ============================================================================
# Aliases - General
# ============================================================================
# ls aliases (use GNU ls colors if available)
if ls --color > /dev/null 2>&1; then
    alias ls='ls --color=auto'
else
    alias ls='ls -G'
fi
alias ll='ls -lh'
alias la='ls -lAh'
alias l='ls -CF'

# Directory navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# Safety aliases
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Shortcuts
alias c='clear'
alias h='history'
alias j='jobs -l'
alias df='df -h'
alias du='du -h'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# ============================================================================
# Aliases - Git
# ============================================================================
alias g='git'
alias gs='git status'
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit -v'
alias gcm='git commit -m'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gb='git branch'
alias gbd='git branch -d'
alias gp='git push'
alias gpl='git pull'
alias gf='git fetch'
alias gl='git log --oneline --decorate --graph'
alias gla='git log --oneline --decorate --graph --all'
alias gd='git diff'
alias gds='git diff --staged'
alias gst='git stash'
alias gstp='git stash pop'

# ============================================================================
# Aliases - Docker
# ============================================================================
alias d='docker'
alias dc='docker-compose'
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias dex='docker exec -it'
alias dlog='docker logs -f'
alias dstop='docker stop $(docker ps -q)'
alias drm='docker rm $(docker ps -aq)'
alias drmi='docker rmi $(docker images -q)'

# ============================================================================
# Aliases - Node.js / npm / yarn
# ============================================================================
alias ni='npm install'
alias nid='npm install --save-dev'
alias nig='npm install -g'
alias nr='npm run'
alias ns='npm start'
alias nt='npm test'
alias nrd='npm run dev'
alias nrb='npm run build'

alias yi='yarn install'
alias ya='yarn add'
alias yad='yarn add --dev'
alias yr='yarn run'
alias ys='yarn start'
alias yt='yarn test'
alias yrd='yarn run dev'
alias yrb='yarn run build'

# ============================================================================
# Aliases - Python
# ============================================================================
alias py='python3'
alias python='python3'
alias pip='pip3'
alias venv='python3 -m venv'
alias activate='source venv/bin/activate'

# ============================================================================
# Aliases - Utilities
# ============================================================================
alias myip='curl -s http://ipecho.net/plain; echo'
alias localip='ipconfig getifaddr en0'
alias ports='netstat -tulanp'
alias psg='ps aux | grep -v grep | grep -i -e VSZ -e'

# Reload zsh config
alias reload='source ~/.zshrc'

# Quick edit configs
alias zshconfig='$EDITOR ~/.zshrc'
alias gitconfig='$EDITOR ~/.gitconfig'
alias vimconfig='$EDITOR ~/.vimrc'

# ============================================================================
# Functions
# ============================================================================

# Make directory and cd into it
mkcd() {
    mkdir -p "$@" && cd "$_"
}

# Extract archives
extract() {
    if [ -f $1 ]; then
        case $1 in
            *.tar.bz2)   tar xjf $1     ;;
            *.tar.gz)    tar xzf $1     ;;
            *.bz2)       bunzip2 $1     ;;
            *.rar)       unrar e $1     ;;
            *.gz)        gunzip $1      ;;
            *.tar)       tar xf $1      ;;
            *.tbz2)      tar xjf $1     ;;
            *.tgz)       tar xzf $1     ;;
            *.zip)       unzip $1       ;;
            *.Z)         uncompress $1  ;;
            *.7z)        7z x $1        ;;
            *)     echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Create a backup of a file
backup() {
    cp "$1"{,.backup-$(date +%Y%m%d-%H%M%S)}
}

# Find file by name
ff() {
    find . -type f -iname "*$1*"
}

# Find directory by name
fd() {
    find . -type d -iname "*$1*"
}

# Change to project directory
cdp() {
    cd ~/Projects/$1
}

# Start a simple HTTP server
serve() {
    local port="${1:-8000}"
    python3 -m http.server "$port"
}

# ============================================================================
# Load local customizations
# ============================================================================
if [ -f ~/.zshrc.local ]; then
    source ~/.zshrc.local
fi
