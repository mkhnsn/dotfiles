# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a **chezmoi-managed dotfiles repository** for cross-platform configuration (macOS, Linux, GitHub Codespaces). It provides portable shell, Git, VS Code, and 1Password integration.

## Commands

```bash
# Apply dotfiles to $HOME
chezmoi apply

# Force-refresh external dependencies (plugins, git repos)
chezmoi apply -R

# Generate bootstrap scripts for external bootstrap repo
make bootstrap-scripts

# Run diagnostics (check binaries, paths, completions, git config)
bash doctor.sh
```

## Chezmoi Conventions

- `dot_*` files become `~/.` hidden files (e.g., `dot_zshrc` → `~/.zshrc`)
- `.tmpl` suffix indicates template files with variable substitution
- `run_onchange_*` scripts execute when their source content changes
- `.chezmoiignore.tmpl` controls OS-specific file exclusions
- `.chezmoiexternal.toml` manages external git dependencies
- `private_*` files are gitignored and typically contain 1Password-backed secrets

## Architecture

### Configuration Flow
```
.chezmoitemplates/          # Canonical template sources (single source of truth)
       ↓
dot_*/                      # Chezmoi-managed files with OS conditionals
       ↓
chezmoi apply              # Renders templates to $HOME
```

### VS Code Configuration
VS Code templates live in `.chezmoitemplates/vscode/` as the single source of truth. OS-specific wrappers in `dot_config/Code/User/` (Linux) and `Library/Application Support/Code/User/` (macOS) include these templates.

### Shell Configuration
- `dot_zshrc` sources `~/.config/shell/` modules
- `dot_config/shell/env.zsh` handles PATH, fzf, completions, pnpm
- `dot_config/shell/aliases.zsh` contains shell aliases
- External zsh plugins managed via `.chezmoiexternal.toml`

### Bootstrap Scripts
- `install.sh` - Entry point for Codespaces and curl-based installs
- `scripts/` - Templates for external bootstrap repository generation
- `Makefile` - Generates bootstrap scripts from templates

## Template Variables

Chezmoi templates use Go template syntax with these key variables:
- `.chezmoi.os` - Operating system ("darwin", "linux")
- `.codespaces` - Boolean for GitHub Codespaces environment
- Secrets accessed via `{{ secret ... }}` with 1Password

## External Dependencies

Defined in `.chezmoiexternal.toml`:
- fzf-tab and fzf-tab-source plugins (zsh completion)
