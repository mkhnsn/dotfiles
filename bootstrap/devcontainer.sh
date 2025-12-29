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
# Codespaces usually has this already; install only if missing.
if ! command -v gh >/dev/null 2>&1; then
  sudo mkdir -p /usr/share/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  sudo chmod go+r /usric/share/keyrings/githubcli-archive-keyring.gpg
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

# Optional: if op + service token exist, templates using op:// can work
if command -v op >/dev/null 2>&1 && [[ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
  echo "1Password service token detected; chezmoi can read op:// secrets."
fi

# Apply dotfiles (init only once; apply thereafter)
if [[ ! -d "$HOME/.local/share/chezmoi" ]]; then
  chezmoi init --apply mkhnsn/dotfiles.git
else
  chezmoi apply
fi

# Make zsh the default shell (often blocked in containers; never fail)
chsh -s "$(command -v zsh)" "$USER" >/dev/null 2>&1 || true