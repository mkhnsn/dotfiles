#!/usr/bin/env bash
set -euo pipefail

# This script is meant for Linux devcontainers/Codespaces.
# It installs basics, installs chezmoi, applies your dotfiles.

sudo apt-get update
sudo apt-get install -y \
  git \
  curl \
  zsh \
  ca-certificates \
  ripgrep \
  fzf \
  bat \
  zoxide

# GitHub CLI (gh)
if ! command -v gh >/dev/null 2>&1; then
  type -p curl >/dev/null || sudo apt-get install -y curl
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  sudo apt-get update
  sudo apt-get install -y gh
fi

# starship (simple install)
if ! command -v starship >/dev/null 2>&1; then
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y
fi

# chezmoi (single-binary install)
if ! command -v chezmoi >/dev/null 2>&1; then
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin
fi

# Apply dotfiles
chezmoi init --apply mkhnsn/dotfiles.git || chezmoi apply

# Make zsh the default shell (may be blocked in some containers; harmless if it fails)
chsh -s "$(command -v zsh)" "$USER" || true