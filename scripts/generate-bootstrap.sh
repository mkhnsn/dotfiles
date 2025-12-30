#!/usr/bin/env bash
set -euo pipefail

# generate-bootstrap.sh
# Generates the bootstrap scripts from templates
# Templates live in: scripts/templates/
# Output: ../bootstrap/ (sibling directory)
#
# Usage:
#   ./scripts/generate-bootstrap.sh        (from dotfiles root)
#   cd scripts && ./generate-bootstrap.sh  (from scripts directory)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"

log() { printf "[generate] %s\n" "$*"; }
err() { printf "[generate] ERROR: %s\n" "$*" >&2; }

# Best-effort realpath (macOS has `realpath`; fallback to python)
_realpath() {
  if command -v realpath >/dev/null 2>&1; then
    realpath "$1"
  elif command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import os,sys
print(os.path.realpath(sys.argv[1]))
PY
  else
    # Fallback: not perfect, but better than nothing
    echo "$(cd \"$(dirname \"$1\")\" && pwd)/$(basename \"$1\")"
  fi
}

_is_git_repo() {
  command -v git >/dev/null 2>&1 || return 1
  git -C "$1" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

_git_remote_url() {
  command -v git >/dev/null 2>&1 || return 1
  git -C "$1" config --get remote.origin.url 2>/dev/null || true
}

_warn_if_not_bootstrap_repo() {
  local dir="$1"
  local url
  url="$(_git_remote_url "$dir")"
  # Non-fatal: we just want to protect you from accidentally writing into the wrong repo.
  if [[ -n "$url" ]] && [[ "$url" != *"bootstrap"* ]]; then
    log "WARNING: '$dir' origin remote does not look like the bootstrap repo: $url"
  fi
}

# ─────────────────────────────────────────────────────────────
# Find bootstrap directory
# ─────────────────────────────────────────────────────────────

# Try common locations for bootstrap repo
BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-}"

if [[ -z "$BOOTSTRAP_DIR" ]]; then
  # Try sibling directory first
  if [[ -d "$DOTFILES_DIR/../bootstrap" ]]; then
    BOOTSTRAP_DIR="$DOTFILES_DIR/../bootstrap"
  # Try user's src directory
  elif [[ -d "$HOME/src/bootstrap" ]]; then
    BOOTSTRAP_DIR="$HOME/src/bootstrap"
  # Try as env variable
  elif [[ -n "${BOOTSTRAP_REPO:-}" ]]; then
    BOOTSTRAP_DIR="$BOOTSTRAP_REPO"
  else
    err "Bootstrap repo not found"
    log "Tried:"
    log "  • $DOTFILES_DIR/../bootstrap"
    log "  • $HOME/src/bootstrap"
    log ""
    log "Set BOOTSTRAP_DIR environment variable:"
    log "  BOOTSTRAP_DIR=/path/to/bootstrap ./scripts/generate-bootstrap.sh"
    exit 1
  fi
fi

if [[ ! -d "$SCRIPT_DIR/templates" ]]; then
  err "Templates directory not found: $SCRIPT_DIR/templates"
  exit 1
fi

if [[ ! -d "$BOOTSTRAP_DIR" ]]; then
  err "Bootstrap repo not found at: $BOOTSTRAP_DIR"
  exit 1
fi

# Normalize paths so we can safely compare
DOTFILES_DIR_REAL="$(_realpath "$DOTFILES_DIR")"
BOOTSTRAP_DIR_REAL="$(_realpath "$BOOTSTRAP_DIR")"

# Safety rails: refuse to write into the dotfiles repo (or a subdir of it)
if [[ "$BOOTSTRAP_DIR_REAL" == "$DOTFILES_DIR_REAL" ]] || [[ "$BOOTSTRAP_DIR_REAL" == "$DOTFILES_DIR_REAL"/* ]]; then
  err "Refusing to generate into '$BOOTSTRAP_DIR_REAL' because it is inside the dotfiles repo ($DOTFILES_DIR_REAL)."
  err "Point BOOTSTRAP_DIR at your separate bootstrap repo checkout."
  exit 1
fi

# Optional sanity check: if it's a git repo, warn if it doesn't look like the bootstrap repo
if _is_git_repo "$BOOTSTRAP_DIR_REAL"; then
  _warn_if_not_bootstrap_repo "$BOOTSTRAP_DIR_REAL"
else
  log "NOTE: '$BOOTSTRAP_DIR_REAL' is not a git repo (or git not installed). Proceeding anyway."
fi

log "Dotfiles directory: $DOTFILES_DIR"
log "Bootstrap directory: $BOOTSTRAP_DIR"

# ─────────────────────────────────────────────────────────────
# Generate scripts from templates
# ─────────────────────────────────────────────────────────────

log ""
log "Generating bootstrap scripts..."

# Generate minimal.sh
if [[ ! -f "$SCRIPT_DIR/templates/minimal.sh.template" ]]; then
  err "Template not found: minimal.sh.template"
  exit 1
fi

log "Generating minimal.sh"
tmp_min="$(mktemp)"
cp "$SCRIPT_DIR/templates/minimal.sh.template" "$tmp_min"
chmod +x "$tmp_min"
if [[ -f "$BOOTSTRAP_DIR/minimal.sh" ]] && cmp -s "$tmp_min" "$BOOTSTRAP_DIR/minimal.sh"; then
  rm -f "$tmp_min"
  log "minimal.sh unchanged"
else
  mv "$tmp_min" "$BOOTSTRAP_DIR/minimal.sh"
  log "minimal.sh updated"
fi

# Generate full.sh
if [[ ! -f "$SCRIPT_DIR/templates/full.sh.template" ]]; then
  err "Template not found: full.sh.template"
  exit 1
fi

log "Generating full.sh"
tmp_full="$(mktemp)"
cp "$SCRIPT_DIR/templates/full.sh.template" "$tmp_full"
chmod +x "$tmp_full"
if [[ -f "$BOOTSTRAP_DIR/full.sh" ]] && cmp -s "$tmp_full" "$BOOTSTRAP_DIR/full.sh"; then
  rm -f "$tmp_full"
  log "full.sh unchanged"
else
  mv "$tmp_full" "$BOOTSTRAP_DIR/full.sh"
  log "full.sh updated"
fi

# ─────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────

log ""
log "✓ Bootstrap scripts generated"
log ""
log "Generated files:"
log "  • $BOOTSTRAP_DIR_REAL/minimal.sh"
log "  • $BOOTSTRAP_DIR_REAL/full.sh"
log ""
log "Next steps:"
log "  1. Review changes: cd $BOOTSTRAP_DIR && git diff"
log "  2. Commit in bootstrap: git add *.sh && git commit -m 'scripts: regenerated from dotfiles'"
log "  3. Commit in dotfiles: git add scripts/templates && git commit -m 'bootstrap: update templates'"
log ""
