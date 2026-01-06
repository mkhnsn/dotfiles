# Dotfiles Managed with chezmoi

This repository contains my personal dotfiles managed with [chezmoi](https://www.chezmoi.io).  
The goal is a clean, portable, reproducible setup across macOS, Linux, Windows, and GitHub Codespaces.

The repository is designed to support **four installation modes**:

- GitHub Codespaces (automatic)
- Personal machines (full setup) - macOS, Linux, Windows
- Temporary or shared machines (lite setup)

---

## Quick Start

### 1. GitHub Codespaces (automatic)

If this repository is selected as your dotfiles repository in **GitHub Codespaces settings** and  
**“Automatically install dotfiles”** is enabled, setup runs automatically.

No manual steps are required.

This relies on GitHub’s official dotfiles mechanism and does not require `install.sh` to be invoked manually.

---

### 2. Personal machine (full setup)

#### macOS / Linux


Use this on a personal macOS or Linux machine where you want the full environment:
shell configuration, tools, 1Password integration, SSH agent wiring, and VS Code setup.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/mkhnsn/dotfiles/main/install.sh)"
```

Notes:

- macOS requires Homebrew to already be installed
- You’ll be prompted to sign into 1Password (once)
- This is the recommended path for long‑lived personal machines

#### Windows

Use this on Windows machines where you want Git Bash with zsh, VS Code, and development tools.

**PowerShell (as regular user):**
```powershell
iwr -useb https://raw.githubusercontent.com/mkhnsn/dotfiles/main/install.ps1 | iex
```

Or download and run:
```powershell
Invoke-WebRequest -Uri https://raw.githubusercontent.com/mkhnsn/dotfiles/main/install.ps1 -OutFile install.ps1
.\install.ps1
```

This will:
- Install winget (if needed)
- Install Git for Windows (includes Git Bash)
- Install chezmoi
- Apply dotfiles configuration
- Set up Git Bash to auto-launch zsh

After installation, open **Git Bash** from your Start Menu and it will automatically launch zsh with your dotfiles configuration.

---

### 3. Temporary or shared machine (lite setup)

Use this on machines you don’t own long‑term (servers, borrowed laptops, CI runners).

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply mkhnsn/dotfiles.git
```

This installs chezmoi and applies dotfiles without interactive secret setup.

---

## Updating

Once installed, update configuration at any time with:

```bash
chezmoi apply
```

To force-refresh external dependencies (plugins, git repos):

```bash
chezmoi apply -R
```

---

## Repository Structure (High-Level)

- `dot_*/` — canonical configuration templates managed by chezmoi
- `.chezmoiexternal.toml` — external git‑based dependencies (zsh plugins, etc.)
- `install.sh` — full bootstrap for personal machines (macOS/Linux)
- `install.ps1` — full bootstrap for Windows machines
- `manifests/windows/` — winget package manifests for Windows
- `bootstrap/` — helper scripts for containers or special environments
- `private_*.tmpl` — secret-backed or machine-specific templates

This structure keeps base configuration portable while allowing platform-specific behavior.

---

## VS Code Configuration

VS Code configuration is generated from canonical templates and applied to the correct OS-specific paths.

- Base templates live under `.chezmoitemplates/vscode/`
- macOS and Linux wrappers map these templates to the appropriate VS Code directories

This allows a single source of truth while remaining OS‑correct.

---

## Zsh & Completion Recovery

If zsh completions become stale or corrupted:

```bash
rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"* 2>/dev/null || true
exec zsh
```

This clears the completion cache and forces regeneration.

---

## Git, SSH, and Signing

- SSH authentication uses the 1Password SSH agent on supported platforms
- Git commit signing is configured using SSH keys
- Allowed signers are managed explicitly to avoid key overload

No private keys are stored in this repository.

---

## 1Password Integration

1Password is used for:

- Secure secret retrieval via `op://` references
- SSH agent integration on interactive machines

For non‑interactive environments (e.g. CI or Codespaces), secrets are optional and not required for a successful apply.

---

## Devcontainers & Codespaces

Devcontainers and GitHub Codespaces rely on:

- GitHub’s native dotfiles integration
- Automatic invocation of supported bootstrap files (`install.sh`, `bootstrap.sh`, etc.)

No duplicate initialization logic is required.

---

For detailed behavior, consult the chezmoi documentation or inspect `install.sh`.
