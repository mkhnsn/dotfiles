#!/usr/bin/env bash
set -euo pipefail

# GitHub Codespaces dotfiles entrypoint (also safe to run anywhere).
#
# Design goals:
# - Works when GitHub has cloned this repo (Codespaces dotfiles feature).
# - Works when executed via curl from raw GitHub (no local repo present).
# - Idempotent and non-invasive: only ensures chezmoi exists and applies.
# - Keeps "personal-machine full setup" out of here (that goes in bootstrap/personal.sh).

DOTFILES_REPO_DEFAULT="mkhnsn/dotfiles"
DOTFILES_REPO="${DOTFILES_REPO:-$DOTFILES_REPO_DEFAULT}"
CHEZMOI_BIN="${CHEZMOI_BIN:-chezmoi}"

# Directory of this script (only meaningful when the repo is already cloned locally).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '[dotfiles] %s\n' "$*"; }

# ---- Minimal prereqs (Linux only; skip if we can't elevate) ----
if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive

  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    log "apt-get: installing minimal prereqs (git/curl/ca-certificates)"
    apt-get update -y
    apt-get install -y git curl ca-certificates
  elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    log "apt-get: installing minimal prereqs with sudo (git/curl/ca-certificates)"
    sudo -n apt-get update -y
    sudo -n apt-get install -y git curl ca-certificates
  else
    log "apt-get present but no passwordless sudo/root; skipping prereqs"
  fi
fi

# ---- Ensure chezmoi exists ----
if ! command -v "$CHEZMOI_BIN" >/dev/null 2>&1; then
  if ! command -v curl >/dev/null 2>&1; then
    echo "[dotfiles] ERROR: curl not found and chezmoi is missing. Install curl, then re-run." >&2
    exit 1
  fi

  log "installing chezmoi (single-binary) into ~/.local/bin"
  # get.chezmoi.io install is non-interactive; keep output quiet-ish but fail hard on curl errors
  mkdir -p "$HOME/.local/bin"
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
  export PATH="$HOME/.local/bin:$PATH"
  CHEZMOI_BIN=chezmoi
fi

# ---- Apply dotfiles ----
# If this script is running from a cloned dotfiles repo (Codespaces dotfiles flow),
# apply directly from the local source directory. Do NOT use --one-shot here,
# because Codespaces already cloned the repo and we want deterministic behavior.
#
# If we are curl-running (no local repo), do a one-shot init from the repo.

if [[ -f "$SCRIPT_DIR/dot_zshrc" || -f "$SCRIPT_DIR/.chezmoiexternal.toml" || -d "$SCRIPT_DIR/dot_config" ]]; then
  log "repo detected locally at: $SCRIPT_DIR"
  log "applying via chezmoi from local source dir"
  "$CHEZMOI_BIN" apply --source "$SCRIPT_DIR"
else
  log "no local repo detected (likely curl-run); applying from repo: $DOTFILES_REPO"
  log "applying via chezmoi one-shot (remote repo)"
  "$CHEZMOI_BIN" init --one-shot --apply "$DOTFILES_REPO"
fi

log "done"
log "When VS Code is fully ready, run: finish-install"