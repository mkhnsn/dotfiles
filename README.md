# Dotfiles Managed with chezmoi

## Description and Goals

This repository contains my personal dotfiles managed with [chezmoi](https://chezmoi.io/). The goal is to maintain a clean, portable, and reproducible configuration environment across multiple machines and operating systems, enabling quick setup and consistent behavior.

---

## Prerequisite: Install chezmoi

Before initializing your dotfiles on a new machine, you must install chezmoi.

### macOS (using Homebrew)

```zsh
brew install chezmoi
```

### Linux (using the official install script)

```sh
sh -c "$(curl -fsLS get.chezmoi.io)"
```

---

## First-time Install

Once chezmoi is installed, initialize and apply your dotfiles with:

```zsh
chezmoi init --apply git@github.com:mkhnsn/dotfiles.git
```

This clones the repository and applies the configuration to your home directory.

---

## Update / Refresh Externals (Plugins)

To update external components such as plugins managed by chezmoi:

```zsh
chezmoi apply -R
```

This forces a refresh of all external dependencies.

---

## Repository Structure (High-Level)

- `dot_` files and directories: canonical configuration templates that chezmoi manages.
- `dot_vscode/`: VS Code configuration templates.
- OS-specific wrappers: separate files or directories that apply OS-dependent overrides or additions.
- `private_` files: sensitive data encrypted and managed securely by chezmoi.

This structure allows clear separation between generic and platform-specific configurations.

---

## VS Code Configuration Model

VS Code settings are managed using canonical templates under `dot_vscode/`. OS-specific customizations are handled via wrapper files or directories that overlay the base configuration. This approach keeps the main configuration consistent while allowing machine or OS-specific tweaks.

---

## Zsh & Completions Notes

Zsh completions occasionally become stale or corrupted. To recover:

```zsh
rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"* 2>/dev/null || true
exec zsh
```

This clears the completion dump cache and restarts the shell to regenerate completions.

---

## Git & SSH Signing Notes

Git and SSH keys are configured to use signing for commits and authentication where applicable. Ensure your GPG and SSH agents are running and correctly configured to enable seamless signing.

---

## 1Password Usage Notes

Some secrets and credentials are managed via 1Password and integrated into the dotfiles workflow. Make sure 1Password CLI is installed and authenticated to allow secure retrieval of sensitive data during setup.

---

## Devcontainer / Codespaces Notes

Development containers and GitHub Codespaces are configured to use the dotfiles repository to bootstrap environments automatically, ensuring consistent tooling and settings inside containerized or cloud-based development setups.

---

For any questions or issues, consult the chezmoi documentation or open an issue in this repository.
