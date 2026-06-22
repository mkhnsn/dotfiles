# Environment / PATH (managed by chezmoi)

export EDITOR="code --wait"

# ---- history ----
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY          # share history across sessions in real time
setopt HIST_IGNORE_ALL_DUPS   # deduplicate older entries
setopt HIST_REDUCE_BLANKS     # trim whitespace
setopt HIST_IGNORE_SPACE      # lines starting with space are private
setopt APPEND_HISTORY         # append, don't overwrite

# PATH basics
# Include both ~/.local/bin and ~/bin: the chezmoi installer drops its binary in
# one or the other depending on flags, and WSL's default PATH includes neither.
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"
export PATH="$HOME/src/github.com/mkhnsn/scripts/:$PATH"

# macOS-only paths
if [[ "${OSTYPE:-}" == darwin* ]]; then
  [[ -d "/Applications/iTerm.app" ]] && \
    export PATH="/Applications/iTerm.app/Contents/Resources/utilities:$PATH"
fi

# opencode
export PATH="$HOME/.opencode/bin:$PATH"

# ghq root
if command -v ghq >/dev/null 2>&1; then
  export GHQ_ROOT="$HOME/src"
  mkdir -p "$GHQ_ROOT" 2>/dev/null || true
fi


# ---- 1Password CLI / chezmoi integration ----
# Headless/WSL boxes authenticate with a service-account token instead of the
# desktop app. Persist it in ~/.config/op/service-account.env (0600, gitignored,
# written by run_once_05-1password) so `chezmoi apply` works in fresh shells.
[[ -r "$HOME/.config/op/service-account.env" ]] && \
  source "$HOME/.config/op/service-account.env"

# Pin the default 1Password account so chezmoi/op never prompt — but only in
# desktop-app (account) mode. Under a service token, OP_ACCOUNT is irrelevant
# and selecting an account just adds confusion.
if command -v op >/dev/null 2>&1 && [[ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
  export OP_ACCOUNT="unstablestudios.1password.com"
fi

# ---- fzf defaults ----
# Use fd if available (faster, respects .gitignore-ish behavior)
# Ubuntu sometimes ships it as `fd-find`.
if command -v fd >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
elif command -v fd-find >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fd-find --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi
export FZF_CTRL_R_OPTS='--scheme=history'

# ---- completions dir ----
ZSH_COMPLETIONS_DIR="$HOME/.config/zsh/completions"
mkdir -p "$ZSH_COMPLETIONS_DIR" 2>/dev/null || true

# Prepend to fpath if not already present
fpath_prepend() {
  local d="$1"
  [[ -d "$d" ]] || return 0
  local p
  for p in $fpath; do
    [[ "$p" == "$d" ]] && return 0
  done
  fpath=("$d" $fpath)
}

fpath_prepend "$ZSH_COMPLETIONS_DIR"

# Homebrew completions (if available)
if command -v brew >/dev/null 2>&1; then
  _brew_prefix="$(brew --prefix)"
  fpath_prepend "$_brew_prefix/share/zsh-completions"
  fpath_prepend "$_brew_prefix/share/zsh/site-functions"

  # Homebrew node ships a bash-style _npm that shadows the proper zsh one.
  # Remove it so /usr/share/zsh/*/functions/_npm (with #compdef) wins.
  [[ -L "$_brew_prefix/share/zsh/site-functions/_npm" ]] && \
    rm -f "$_brew_prefix/share/zsh/site-functions/_npm"
fi

# System zsh completions
for d in \
  "/usr/share/zsh/site-functions" \
  "/usr/local/share/zsh/site-functions" \
  "/usr/share/zsh/${ZSH_VERSION}/functions" \
; do
  [[ -d "$d" ]] && fpath_prepend "$d"
done

# pnpm (global bins)
if [[ "${OSTYPE:-}" == darwin* ]]; then
  export PNPM_HOME="$HOME/Library/pnpm"
else
  export PNPM_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/pnpm"
fi
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

autoload -Uz compinit
ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
mkdir -p "${ZSH_COMPDUMP:h}" 2>/dev/null || true

# -i: ignore insecure directories (prevents noisy prompts on fresh boxes)
# Do NOT use -u (unsafe) globally.
compinit -i -d "$ZSH_COMPDUMP"

# OpenClaw Completion (cached — regenerate: rm ~/.cache/zsh/openclaw-completion.zsh)
_openclaw_comp="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/openclaw-completion.zsh"
if [[ ! -f "$_openclaw_comp" ]] && command -v openclaw >/dev/null 2>&1; then
  mkdir -p "${_openclaw_comp:h}" 2>/dev/null || true
  openclaw completion --shell zsh > "$_openclaw_comp" 2>/dev/null
fi
[[ -r "$_openclaw_comp" ]] && source "$_openclaw_comp"

#-------------------------------------------------------------------------------
#---- most settings should come after this line! -------------------------------
#-------------------------------------------------------------------------------

# ---- fzf keybindings ----
# Source fzf for Ctrl-T, Ctrl-R, Alt-C keybindings.
# fzf also binds ^I (TAB) to its own fzf-completion widget, but fzf-tab
# (loaded later) already provides fzf-powered completion for everything.
# Reset ^I after sourcing so fzf-tab wraps expand-or-complete directly,
# avoiding a redundant context-switch layer that breaks some completions.
if [[ -r "$HOME/.fzf.zsh" ]]; then
  source "$HOME/.fzf.zsh"
  bindkey '^I' expand-or-complete
else
  # Fallback: some distros place these in /usr/share (paths vary). Try common locations.
  for _fzf_f in \
    "/usr/share/fzf/key-bindings.zsh" \
    "/usr/share/doc/fzf/examples/key-bindings.zsh" \
  ; do
    [[ -r "$_fzf_f" ]] && { source "$_fzf_f"; break; }
  done
  unset _fzf_f
fi

# ---- word/path semantics ----
# Make "word" jumps behave like path/arg jumps (/, -, ., _ become boundaries)
WORDCHARS=''

# ---- Option+Arrow / Option+Delete word ops (portable) ----
for km in emacs viins; do
  # Move by word
  bindkey -M $km '^[b'      backward-word   # Meta-b (common)
  bindkey -M $km '^[f'      forward-word    # Meta-f (common)
  bindkey -M $km '^[[1;9D'  backward-word   # ⌥← (iTerm2 variant)
  bindkey -M $km '^[[1;9C'  forward-word    # ⌥→ (iTerm2 variant)
  bindkey -M $km '^[[1;3D'  backward-word   # ⌥← (alt variant)
  bindkey -M $km '^[[1;3C'  forward-word    # ⌥→ (alt variant)

  # Delete word backward (⌥⌫)
  bindkey -M $km '^[^?'     backward-kill-word
  bindkey -M $km '^[^H'     backward-kill-word
  bindkey -M $km '^[\b'     backward-kill-word

  # Delete word forward (⌥⌦)
  bindkey -M $km '^[[3;3~'  kill-word
  bindkey -M $km '^[[3;9~'  kill-word
done

# ---- completion UX: don't destroy my buffer ----
setopt COMPLETE_IN_WORD        # complete from cursor, not just end
setopt ALWAYS_TO_END           # move cursor to end after completion
setopt NO_BEEP                 # stop yelling at me

# Make selection explicit when there are many matches
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%d'
zstyle ':completion:*:messages' format '%d'
zstyle ':completion:*:warnings' format 'No matches for: %d'

# ---- zsh plugins (loaders) ----
for f in "$HOME/.config/zsh/plugins.d/"*.zsh(N); do
  source "$f"
done

if command -v brew >/dev/null 2>&1; then
  _brew_prefix="${_brew_prefix:-$(brew --prefix)}"

  # zsh-syntax-highlighting
  [[ -r "$_brew_prefix/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && \
    source "$_brew_prefix/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

  # zsh-autosuggestions
  [[ -r "$_brew_prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && \
    source "$_brew_prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh"

else
  # Linux: try common package locations
  for _zsh_plugin in \
    "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
    "/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  ; do
    [[ -r "$_zsh_plugin" ]] && { source "$_zsh_plugin"; break; }
  done

  for _zsh_plugin in \
    "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh" \
    "/usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  ; do
    [[ -r "$_zsh_plugin" ]] && { source "$_zsh_plugin"; break; }
  done
  unset _zsh_plugin
fi
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"
ZSH_AUTOSUGGEST_STRATEGY=(match_prev_cmd completion)

typeset -A ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[default]=none
ZSH_HIGHLIGHT_STYLES[unknown-token]=fg=red,bold
ZSH_HIGHLIGHT_STYLES[reserved-word]=fg=green
ZSH_HIGHLIGHT_STYLES[alias]=none
ZSH_HIGHLIGHT_STYLES[builtin]=none
ZSH_HIGHLIGHT_STYLES[function]=none
ZSH_HIGHLIGHT_STYLES[command]=none
ZSH_HIGHLIGHT_STYLES[precommand]=none
ZSH_HIGHLIGHT_STYLES[commandseparator]=none
ZSH_HIGHLIGHT_STYLES[hashed-command]=none
ZSH_HIGHLIGHT_STYLES[path]=none
ZSH_HIGHLIGHT_STYLES[globbing]=none
ZSH_HIGHLIGHT_STYLES[history-expansion]=fg=blue
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]=none
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]=none
ZSH_HIGHLIGHT_STYLES[back-quoted-argument]=none
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]=fg=yellow
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]=fg=yellow
ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]=fg=cyan
ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]=fg=cyan
ZSH_HIGHLIGHT_STYLES[assign]=none

# 1Password SSH agent socket (macOS only; don't stomp whatever agent a Linux box already uses)
if [[ "${OSTYPE:-}" == darwin* ]]; then
  OP_SSH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
  [[ -S "$OP_SSH_SOCK" ]] && export SSH_AUTH_SOCK="$OP_SSH_SOCK"
fi

# Rust
[[ -r "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

# ntfy: auto-notify when long-running commands finish in an unfocused terminal.
# Reads ~/.ntfy.yml (Pushover or other backends). Skip with AUTO_NTFY_DONE_IGNORE.
if command -v ntfy >/dev/null 2>&1; then
  export AUTO_NTFY_DONE_IGNORE="${AUTO_NTFY_DONE_IGNORE:-vim nvim micro less more man tmux screen ssh mosh htop btop ncdu yazi watch fzf claude}"
  eval "$(ntfy shell-integration 2>/dev/null)" 2>/dev/null || true
fi

# Homebrew OpenSSL hint (only if brew exists)
if command -v brew >/dev/null 2>&1; then
  _brew_prefix="${_brew_prefix:-$(brew --prefix)}"
  export OPENSSL_ROOT_DIR="$_brew_prefix/opt/openssl@3"
fi

# System pager defaults
export PAGER='less'
export LESS='-R -F -X --mouse'

# Better cat (interactive only)
if command -v bat >/dev/null 2>&1; then
  alias cat='bat --paging=auto'
fi

# Prefer bat for previewing files
export BAT_PAGER='less -RFX --mouse'
export BAT_THEME='GitHub'   # or Nord, Dracula, GitHub, etc.

# Man pages through bat (colorized, searchable)
if command -v bat >/dev/null 2>&1; then
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
else
  export MANPAGER='less -R --mouse'
fi
export LESS_TERMCAP_md=$'\e[1m'   # bold
export LESS_TERMCAP_me=$'\e[0m'   # reset
