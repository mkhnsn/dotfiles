# dotfiles

A sensible default set of dotfiles for full stack development with a preference towards macOS and zsh style CLIs.

## Features

- **Zsh Configuration** (`.zshrc`) - Comprehensive shell setup with:
  - Smart command history management
  - Git-aware prompt with branch information
  - Useful aliases for git, docker, node, python, and more
  - Path configuration for common development tools
  - Custom functions for productivity
  
- **Git Configuration** (`.gitconfig`) - Optimized git setup with:
  - Colorized output
  - Useful aliases and shortcuts
  - Better diff and merge tools
  - Automatic branch setup
  
- **Global Gitignore** (`.gitignore_global`) - Comprehensive ignore patterns for:
  - Operating system files (macOS, Windows, Linux)
  - IDE and editor files
  - Language-specific build artifacts
  - Common development artifacts
  
- **Vim Configuration** (`.vimrc`) - Modern vim setup with:
  - Syntax highlighting and line numbers
  - Smart indentation
  - File-type specific settings
  - Useful key mappings
  
- **EditorConfig** (`.editorconfig`) - Consistent coding styles across editors
  
- **NPM Configuration** (`.npmrc`) - Better npm defaults
  
- **Curl Configuration** (`.curlrc`) - Improved curl behavior
  
- **Brewfile** - Comprehensive package list for macOS including:
  - Core Unix utilities
  - Development tools and languages
  - Version managers
  - Databases and cloud tools
  - GUI applications

## Installation

### Quick Install

```bash
git clone https://github.com/mkhnsn/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

The install script will:
- Create symlinks from your home directory to the dotfiles
- Back up any existing dotfiles
- Provide next steps for customization

### Manual Installation

If you prefer to install specific files manually:

```bash
ln -s ~/.dotfiles/.zshrc ~/.zshrc
ln -s ~/.dotfiles/.gitconfig ~/.gitconfig
ln -s ~/.dotfiles/.gitignore_global ~/.gitignore_global
ln -s ~/.dotfiles/.vimrc ~/.vimrc
ln -s ~/.dotfiles/.editorconfig ~/.editorconfig
ln -s ~/.dotfiles/.npmrc ~/.npmrc
ln -s ~/.dotfiles/.curlrc ~/.curlrc
```

## Post-Installation Setup

### 1. Customize Git Configuration

Edit `~/.gitconfig` to set your personal information:

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### 2. Install Homebrew Packages (macOS)

If you're on macOS, install the packages defined in the Brewfile:

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install packages from Brewfile
brew bundle --file=~/.dotfiles/Brewfile
```

### 3. Reload Shell Configuration

```bash
source ~/.zshrc
```

### 4. Install Version Managers

#### NVM (Node Version Manager)

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
nvm install --lts
```

#### Pyenv (Python Version Manager)

```bash
pyenv install 3.11.0
pyenv global 3.11.0
```

#### Rbenv (Ruby Version Manager)

```bash
rbenv install 3.2.0
rbenv global 3.2.0
```

## Configuration Files

| File | Description |
|------|-------------|
| `.zshrc` | Zsh shell configuration with aliases, functions, and prompt |
| `.gitconfig` | Git configuration with aliases and settings |
| `.gitignore_global` | Global gitignore patterns |
| `.vimrc` | Vim editor configuration |
| `.editorconfig` | Cross-editor configuration for consistent coding styles |
| `.npmrc` | NPM configuration |
| `.curlrc` | Curl configuration |
| `Brewfile` | Homebrew package definitions for macOS |
| `install.sh` | Installation script |

## Useful Aliases

### Git Aliases

```bash
gs          # git status -s
ga          # git add
gc          # git commit -v
gco         # git checkout
gb          # git branch
gp          # git push
gl          # git log --oneline --decorate --graph
gd          # git diff
```

### Docker Aliases

```bash
d           # docker
dc          # docker-compose
dps         # docker ps
di          # docker images
dex         # docker exec -it
```

### Node.js Aliases

```bash
ni          # npm install
nr          # npm run
ns          # npm start
nt          # npm test
```

### Navigation Aliases

```bash
..          # cd ..
...         # cd ../..
ll          # ls -lh
la          # ls -lAh
```

## Useful Functions

```bash
mkcd <dir>              # Create directory and cd into it
extract <file>          # Extract any archive format
backup <file>           # Create timestamped backup of file
ff <name>               # Find file by name
fd <name>               # Find directory by name
serve [port]            # Start HTTP server (default port 8000)
```

## Customization

You can create local configuration files that won't be tracked by git:

- `~/.zshrc.local` - Local zsh configuration
- `~/.gitconfig.local` - Local git configuration
- `~/.vimrc.local` - Local vim configuration

These files will be automatically loaded if they exist.

## Structure

```
dotfiles/
├── .zshrc              # Zsh configuration
├── .gitconfig          # Git configuration
├── .gitignore_global   # Global gitignore
├── .vimrc              # Vim configuration
├── .editorconfig       # Editor configuration
├── .npmrc              # NPM configuration
├── .curlrc             # Curl configuration
├── Brewfile            # Homebrew packages
├── install.sh          # Installation script
└── README.md           # This file
```

## Requirements

- macOS (recommended) or Linux
- Zsh shell
- Git
- Homebrew (for macOS package management)

## Updating

To update your dotfiles:

```bash
cd ~/.dotfiles
git pull
source ~/.zshrc
```

## Contributing

Feel free to customize these dotfiles for your own use. If you have suggestions or improvements, please open an issue or pull request.

## License

MIT License - feel free to use and modify as needed.