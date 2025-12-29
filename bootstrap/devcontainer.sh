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

# 1Password CLI (op) - for service-account auth in Codespaces/devcontainers
if ! command -v op >/dev/null 2>&1; then
  sudo apt-get install -y gnupg
  sudo mkdir -p /usr/share/keyrings

  CODENAME="$(
    . /etc/os-release
    echo "${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
  )"

  if [[ -z "$CODENAME" ]]; then
    echo "Could not determine distro codename; skipping 1Password CLI install."
  else
    curl -fsSL https://downloads.1password.com/linux/keys/1password.asc \
      | sudo gpg --dearmor -o /usr/share/keyrings/1password-archive-keyring.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$CODENAME stable main" \
      | sudo tee /etc/apt/sources.list.d/1password.list >/dev/null

    sudo apt-get update
    sudo apt-get install -y 1password-cli
  fi
fi

# GitHub CLI (gh)
if ! command -v gh >/dev/null 2>&1; then
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

if [[ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
  echo "WARNING: OP_SERVICE_ACCOUNT_TOKEN is not set. Chezmoi 1Password reads will fail."
fi

# Apply dotfiles (init only once; apply thereafter)
if [[ ! -d "$HOME/.local/share/chezmoi" ]]; then
  chezmoi init --apply mkhnsn/dotfiles.git
else
  chezmoi apply
fi

# Make zsh the default shell (may be blocked in some containers; harmless if it fails)
chsh -s "$(command -v zsh)" "$USER" || true