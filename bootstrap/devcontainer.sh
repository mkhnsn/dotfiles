#!/usr/bin/env bash
set -euo pipefail
# Bootstrap script for macOS + Linux (devcontainers/Codespaces included).
# Safe to re-run. Installs minimal tools, installs chezmoi if needed,
# then applies this dotfiles repo.
#
# Run:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/mkhnsn/dotfiles/main/bootstrap/devcontainer.sh)"
#
# Notes:
# - macOS requires Homebrew to already be installed (we do NOT auto-install brew).
# - Linux path is optimized for Debian/Ubuntu (apt-get).
# - Other distros will skip package installs but still apply dotfiles.

DOTFILES_REPO="mkhnsn/dotfiles.git"
CHEZMOI_DIR="$HOME/.local/share/chezmoi"

OS="$(uname -s)"

bootstrap_macos() {
  echo "Bootstrapping macOS…"

  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew not found."
    echo "Install it first: https://brew.sh/"
    exit 1
  fi

  if ! command -v chezmoi >/dev/null 2>&1; then
    brew install chezmoi
  fi

  if [[ ! -d "$CHEZMOI_DIR" ]]; then
    chezmoi init --apply "$DOTFILES_REPO"
  else
    chezmoi apply
  fi

  echo "Bootstrap complete (macOS)."
}

bootstrap_linux() {
  echo "Bootstrapping Linux…"

  # Base packages (Debian / Ubuntu)
  if command -v apt-get >/dev/null 2>&1; then
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
  else
    echo "apt-get not found; skipping system package install."
  fi

  # GitHub CLI
  if ! command -v gh >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1; then
    sudo mkdir -p /usr/share/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
      https://cli.github.com/packages stable main" \
      | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt-get update
    sudo apt-get install -y gh
  fi

  # starship prompt
  if ! command -v starship >/dev/null 2>&1; then
    curl -fsSL https://starship.rs/install.sh | sh -s -- -y || true
  fi

  # chezmoi (single-binary)
  if ! command -v chezmoi >/dev/null 2>&1; then
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin
  fi

  # Apply dotfiles
  if [[ ! -d "$CHEZMOI_DIR" ]]; then
    chezmoi init --apply "$DOTFILES_REPO"
  else
    chezmoi apply
  fi

  # Default shell → zsh (non-fatal if blocked)
  if command -v chsh >/dev/null 2>&1 && command -v zsh >/dev/null 2>&1; then
    chsh -s "$(command -v zsh)" "$USER" || true
  fi

  echo "Bootstrap complete (Linux)."
}

case "$OS" in
  Darwin)
    bootstrap_macos
    ;;
  Linux)
    bootstrap_linux
    ;;
  *)
    echo "Unsupported OS: $OS"
    echo "Install chezmoi manually, then run:"
    echo "  chezmoi init --apply $DOTFILES_REPO"
    exit 1
    ;;
esac