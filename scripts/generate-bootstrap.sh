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
BOOTSTRAP_DIR="$DOTFILES_DIR/../bootstrap"

log() { printf "[generate] %s\n" "$*"; }
err() { printf "[generate] ERROR: %s\n" "$*" >&2; }

# ─────────────────────────────────────────────────────────────
# Validate paths
# ─────────────────────────────────────────────────────────────

if [[ ! -d "$SCRIPT_DIR/templates" ]]; then
  err "Templates directory not found: $SCRIPT_DIR/templates"
  exit 1
fi

if [[ ! -d "$BOOTSTRAP_DIR" ]]; then
  err "Bootstrap repo not found at: $BOOTSTRAP_DIR"
  log "Expected bootstrap to be a sibling directory of dotfiles"
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
