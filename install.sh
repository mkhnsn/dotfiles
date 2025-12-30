#!/usr/bin/env bash
set -euo pipefail

# GitHub Codespaces dotfiles entrypoint (also safe to run anywhere).
# - Assumes this script lives inside the dotfiles repo (GitHub already cloned it for Codespaces)
# - Uses chezmoi "one-shot" so we don't create/manage a working copy in the environment
# - Idempotent: safe to run repeatedly

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHEZMOI_BIN="${CHEZMOI_BIN:-chezmoi}"

echo "[dotfiles] repo: $REPO_DIR"

# Ensure basic deps for the chezmoi installer (and useful baseline tools).
if command -v apt-get >/dev/null 2>&1; then
  if command -v sudo >/dev/null 2>&1; then
    sudo apt-get update -y
    sudo apt-get install -y git curl ca-certificates
  else
    apt-get update -y
    apt-get install -y git curl ca-certificates
  fi
fi

# Install chezmoi if missing (single-binary).
if ! command -v "$CHEZMOI_BIN" >/dev/null 2>&1; then
  echo "[dotfiles] installing chezmoi..."
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
  export PATH="$HOME/.local/bin:$PATH"
  CHEZMOI_BIN=chezmoi
fi

echo "[dotfiles] applying via chezmoi one-shot..."
"$CHEZMOI_BIN" init --one-shot --apply "$REPO_DIR"

echo "[dotfiles] done."