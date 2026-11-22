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
Files read from 1Password (`~/.ssh/authorized_keys`, `~/.ntfy.yml`) are skipped and left as they are.
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

## tmux

Config: `~/.config/tmux/tmux.conf` on every machine. A `~/.tmux.conf` would override it;
`doctor.sh` warns if one exists.

A server holds sessions, a session holds windows (the tabs in the status bar), and a window
splits into panes. One session per project works well, with windows for the editor or
Claude, a shell and logs.

ssh and mosh logins open tmux automatically. The first one attaches to `main`. If `main` is
already open on another screen, the new login gets a session of its own grouped with `main`:
the same windows, but you can look at a different one. It closes when you detach. Detaching
ends the connection. To open a separate session instead, run
`mosh <host> -- tmux new -A -s <name>`. To skip tmux, run `ssh -t <host> NO_TMUX=1 zsh -l`.

tmux-resurrect and tmux-continuum save sessions every 15 minutes and restore them after a
reboot.

The prefix is `C-a`; with tmux nested on a Mac, `C-a C-a` reaches the inner one.

| Keys | What it does |
|---|---|
| `C-a c` | New window |
| `C-a 1`…`9` / `n` / `p` | Window by number / next / previous |
| `C-a ,` | Rename window |
| `C-a \|` / `C-a -` | Split side by side / top and bottom |
| `C-a h` `j` `k` `l` | Move between panes (the mouse works too) |
| `C-a z` | Zoom a pane, and back |
| `C-a x` / `C-a &` | Close pane / close window |
| `C-a s` / `C-a w` | Pick a session / pick a window |
| `C-a $` | Rename session |
| `C-a d` | Detach |
| `C-a [` | Copy mode: `v` selects, `y` copies to the local clipboard, `q` quits |
| `C-a r` | Reload config |
| `C-a ?` | Cheat sheet, grouped (`C-a :list-keys` shows every binding) |
| `C-a H` | Hide or show the key hint row under the status bar |
| `C-a m` | Turn mouse handling off or on (try off if touch input misbehaves, e.g. on an iPad) |

---

## Git, SSH, and Signing

- SSH authentication uses the 1Password SSH agent on supported platforms
- Git commit signing uses SSH keys: 1Password locally, a per-machine fallback key in Claude
  Code and SSH sessions
- `~/.config/git/allowed_signers` is rebuilt from the GitHub account's signing keys on each apply

Which key does what, and how to retire a machine's key: [docs/keys.md](docs/keys.md).

No private keys are stored in this repository.

On Macs chezmoi also writes:

- `~/.ssh/config`: the 1Password agent and its per-host keys, short tailnet names
  (`ssh mikebook-pro`) expanded to MagicDNS, tailnet hosts' keys trusted on first use, and
  agent forwarding to tailnet hosts only. The tailnet's domain is read from Tailscale at
  apply time (it isn't in this public repo), so apply again once Tailscale is connected.
- `~/.ssh/authorized_keys`: from 1Password (Unstable Studios > Automation > "Mac SSH
  authorized keys"): the Echo-Net Admin key and Blink Shell's keys on the iPad and iPhone.

Incoming SSH needs Remote Login, which `mac-setup` turns on for your user only. Tailscale
SSH isn't used: the app build on workstations can't run its SSH server, and servers
(`tailscaled`, which could) keep Remote Login until it's been tried there.

### Finding and cloning repos

Repos are cloned with ghq under `~/src` (`gget owner/repo` clones and changes into it). `c`
fuzzy-finds a repo and changes into it: the ones you've cloned, plus every repo of yours and
your GitHub organizations' that you haven't (archived ones left out), marked `clone`. Picking
one of those clones it first. The GitHub list is cached in `~/.cache/cproj/remote` and
refreshed in the background once a day; `cproj-refresh` updates it now.

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

## echo-provision

On full-setup Macs and Linux machines, `chezmoi apply` installs `echo-provision` (guided setup for
drives and YubiKeys) into `~/.local/bin` from the latest release in the private
`unstable-studios/echo-core` repo, and updates it when a new release comes out. It needs `gh`
signed in with access to that repo, and skips quietly otherwise.

---

## New Mac checklist

`mac-setup` walks a Mac through the whole setup and checks each step: MDM enrollment,
FileVault, profiles and the Ninja agent, the escrowed secrets in 1Password, Command Line
Tools, Homebrew, the 1Password CLI, SSH agent and browser integration, the Claude Code MCP tokens (Home Assistant, Cloudflare read-only), dotfiles and Brewfile, `gh` and Doppler sign-in,
the computer name (renamed in SimpleMDM), Desktop & Documents in iCloud,
Tailscale (name and tag), Remote Login, BetterTouchTool (preset, snapping, MCP server), Raycast (Cloud
Sync, weekly exports, the settings that stay on each Mac, and the echo-m365 sign-in its Generate TAP command needs: the
`AdminAccount` from that repo's `tenant.psd1`), Zoom's video shortcut, workstation apps (Brewfile, vendor
downloads, gridfinity-studio, licenses, HueForge plugins), Ninja Remote's Screen Recording approval, Ninja Backup's deployment and a first
backup run, macOS settings and the Dock, desktop widgets, Time Machine to echo-nas (virtual machines excluded), and the default browser. It ticks what's done, says what to do next, offers to do it when it
can, and re-checks before moving on. Re-run it any time; `mac-setup --status` only checks.
For apps with no Homebrew cask it opens the download page, waits for the file in `~/Downloads`
(or uses one already there) and installs it: the `.app` from a `.zip` or `.dmg` goes to
`/Applications`, a `.pkg` runs through `installer`, and anything else opens in Finder.
Steps that can only be confirmed by hand are remembered in `~/.local/state/mac-setup`. Multi-part
steps are split per item (each app without a cask, each license, each app export, each
escrowed secret, the browser pieces), so each gets its own tick and its own "Do it now?"
(opening the download page, the app, or the exports folder).

Tests: `make test` renders it, runs shellcheck and `tests/mac-setup.test.sh` (stub commands, no
dependencies), also under bash 3.2 in Docker. CI runs the same on every PR.

Things to know on a FileVault Mac:

- Installers that restart the Mac (3Dconnexion, drivers) leave it at the FileVault unlock
  screen, offline to Ninja, Tailscale and SimpleMDM until you unlock it in person. Click
  Later in the installer and restart with `sudo fdesetup authrestart`, which unlocks once.
- Claude Code may ask for access to other apps' data after each update (it runs from a
  versioned path). Deny it: nothing in this setup needs it.

The Tailscale tag it expects is `tag:echo-core` on servers (`is_server`) and
`tag:echo-admin` otherwise. Servers run the open-source `tailscaled` set up by
echo-core's playbook (decision 0006), so `mac-setup` flags the Tailscale app there instead
of installing it, and `run_once_02-tailscale` leaves Tailscale to the playbook. The full runbook is in `unstable-studios/echo-core`
(`docs/devices/README.md`).

On servers, `gh` and Doppler mustn't carry your personal logins (an always-on Mac has no
FileVault): `mac-setup` flags a GitHub web login or classic token and any Doppler login
that isn't a service token, and offers to sign them out. Use a fine-grained GitHub token or a Doppler service
token scoped to what runs there, or none. Secrets in the dotfiles come from a 1Password
service account (full setup with `OP_SERVICE_ACCOUNT_TOKEN`).

## Workstation apps and macOS settings

- `Brewfile`: CLI tools for every Mac, including the `claude` CLI (`claude-code` cask). An entry
  that fails to install (a formula that became a cask, a moved tap) doesn't stop the apply:
  it's listed in the end-of-apply summary, and the rest of the setup carries on.
  `make test` (and CI) checks each entry exists in Homebrew as the type it's listed as
  (`tests/brewfile_check.py`), so a `brew` line for a cask fails in the repo first.
- PowerShell modules: on macOS, after the Brewfile installs `pwsh`, the install script adds the modules in
  `PWSH_MODULES` (`run_install-packages.sh.tmpl`) for the current user. Today that's
  `Microsoft.Graph.Authentication`, which the echo-m365 and mclean-iac tenant scripts need.
- `Brewfile.workstation`: GUI apps for workstation Macs (casks, plus App Store apps through
  `mas`; sign in to the App Store first). Installed after the base Brewfile unless
  `is_server`, with `--adopt` so apps already in `/Applications` are taken over. Apps
  without a cask, licenses and sign-ins are `mac-setup` steps.
- `dot_duti`: VS Code Insiders as the default app for dev files (JSON, YAML, Markdown,
  shell, Terraform, ...), applied with `duti`. Workstations only: servers (`is_server`)
  skip it.
- `mac-defaults`: applies Dock, Finder and system settings, the Dock apps in order
  and the Downloads stack (`dockutil`), and the system keyboard shortcuts in `macos/symbolichotkeys.plist`
  (screenshots, Spotlight off for Raycast, input sources, ...). Runs on apply when it
  changes, on workstations only. `--check`, `--diff`, `--dock`; after changing shortcuts in System Settings,
  `mac-defaults --export-shortcuts` and commit.
- Desktop widgets: `mac-defaults` shows them on the desktop and in Stage Manager. Which
  widgets, where they sit and their settings are kept in containers macOS protects
  (per display, with personal data like Home accessories and contacts), so `mac-setup` has a
  manual step to place them (right-click the desktop > Edit Widgets).
- `3dx-sync`: SpaceMouse settings (per-app navigation in `navlib/*.user.config`, button
  assignments in `Cfg/*.xml`) in `macos/3dconnexion/`. `3dx-sync export` after changing them
  in 3DxWare, review and commit; `mac-setup` imports them (`3dx-sync import`).
- Default browser: Chrome, set by `mac-setup` with `defaultbrowser` (macOS asks to confirm).
- `app-prefs`: chosen app settings (Bartender, BetterMouse, AltTab, Stats, Festivitas,
  OpenSCAD, KeyboardCleanTool) in `macos/prefs/`, allow-list only (`macos/prefs/allowlist`),
  so licenses and app state stay out of this public repo. `app-prefs export` on the Mac
  you changed them on, review and commit; `app-prefs apply` merges them in (runs on apply,
  skipping running apps; `app-prefs apply --restart`, which `mac-setup` uses, quits a running
  app that differs, applies and opens it again). `check` and `diff` list differing key names, never values. A test
  fails if a committed setting looks like a license, token or email address.
  BetterMouse is compared by content: it re-saves its maps in a new order on every launch
  and keeps one entry per mouse per connection (Bolt, Bluetooth), so a reorder or a newly
  seen connection isn't a difference, and `apply` keeps devices only this Mac has.
- `streamdeck-library`: indexes the Stream Deck library (OneDrive (Unstable Studios) > Apps >
  Stream Deck library: purchased profile packs and sideloaded plugins, kept out of this repo).
  `build` after adding or replacing a file rewrites its `library.json` (checksums and the profile
  variants in each pack); `check` verifies the files; `extract <pack> --app <app>` copies a pack's
  profile out, as a starting point for our own. `streamdeck-apply`, which installs our own
  profiles from this repo, is designed in [docs/streamdeck.md](docs/streamdeck.md).
- PrusaSlicer user presets (filament, print) are plain dotfiles under
  `Library/Application Support/PrusaSlicer`; after changing one, `chezmoi re-add` it.
- Kept private, through each app's own export saved to OneDrive (Unstable Studios) > Apps >
  Mac app exports: Stream Deck profiles, BetterDisplay settings and Claude Code's memories and prompt history (`claude-sync export` on the old Mac before wiping it; mac-setup runs `claude-sync import`). `mac-setup` checks OneDrive is signed in first and reminds you to restore them.

When workstation apps fail to install, the end-of-apply summary lists each one with its cause and the
command that fixes it. Apps that are already installed in a way Homebrew can't take over (an installer
that updates itself, like OneDrive or Fusion, or a newer copy) are skipped on that Mac and still installed on
the others. Run `brew-why` any time for the same list (`brew-why <cask>` for one app).

## Keyboard shortcuts

`macos/shortcuts.toml` lists every keyboard shortcut once, with the app that owns it. `shortcut-check`
(also in `make test` and CI) reads the bindings the dotfiles manage — macOS system shortcuts
(`macos/symbolichotkeys.plist`), the BTT preset, AltTab's settings — and fails on a **conflict**
(two owners on the same keys), an **undeclared** binding, or a **stale** entry. Raycast's settings
are encrypted, so its hotkeys are entered by hand (`source = "manual"`) and only checked for
conflicts, as are app settings changed by hand (Zoom's video shortcut). `shortcut-check --list` prints the whole map.

Each job has one owner, picked as the best tool for it; an app can own several jobs, and the
same feature in other apps is turned off (BTT's clipboard manager is pinned off, for example).
Owners now: window management BTT (drag-to-snap, the ⌃⌥ keys, ⌃⌥⌘ move and ⌃⇧⌘ resize), the
Caps Lock Hyper key and Hyper+key shortcuts BTT,
app switching AltTab (⌘Tab), menu bar Bartender, launcher, clipboard history (⇧⌘V) and link
cleaning Raycast (Link Cleaner, on demand: BTT cleans links only inside its clipboard manager, which
is off). After changing a shortcut in an
app, export it (`btt-sync export`, `app-prefs export`), update the registry, and run
`shortcut-check`.

## BetterTouchTool

BTT is installed from [folivora.ai](https://folivora.ai), not Homebrew (BTT warns about
Homebrew installs: `brew upgrade` replaces the app under its own updater). Its Default preset,
with general settings, lives in `macos/btt/Default.bttpreset` and isn't deployed by chezmoi:

- `btt-sync import` on a new Mac, after installing BTT
- `btt-sync export` after changing triggers, then review and commit the diff. Export sorts the
  preset, drops machine state (launch counts, lid state) and keeps the pinned settings in
  `btt-sync`: no Imgur uploads, no usage logging, BTT off the Stream Deck (Elgato's app
  owns it; its keys call BTT actions), and BTT's clipboard manager and link cleaning off
  (Raycast's jobs). Export also drops per-trigger update times, which change on every import.
  A test checks the committed preset.

`mac-setup` compares BTT's global keyboard shortcuts and move/resize modifier keys with the
preset's, so it asks for a re-import when they differ after an earlier import. If BTT then lists two
presets named Default, delete the older one.

Caps Lock is the Hyper key (⌃⌥⇧⌘) on every keyboard, set in the preset; holding it alone for
0.65 s and releasing toggles Caps Lock. Hyper+key shortcuts belong to BTT (see
`macos/shortcuts.toml`). BTT only sees Caps Lock while System Settings › Keyboard › Modifier
Keys leaves it as Caps Lock.

The Stream Deck camera key sends ⌃⇧⌘V to Zoom, so on a new Mac set Zoom › Settings › Keyboard
Shortcuts › Start/Stop Video to ⌃⇧⌘V (Zoom's default ⇧⌘V is Raycast's Clipboard History).
`mac-setup` asks for it.

BTT's MCP server (port 64832, turned on in BTT's settings) lets Claude Code read and change
triggers; `mac-setup` checks it's on.

This repo is public: keep secrets out of BTT triggers.

## Raycast

Raycast's settings live in an encrypted database, so the dotfiles don't hold them. Instead:

- **Cloud Sync** (Pro) carries quicklinks, snippets, extensions (turned on per Mac), AI
  commands, MCP servers and hotkeys between Macs. A new Mac can reset some hotkeys when it first joins: check them
  against `shortcut-check --list`.
- **Weekly exports** (Settings › Advanced › Export, set on each Mac) go to OneDrive › Apps ›
  Mac app exports › Raycast › <computer name>, last 5 kept. The `.rayconfig` is encrypted; its passphrase is in 1Password. Import
  Settings & Data restores it, category by category.
- **Per-Mac settings** don't sync and are set by hand: Script Folders (`~/.local/bin`, whose
  scripts carry Raycast headers), MCP Server › Connect App › Claude Code with Store off under
  Shared Extensions, and the Windows apps from Parallels unticked in Settings › Extensions ›
  Applications. Raycast's MCP server can change most settings by ID, so Claude Code can do the
  app list.

`mac-setup` walks through all three.

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
