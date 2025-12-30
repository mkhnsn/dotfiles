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
cp "$SCRIPT_DIR/templates/minimal.sh.template" "$BOOTSTRAP_DIR/minimal.sh"
chmod +x "$BOOTSTRAP_DIR/minimal.sh"

# Generate full.sh
if [[ ! -f "$SCRIPT_DIR/templates/full.sh.template" ]]; then
  err "Template not found: full.sh.template"
  exit 1
fi

log "Generating full.sh"
cp "$SCRIPT_DIR/templates/full.sh.template" "$BOOTSTRAP_DIR/full.sh"
chmod +x "$BOOTSTRAP_DIR/full.sh"

# ─────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────

log ""
log "✓ Bootstrap scripts generated"
log ""
log "Generated files:"
log "  • $BOOTSTRAP_DIR/minimal.sh"
log "  • $BOOTSTRAP_DIR/full.sh"
log ""
log "Next steps:"
log "  1. Review changes: cd $BOOTSTRAP_DIR && git diff"
log "  2. Commit in bootstrap: git add *.sh && git commit -m 'scripts: regenerated from dotfiles'"
log "  3. Commit in dotfiles: git add scripts/templates && git commit -m 'bootstrap: update templates'"
log ""
