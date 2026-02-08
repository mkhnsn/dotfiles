# /new-repo — Create & Scaffold a New GitHub Repository

This is a user-invokable skill. The user runs it as `/new-repo <name>` or `/new-repo <org>/<name>`.

## Argument Parsing

- If the argument is just a name (e.g., `my-app`), use org `unstable-studios` → `unstable-studios/my-app`
- If the argument includes a slash (e.g., `other-org/my-app`), use that org and name directly
- If no argument is provided, ask the user for a repo name

## Workflow

Follow these steps in order:

### 1. Parse and Confirm

Parse the repo name from the argument: `{{ args }}`. Determine the org and repo name. Show the user what will be created:

```
Creating: github.com/<org>/<repo>
Path: ~/src/github.com/<org>/<repo>
```

### 2. Create Directory

```bash
mkdir -p ~/src/github.com/<org>/<repo>
cd ~/src/github.com/<org>/<repo>
```

### 3. Initialize Git

```bash
git init
```

### 4. Gather Preferences

Ask the user (using AskUserQuestion) about:

- **Project description** — a one-liner for the README and GitHub repo description
- **`.gitignore` type** — suggest based on context, or ask (e.g., Node, Go, Python, Rust, etc.). Use GitHub's gitignore templates via `gh api /gitignore/templates/<type>` to fetch the content.
- **License** — default to MIT, ask if they want something different

### 5. Scaffold Files

Create these files in the repo directory:

**README.md:**
```markdown
# <repo>

<description from step 4>
```

**.gitignore:** Use the template from step 4.

**LICENSE:** Generate MIT license (or chosen license) with the current year and `unstable studios` as the copyright holder (or appropriate name for the org).

**CLAUDE.md:** Create a project CLAUDE.md that includes:
```markdown
# CLAUDE.md

## Project Overview

<description>

## Coding Conventions

### Git Workflow
- Always use feature branches — never commit directly to main/master
- Branch naming: `feat/`, `fix/`, `docs/`, `chore/`, `refactor/`, `test/`, `style/`, `perf/`, `ci/`, `build/`
- Conventional commits: `type(scope): description`
  - Types: feat, fix, docs, chore, refactor, test, style, perf, ci, build
- Atomic commits — one logical change per commit
- Push branches and open PRs — don't merge directly to main

### Documentation
- Update docs when behavior changes
- Keep README current
```

Extend the CLAUDE.md with any project-specific details that make sense for the chosen language/framework.

### 6. Initial Commit

```bash
git add -A
git commit -m "feat: initialize project"
```

### 7. Create GitHub Repository

```bash
gh repo create <org>/<repo> --private --source=. --push --description "<description>"
```

### 8. Link to Unstable Studios (if applicable)

If the org is `unstable-studios`, run:

```bash
link-unstable
```

If `link-unstable` is not available, skip this step silently.

### 9. Done

Tell the user the repo is ready and show:
- Local path: `~/src/github.com/<org>/<repo>`
- GitHub URL: `https://github.com/<org>/<repo>`
- Remind them they're on the `main` branch and should create a feature branch before starting work
