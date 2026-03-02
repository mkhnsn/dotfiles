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

## Claude Code Integration

This repo manages Claude Code configuration via `dot_claude/`. Settings are merged at apply time by `dot_claude/modify_settings.json` (a chezmoi modify script that preserves interactively-set keys like `enabledPlugins`).

### Hooks

Defined in `modify_settings.json`, applied to `~/.claude/settings.json`:

| Event | Script | Behavior |
|-------|--------|----------|
| `PreToolUse` | `scripts/guard-destructive.sh` | Warns on destructive commands (commit/push to main, force push, reset --hard, rm -rf, etc.). User-overridable via approval prompt. |
| `PreToolUse` | `scripts/nudge-speckit.sh` | On Edit/Write, nudges to use spec-kit. Silent if specs exist or `.specifyignore` is present at repo root. Advisory only. |
| `PostToolUse` | `scripts/post-edit-lint.sh` | Auto-lints after Edit/Write: eslint (JS/TS), ruff (Python), rustfmt (Rust), gofmt (Go), shfmt (shell). Async, advisory only. |

### Skills (slash commands)

| Skill | File | Usage |
|-------|------|-------|
| `/doctor` | `skills/doctor/SKILL.md` | Runs `doctor.sh` diagnostics and interprets the output |
| `/pr` | `skills/pr/SKILL.md` | Creates a PR following coding-rules conventions |
| `/new-repo` | `skills/new-repo/SKILL.md` | Scaffolds a new GitHub repo with README, license, CLAUDE.md |
| `/coding-rules` | `skills/coding-rules/SKILL.md` | Git workflow and conventional commit conventions |

### Custom Agents

Defined in `dot_claude/agents/`. Use with `--agent <name>`:

| Agent | Purpose |
|-------|---------|
| `architect` | System design, architecture analysis, and trade-off evaluation |
| `debugger` | Investigate and fix bugs with root cause analysis |
| `docs` | Technical writing (READMEs, API docs, code documentation) |
| `refactorer` | Improve code structure without changing behavior |
| `reviewer` | Code review focused on bugs, security, and breaking changes |
| `security` | Security audit (secrets, injection, auth, deps, config) |
| `tester` | Write and run tests, find coverage gaps |
| `ux-reviewer` | Frontend/UI audit for accessibility, usability, and consistency |

### Permissions

Base permissions are merged into `settings.json` by the modify script (existing interactive permissions are preserved):
- Git: fetch, pull, status, log, diff, branch, stash, remote, add, commit, push, checkout, switch, merge, rebase
- GitHub CLI: `gh pr`, `gh issue`, `gh api`, `gh run`, `gh repo`, `gh label`, `gh auth`
- Safe utilities: `ls`, `tree`, `wc`, `sort`, `mkdir`
- IDE: `mcp__ide__getDiagnostics`
- `WebFetch`, `WebSearch`
- `Read`, `Edit`, `Write` for `~/src/**`

### Shell Functions (pipe mode)

Defined in `dot_config/shell/functions.zsh`:

| Function | Usage |
|----------|-------|
| `ai-commit` | Generate commit message from staged changes |
| `ai-review` | Review uncommitted changes for bugs/security |
| `ai-explain <file>` | Explain what a file does (also works with pipes) |
| `ai "question"` | Quick one-shot question from the terminal |

### Zsh Completions

- `dot_config/zsh/completions/_claude` — vendored completion for the Claude Code CLI (based on wbingli/zsh-claudecode-completion)
- Completion setup: fzf-tab handles all TAB completion; fzf's TAB binding is removed to avoid a redundant context-switch layer
