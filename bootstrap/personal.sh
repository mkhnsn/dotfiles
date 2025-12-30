

#!/usr/bin/env bash
set -euo pipefail

# Fully-loaded bootstrap for PERSONAL macOS machines.
#
# This is intentionally NOT run by GitHub Codespaces dotfiles automation.
# The universal entrypoint is ./install.sh.
#
# This script:
# - Assumes macOS (Darwin)
# - May prompt (Homebrew install, app permissions, etc.)
# - Is safe to re-run (idempotent-ish)

log() { printf '[personal] %s\n' "$*"; }

die() { echo "[personal] ERROR: $*" >&2; exit 1; }

if [[ "$(uname -s)" != "Darwin" ]]; then
  die "personal.sh is macOS-only. Use install.sh for generic bootstrap." 
fi

# --- Ensure chezmoi exists (should already be present if install.sh was used) ---
if ! command -v chezmoi >/dev/null 2>&1; then
  die "chezmoi not found. Run the repo root install.sh first." 
fi

CHEZMOI_SRC="$(chezmoi source-path)"
if [[ -z "${CHEZMOI_SRC:-}" || ! -d "$CHEZMOI_SRC" ]]; then
  die "could not determine chezmoi source-path"
fi

log "chezmoi source: $CHEZMOI_SRC"

# --- Homebrew ---
if ! command -v brew >/dev/null 2>&1; then
  log "Homebrew not found; installing…"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Ensure brew is in PATH for this session (Apple Silicon default)
  if [[ -x "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x "/usr/local/bin/brew" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

command -v brew >/dev/null 2>&1 || die "brew still not available after install"

# --- Brew bundle (your declarative toolchain) ---
if [[ -f "$CHEZMOI_SRC/Brewfile" ]]; then
  log "Installing/updating Brewfile deps…"
  brew bundle --file "$CHEZMOI_SRC/Brewfile"

  # Optional fzf keybindings/completion (safe if repeated)
  if [[ -x "$(brew --prefix)/opt/fzf/install" ]]; then
    log "Enabling fzf keybindings/completion (non-destructive)…"
    "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc || true
  fi
else
  log "No Brewfile found at $CHEZMOI_SRC/Brewfile; skipping brew bundle"
fi

# --- Ensure zsh is default shell ---
if command -v zsh >/dev/null 2>&1; then
  ZSH_PATH="$(command -v zsh)"
  if [[ "${SHELL:-}" != "$ZSH_PATH" ]]; then
    log "Setting default shell to zsh ($ZSH_PATH)…"
    chsh -s "$ZSH_PATH" || true
  fi
fi

# --- Apply dotfiles again (after brew installs new tools/completions) ---
log "Re-applying chezmoi (after brew)…"
chezmoi apply

# --- 1Password SSH Agent: lightweight setup (don’t manage generated files) ---
#
# We intentionally do NOT try to generate 1Password's agent.toml or its managed config.
# We only ensure your ~/.ssh/config includes the standard include + IdentityAgent.
# (Your repo already manages dot_config/ssh/config — this is a safety net.)

mkdir -p "$HOME/.ssh"
SSH_CONFIG="$HOME/.ssh/config"

ensure_line() {
  local file="$1" line="$2"
  grep -Fqx "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

if [[ ! -f "$SSH_CONFIG" ]]; then
  touch "$SSH_CONFIG"
  chmod 600 "$SSH_CONFIG" || true
fi

# Keep these near the top; order matters for Include in some setups.
if ! grep -Eq '^Include[[:space:]]+~/.ssh/1Password/config$' "$SSH_CONFIG"; then
  log "Ensuring ~/.ssh/config includes 1Password include…"
  # Prepend rather than append (so it’s earlier)
  tmp="$(mktemp)"
  {
    echo 'Include ~/.ssh/1Password/config'
    echo ''
    cat "$SSH_CONFIG"
  } > "$tmp"
  mv "$tmp" "$SSH_CONFIG"
fi

# Add a sensible default IdentityAgent stanza if not present.
if ! grep -Eq '^[[:space:]]*IdentityAgent[[:space:]]+"?~?/Library/Group Containers/2BUA8C4S2C\.com\.1password/t/agent\.sock"?' "$SSH_CONFIG"; then
  log "Ensuring ~/.ssh/config sets 1Password SSH agent socket…"
  cat >> "$SSH_CONFIG" <<'EOF'

Host *
  IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
EOF
fi

# --- VS Code: optional convenience ---
# We avoid forcing profiles here; your managed settings/templates handle that.
# This just prints helper commands.

if command -v code >/dev/null 2>&1; then
  log "VS Code detected. Your settings are managed by chezmoi; open them here:"
  log "  code \"$CHEZMOI_SRC/dot_config/Code/User/settings.json.tmpl\""
else
  log "VS Code 'code' CLI not found (fine)."
fi

# --- iTerm2: avoid managing plist directly ---
# Your repo may include a plist, but the safer pattern is:
# iTerm2 -> Preferences -> General -> Preferences -> 'Load preferences from a custom folder or URL'
# pointing at your repo path.

log "iTerm2 note: prefer iTerm2's 'Load preferences from a custom folder' over writing plist." 

log "Personal bootstrap complete. Restart your terminal (or 'exec zsh') to pick up shell changes."