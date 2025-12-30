# Aliases (managed by chezmoi)

if command -v eza >/dev/null 2>&1; then
  alias ll='eza -alF --group-directories-first'
  alias la='eza -A'
  alias l='eza'
else
  alias ll='ls -alF'
  alias la='ls -A'
  alias l='ls -CF'
fi

# Git muscle-memory shortcuts (shell-level)
alias g='git'
alias gb='git branch'
alias gbd='git branch -d'
alias gd='git diff'
alias gst='git status -sb'
alias gco='git checkout'
alias gsw='git switch'
alias gl='git log --oneline --decorate --graph --all'
alias ga='git add'
alias gaa='git add -A'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gp='git push'
alias gpf='git push --force-with-lease'
alias gup='git pull --rebase'

alias tree='tree -C -L 3 --dirsfirst'
alias treee="tree -C --gitignore -a -I '.git' --dirsfirst"