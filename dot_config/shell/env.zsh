# Environment / PATH (managed by chezmoi)

export EDITOR="code --wait"

# PATH basics
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/src/scripts:$PATH"

# ---- 1Password CLI / chezmoi integration ----
# Pin the default 1Password account so chezmoi/op never prompt.
# Only set this if `op` exists, so we don't leak env noise into minimal shells.
if command -v op >/dev/null 2>&1; then
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



# Fuzzy git branch checkout
gcof() {
  local b
  b="$(
    git branch --all --format='%(refname:short)' 2>/dev/null \
      | sed '/^HEAD$/d' \
      | sed '/->/d' \
      | fzf
  )" || return
  git checkout "$b"
}

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
  fpath_prepend "$(brew --prefix)/share/zsh-completions"
  fpath_prepend "$(brew --prefix)/share/zsh/site-functions"
fi

# System zsh completions (npm often lives here)
for d in \
  "/usr/share/zsh/site-functions" \
  "/usr/local/share/zsh/site-functions" \
  "/usr/share/zsh/${ZSH_VERSION}/functions" \
  "/usr/share/zsh/functions" \
  "/usr/share/zsh" \
; do
  [[ -d "$d" ]] && fpath_prepend "$d"
done

# pnpm (global bins)
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

autoload -Uz compinit
ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
mkdir -p "${ZSH_COMPDUMP:h}" 2>/dev/null || true

# -C: use cached .zcompdump when possible (fast)
# -i: ignore insecure directories (prevents noisy prompts on fresh boxes)
# Do NOT use -u (unsafe) globally.
compinit -i -d "$ZSH_COMPDUMP"

# special case for npm completion
autoload -Uz _npm 2>/dev/null || true
(( $+functions[_npm] )) && compdef _npm npm 2>/dev/null || true

#-------------------------------------------------------------------------------
#---- most settings should come after this line! -------------------------------
#-------------------------------------------------------------------------------

# ---- fzf keybindings/completion  ----
# Prefer the user's ~/.fzf.zsh (installed by brew or the upstream fzf installer).
if [[ -r "$HOME/.fzf.zsh" ]]; then
  source "$HOME/.fzf.zsh"
else
  # Fallback: some distros place these in /usr/share (paths vary). Try common locations.
  [[ -r "/usr/share/fzf/key-bindings.zsh" ]] && source "/usr/share/fzf/key-bindings.zsh"
  [[ -r "/usr/share/fzf/completion.zsh" ]] && source "/usr/share/fzf/completion.zsh"
  [[ -r "/usr/share/doc/fzf/examples/key-bindings.zsh" ]] && source "/usr/share/doc/fzf/examples/key-bindings.zsh"
  [[ -r "/usr/share/doc/fzf/examples/completion.zsh" ]] && source "/usr/share/doc/fzf/examples/completion.zsh"
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
unsetopt MENU_COMPLETE          # don't replace text by cycling matches
setopt AUTO_MENU               # show menu when there are multiple matches
setopt COMPLETE_IN_WORD        # complete from cursor, not just end
setopt ALWAYS_TO_END           # move cursor to end after completion
setopt NO_BEEP                 # stop yelling at me

# Make selection explicit when there are many matches
zstyle ':completion:*' menu select
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%d'
zstyle ':completion:*:messages' format '%d'
zstyle ':completion:*:warnings' format '%d'

# ---- zsh plugins (loaders) ----
for f in "$HOME/.config/zsh/plugins.d/"*.zsh(N); do
  source "$f"
done

# 1Password SSH agent socket (macOS only; don't stomp whatever agent a Linux box already uses)
if [[ "${OSTYPE:-}" == darwin* ]]; then
  OP_SSH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
  [[ -S "$OP_SSH_SOCK" ]] && export SSH_AUTH_SOCK="$OP_SSH_SOCK"
fi

# Rust
[[ -r "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

# Homebrew OpenSSL hint (only if brew exists)
if command -v brew >/dev/null 2>&1; then
  export OPENSSL_ROOT_DIR="$(brew --prefix openssl@3 2>/dev/null)"
fi

