#!/usr/bin/env bash
set -euo pipefail

# GitHub Codespaces dotfiles entrypoint (also safe to run anywhere).
#
# Design goals:
# - Works when GitHub has cloned this repo (Codespaces dotfiles feature).
# - Works when executed via curl from raw GitHub (no local repo present).
# - Idempotent and non-invasive: only ensures chezmoi exists and applies.
# - Keeps personal-machine setup out of here; chezmoi's run_ scripts do that.

DOTFILES_REPO_DEFAULT="mkhnsn/dotfiles"
DOTFILES_REPO="${DOTFILES_REPO:-$DOTFILES_REPO_DEFAULT}"
CHEZMOI_BIN="${CHEZMOI_BIN:-chezmoi}"

# Directory of this script (only meaningful when the repo is already cloned locally).
# BASH_SOURCE is unset when run via bash -c "$(curl ...)", so fall back gracefully.
SCRIPT_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

log() { printf '[dotfiles] %s\n' "$*"; }

# ---- Run as the user whose home gets the dotfiles ----
if [[ -z "${HOME:-}" ]]; then
  echo "[dotfiles] ERROR: HOME isn't set. Run this from a login shell as your own user." >&2
  exit 1
fi
if [[ "$(uname -s)" == "Darwin" && "${EUID:-$(id -u)}" -eq 0 ]]; then
  echo "[dotfiles] ERROR: running as root. Run this as your own user (Homebrew refuses root)." >&2
  exit 1
fi

# ---- macOS prereqs: Homebrew, which also installs the Command Line Tools (git) ----
if [[ "$(uname -s)" == "Darwin" ]]; then
  for brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [[ -x "$brew" ]] && eval "$("$brew" shellenv)" && break
  done
  if ! command -v brew >/dev/null 2>&1; then
    log "installing Homebrew (and the Command Line Tools); it asks for your password"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
fi

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
# apply directly from the local source directory.
#
# If we are curl-running (no local repo), do a one-shot init from the repo.

if [[ -n "$SCRIPT_DIR" ]] && [[ -f "$SCRIPT_DIR/dot_zshrc" || -f "$SCRIPT_DIR/.chezmoiexternal.toml" || -d "$SCRIPT_DIR/dot_config" ]]; then
  log "repo detected locally at: $SCRIPT_DIR"
  log "applying via chezmoi from local source dir"
  "$CHEZMOI_BIN" apply --source "$SCRIPT_DIR"
elif [[ "${DOTFILES_ONESHOT:-0}" == "1" ]]; then
  # Ephemeral: init, apply, then purge the source/config. For throwaway shells.
  log "no local repo detected; one-shot apply from repo: $DOTFILES_REPO"
  "$CHEZMOI_BIN" init --one-shot --apply "$DOTFILES_REPO"
else
  # Persistent install: clone the repo to chezmoi's source dir
  # (~/.local/share/chezmoi) and keep the config, so `chezmoi apply`,
  # `chezmoi edit`, and `chezmoi update` work afterward.
  log "no local repo detected; installing + applying from repo: $DOTFILES_REPO"
  "$CHEZMOI_BIN" init --apply "$DOTFILES_REPO"
  log "source dir: $("$CHEZMOI_BIN" source-path 2>/dev/null || echo "$HOME/.local/share/chezmoi")"
fi

log "done"
if [[ "$(uname -s)" == "Darwin" ]]; then
  log "next: run 'mac-setup' to check the rest of this Mac's setup step by step"
fi
