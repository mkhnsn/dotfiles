# /next — Wrap Up and Plan Next

This is a user-invokable skill. Run it as `/next`.

Wraps up the current work in whatever repo you're in, cleans up branches, and offers to plan the next task from open GitHub issues.

## Workflow

### 1. Commit Outstanding Work

Check the current state of the repo:

```bash
git status
git branch --show-current
```

- If there are uncommitted changes (staged or unstaged), summarize them and offer to commit using conventional commit format
- If on a feature branch with commits ahead of main, offer to push and open a PR (use the `/pr` skill if accepted)
- If on main with no changes, skip to step 2

Do NOT force anything — ask before committing or pushing.

### 2. Switch to Main

Once all work is committed (or the user declines):

```bash
git checkout main
git pull --ff-only
```

If `git pull` fails due to divergence, warn the user and stop.

### 3. Clean Up Stale Branches

Prune remote tracking refs and delete local branches whose upstream is gone:

```bash
git fetch --prune
```

Then find and list branches marked as `[gone]`:

```bash
git branch -vv | grep ': gone]'
```

- Show the list to the user
- Ask for confirmation before deleting
- If confirmed, delete them:

```bash
git branch -d <branch>  # use -d (safe delete), not -D
```

If `-d` fails because a branch isn't fully merged, warn the user and ask whether to force-delete with `-D`.

Also list any local branches that have already been merged into main:

```bash
git branch --merged main | grep -v '^\*\|main\|master'
```

Offer to delete those too (same confirm-first approach).

### 4. Plan Next Task

Fetch open issues from GitHub:

```bash
gh issue list --limit 20 --state open
```

If there are open issues:
- Present them in a numbered list with title, labels, and assignee
- Ask the user which issue they'd like to work on (or if they have something else in mind)
- Once they pick an issue, read its details with `gh issue view <number>` and propose a plan:
  - Suggest a branch name following coding-rules conventions (`feat/`, `fix/`, etc.)
  - Outline the implementation approach
  - Create the branch and start working when the user approves

If there are no open issues:
- Let the user know the board is clear
- Ask if they have something in mind or want to call it done

### 5. Done

Summarize what happened:
- Commits made
- Branches cleaned up
- Next task selected (if any)
