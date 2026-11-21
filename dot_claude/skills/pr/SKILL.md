---
name: pr
description: Commit pending work, push the branch and open a pull request with a summary and test plan. Use when asked to open, create or raise a PR, or to commit and push for review.
argument-hint: "[base-branch]"
---

# /pr — Create a Pull Request

This is a user-invokable skill. Run it as `/pr` or `/pr <base-branch>`.

## Argument Parsing

- If an argument is provided (e.g., `/pr develop`), use it as the base branch
- If no argument is provided, default to `main`
- The argument string is: `$ARGUMENTS`

## Workflow

### 1. Branch and commit

- On main/master, create a branch first: `<type>/<short-description>` (see coding-rules).
- Run `git status`. Commit pending changes as atomic conventional commits, staging explicit
  paths (never `git add -A`/`git add .`, which sweeps in build output).
- Run `git log <base>..HEAD --oneline` to see what the PR will contain.

### 2. Push

```bash
git push -u origin HEAD
```

### 3. Gather Context

Analyze all commits in the branch (not just the latest):

```bash
git log main..HEAD --format="%s%n%b"
git diff main...HEAD --stat
```

### 4. Create PR

Use `gh pr create` with:

- **Title**: Short summary (under 70 chars) derived from the commits. Use conventional commit style if the branch has a single logical change.
- **Body**: Use this template:

```markdown
## Summary

<1-3 bullet points describing what changed and why>

## Test plan

<Bulleted checklist of how to verify the changes>
```

### 5. Link

If the org is `unstable-studios` and `link-unstable` is available, run it.

### 6. Review

Run a reviewer subagent (the `reviewer` agent) over the PR's diff, giving it the code, not
your conclusions. Fix what it confirms, push, and note anything left in the PR.

### 7. Done

Print the PR URL. Don't merge: leave that to the user unless they asked for it.
