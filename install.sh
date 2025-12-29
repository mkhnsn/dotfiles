#!/bin/bash

# install.sh - Installation script for dotfiles
# This script creates symlinks from the home directory to dotfiles in this repo

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where this script is located
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Dotfiles Installation${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}Installing from: ${DOTFILES_DIR}${NC}"
echo ""

# Function to create symlink
create_symlink() {
    local source=$1
    local target=$2
    
    if [ -e "$target" ] || [ -L "$target" ]; then
        if [ -L "$target" ]; then
            echo -e "${YELLOW}Removing existing symlink: ${target}${NC}"
            rm "$target"
        else
            echo -e "${YELLOW}Backing up existing file: ${target}${NC}"
            mv "$target" "${target}.backup.$(date +%Y%m%d-%H%M%S)"
        fi
    fi
    
    echo -e "${GREEN}Creating symlink: ${target} -> ${source}${NC}"
    ln -s "$source" "$target"
}

# Dotfiles to symlink (add more as needed)
files=(
    ".zshrc"
    ".gitconfig"
    ".gitignore_global"
    ".vimrc"
    ".editorconfig"
    ".npmrc"
    ".curlrc"
)

# Create symlinks for dotfiles
echo -e "${BLUE}Creating symlinks...${NC}"
for file in "${files[@]}"; do
    if [ -f "$DOTFILES_DIR/$file" ]; then
        create_symlink "$DOTFILES_DIR/$file" "$HOME/$file"
    else
        echo -e "${RED}Warning: $file not found in $DOTFILES_DIR${NC}"
    fi
done

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Installation complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Post-installation instructions
echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "1. Review and customize your dotfiles:"
echo -e "   ${GREEN}• ~/.gitconfig${NC} - Set your name and email"
echo -e "   ${GREEN}• ~/.zshrc${NC} - Customize your shell settings"
echo ""
echo "2. Install Homebrew packages (macOS only):"
echo -e "   ${GREEN}brew bundle --file=$DOTFILES_DIR/Brewfile${NC}"
echo ""
echo "3. Reload your shell configuration:"
echo -e "   ${GREEN}source ~/.zshrc${NC}"
echo ""
echo "4. (Optional) Install additional tools:"
echo -e "   ${GREEN}• nvm: https://github.com/nvm-sh/nvm${NC}"
echo -e "   ${GREEN}• pyenv: https://github.com/pyenv/pyenv${NC}"
echo -e "   ${GREEN}• rbenv: https://github.com/rbenv/rbenv${NC}"
echo ""
echo -e "${BLUE}========================================${NC}"
