# Dotfiles Managed with chezmoi

This repository contains my personal dotfiles managed with [chezmoi](https://www.chezmoi.io).  
The goal is a clean, portable, reproducible setup across macOS, Linux, and GitHub Codespaces.

The repository is designed to support **three installation modes**:

- GitHub Codespaces (automatic)
- Personal machines (full setup)
- Temporary or shared machines (lite setup)

---

## Quick Start

### 1. GitHub Codespaces (automatic)

If this repository is selected as your dotfiles repository in **GitHub Codespaces settings** and  
**“Automatically install dotfiles”** is enabled, setup runs automatically.

No manual steps are required.

This relies on GitHub’s official dotfiles mechanism and does not require `install.sh` to be invoked manually.

---

### 2. Personal machine (full setup) — recommended

Use this on any personal macOS or Linux machine. This is the **recommended** way to install,
even for quick setups, because it puts chezmoi in `~/.local/bin` (which is on PATH) and
handles all dependencies automatically.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/mkhnsn/dotfiles/main/install.sh)"
```

Notes:

- Run it as your own user in Terminal, not as root or from an RMM shell (Ninja's terminal runs as root)
- macOS: installs Homebrew first if it's missing, which also installs the Command Line Tools (git); it asks for your password
- Full setup: before any template is rendered, `.install-password-manager.sh` (a chezmoi
  `read-source-state.pre` hook) installs 1Password and its CLI on macOS and waits while you
  sign in and turn on Settings > Developer > Integrate with 1Password CLI
- Works on Linux too — installs chezmoi and applies dotfiles in one step

---

### 3. Temporary or shared machine (lite setup)

Use this on machines you don't own long-term (servers, borrowed laptops, CI runners).

> **Important:** The default chezmoi installer puts the binary in `~/bin`, which is
> not on PATH in this setup. Always use `-b ~/.local/bin` to match the managed PATH.

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply mkhnsn/dotfiles
```

This installs chezmoi to `~/.local/bin` and applies dotfiles without interactive secret setup.
For the full experience (Homebrew packages, 1Password, etc.), use option 2 instead.

---

### 4. WSL / headless full setup (1Password service account)

On Windows/WSL and headless servers there is no Linux 1Password desktop app, so the
CLI can't use desktop-app integration. Use a **1Password service-account token** instead.

**One-time provisioning (in 1Password):**

1. Create a custom vault named `Automation` and move the ntfy Pushover item into it
   (the built-in `Private` vault can't be shared with service accounts).
2. Create a service account with read access to `Automation`; copy its token.

**Install:**

```bash
export OP_SERVICE_ACCOUNT_TOKEN=ops_...
bash -c "$(curl -fsSL https://raw.githubusercontent.com/mkhnsn/dotfiles/main/install.sh)"
```

This is a **persistent install**: `install.sh` clones the repo to chezmoi's source dir
(`~/.local/share/chezmoi`) and keeps the config, so `chezmoi apply` / `chezmoi edit` /
`chezmoi update` work afterward. (Set `DOTFILES_ONESHOT=1` before the curl for a throwaway
init-apply-purge instead.)

`chezmoi init` sees the token and records `op_mode = "service"`; the token is persisted to
`~/.config/op/service-account.env` (0600) and sourced by `env.zsh`, so later `chezmoi apply`
runs and fresh shells stay authenticated without re-exporting it. `env.zsh` also adds both
`~/.local/bin` and `~/bin` to PATH, so `chezmoi` is found regardless of where the installer
placed it.

**Switching an already-installed machine to service mode:** `op_mode` is decided at
`chezmoi init` time, and an exported token is authoritative. So if a box was first applied
without the token (and is stuck in `account` mode), just export the token and re-init:

```bash
export OP_SERVICE_ACCOUNT_TOKEN=ops_...     # or: source ~/.config/op/service-account.env
chezmoi init                                # regenerates config -> op_mode = "service"
chezmoi apply
chezmoi data | grep op_mode                 # confirm -> "service"
```

**Rotating the token:** the `op` CLI can only `create` service accounts, not rotate or
delete them — do that in the 1Password admin console (Developer Tools → Service Accounts →
rotate the token, which keeps the same vault grants). Then update the two places the token
lives: the 1Password item where you stashed it, and each machine's persisted file:

```bash
( umask 077; printf 'export OP_SERVICE_ACCOUNT_TOKEN=%q\n' 'ops_NEW...' > ~/.config/op/service-account.env )
chmod 600 ~/.config/op/service-account.env
exec zsh && op whoami   # reload + confirm the new token works
```

`run_once_05` never clobbers an existing `service-account.env`, so editing it directly is
the rotation path — re-running the installer will not update it. No repo change is needed;
the token never lives in chezmoi.

#### Windows Terminal theming (from WSL)

`run_windows-terminal.sh.tmpl` mirrors the Ghostty look (JetBrains Mono + the `Darkside`
scheme, slight transparency) into Windows Terminal. chezmoi runs inside WSL but Windows
Terminal owns its `settings.json` on the Windows side, so the script **surgically merges**
font / color scheme / opacity / default-profile into the existing file (under
`/mnt/c/Users/<you>/AppData/Local/Packages/Microsoft.WindowsTerminal_*/LocalState/`) rather
than overwriting it — everything the app manages (profiles, GUIDs) is preserved, and a
one-time `settings.json.chezmoi.bak` backup is written.

Two notes:

- **Launch Windows Terminal once first** so `settings.json` and the WSL profile exist; the
  script runs on every `chezmoi apply` and is a no-op until then (and idempotent after).
- **Install the JetBrains Mono Nerd Font on Windows** for starship/eza glyphs (Ghostty has a
  built-in Nerd Font fallback; Windows Terminal does not). With `scoop` (run from Windows
  PowerShell, not WSL):
  `scoop bucket add nerd-fonts && scoop install JetBrainsMono-NF-Mono`. Note the package is
  `JetBrainsMono-NF-Mono` (patched, registers as `JetBrainsMono Nerd Font Mono`) — **not**
  the plain `JetBrains-Mono`, which ships no glyphs despite living in the same bucket. The
  `-Mono` variant keeps icons single-cell-width, best for terminals. `FONT_FACE` in
  `run_windows-terminal.sh.tmpl` must match the family name shown in the WT font dropdown.

#### OpenShift client dev toolchain (`dev_openshift`)

Opt-in toolchain for the OpenShift client engagement. Enable it at init by answering yes to
the "OpenShift dev toolchain?" prompt, seeding `DOTFILES_OPENSHIFT=1` in the env, or setting
`dev_openshift = true` in the chezmoi config. It's off by default, so personal machines are
unaffected.

When on, `run_dev-openshift.sh.tmpl` (every apply, idempotent) installs **inside WSL/Linux**:

- **Node.js 22 LTS** via [`fnm`](https://github.com/Schniz/fnm) (installed to `~/.local/bin`;
  `env.zsh` wires up `fnm env --use-on-cd`).
- **Python 3** with `venv`/`pip` (`python3-full` on apt).
- **Ansible**, isolated via `uv tool install ansible` (falls back to a `~/.venvs/ansible` venv).

And on WSL it **symlinks the Windows binaries** into `~/.local/bin` — `podman`, `helm`, `oc` →
the `.exe` on the Windows PATH (these are the FIPS-approved Windows builds; chezmoi shims, it
does not install them). Git stays WSL-native on purpose. If a `.exe` isn't found, apply still
succeeds and prints a hint.

> Path-translation caveat: the shimmed `podman`/`helm`/`oc` are Windows binaries, so paths you
> pass them are Windows paths — use `wslpath -w` when handing them a WSL path.

The Windows side is a separate, explicit step — run **`scripts/windows-client.ps1`** once from
**Windows PowerShell** (the repo is reachable at `\\wsl$\<distro>\home\<you>\.local\share\chezmoi\`).
It installs Podman, Podman Desktop, Helm, Git for Windows (winget) and `oc` (public mirror).
**CRC and its FIPS bundle** need a Red Hat pull secret and are printed as manual steps.

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
- `install.sh` — full bootstrap for personal machines
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

### Reclaiming disk space across clones

`git-sweep` (installed to `~/.local/bin`, also runs as `git sweep`) scans every repo under
your ghq root and reports size, reclaimable build output, and any work that exists only
locally. It changes nothing unless you pass `--apply`:

```bash
git-sweep                                             # dry run with summary
git-sweep --apply --artifacts --branches --only-safe  # clean, skipping repos with local-only work
git-sweep --apply --gone                              # also drop branches whose PR merged
```

For the current repo only, `empty-yard-debris` fetches, lists local branches whose remote
branch was deleted, and removes the ones that are merged or squash-merged (asks first;
`-n` dry run, `-y` no prompt, `-f` also delete unmerged ones). Run either with `--help`.

---

## New Mac checklist

`mac-setup` walks a Mac through the whole setup and checks each step: MDM enrollment,
FileVault, profiles and the Ninja agent, the escrowed secrets in 1Password, Command Line
Tools, Homebrew, the 1Password CLI, dotfiles and Brewfile, `gh` and Doppler sign-in,
Tailscale (name and tag), BetterTouchTool and its preset, and Ninja Remote's Screen
Recording approval. It ticks what's done, says what to do next, offers to do it when it
can, and re-checks before moving on. Re-run it any time; `mac-setup --status` only checks.
Steps that can only be confirmed by hand are remembered in `~/.local/state/mac-setup`.

Tests: `make test` renders it, runs shellcheck and `tests/mac-setup.test.sh` (stub commands, no
dependencies), also under bash 3.2 in Docker. CI runs the same on every PR.

The Tailscale tag it expects is `tag:echo-core` on servers (`is_server`) and
`tag:echo-admin` otherwise. The full runbook is in `unstable-studios/echo-core`
(`docs/devices/README.md`).

## BetterTouchTool

BTT is installed from [folivora.ai](https://folivora.ai), not Homebrew (BTT warns about
Homebrew installs: `brew upgrade` replaces the app under its own updater). Its Default preset,
with general settings, lives in `macos/btt/Default.bttpreset` and isn't deployed by chezmoi:

- `btt-sync import` on a new Mac, after installing BTT
- `btt-sync export` after changing triggers, then review and commit the diff

This repo is public: keep secrets out of BTT triggers.

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
