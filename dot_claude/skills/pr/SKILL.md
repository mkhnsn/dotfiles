# /pr — Create a Pull Request

This is a user-invokable skill. Run it as `/pr` or `/pr <base-branch>`.

## Argument Parsing

- If an argument is provided (e.g., `/pr develop`), use it as the base branch
- If no argument is provided, default to `main`
- The argument string is: `{{ args }}`

## Workflow

### 1. Preflight

Check the current state:

- Ensure you're NOT on main/master (if so, ask the user to create a branch first)
- Run `git status` to check for uncommitted changes — offer to commit them first
- Run `git log main..HEAD --oneline` to see what commits will be in the PR

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

### 6. Done

Print the PR URL.
