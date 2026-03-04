# /reviews — Check PR Review Comments

This is a user-invokable skill. Run it as `/reviews` or `/reviews <repo>`.

Checks all open PRs you authored for review comments, requested changes, and approvals.

## Argument Parsing

- If an argument is provided (e.g., `/reviews my-repo`), scope to that repo
- If no argument is provided, check the current repo
- The argument string is: `{{ args }}`

## Workflow

### 1. Identify the Repo

If an argument was given, use `find-repo` to resolve it:

```bash
find-repo <arg>
```

Otherwise use the current working directory. Confirm it's a git repo.

### 2. Fetch Open PRs You Authored

```bash
gh pr list --author @me --state open --json number,title,url,reviewDecision,updatedAt,headRefName
```

If no open PRs, let the user know and stop.

### 3. Gather Review Details

For each open PR, fetch review comments and review status:

```bash
gh pr view <number> --json reviews,comments,reviewDecision,latestReviews
```

And fetch inline review comments (these are separate from PR-level comments):

```bash
gh api repos/{owner}/{repo}/pulls/<number>/comments --jq '.[] | {user: .user.login, body: .body, path: .path, line: .line, created_at: .created_at}'
```

### 4. Present a Summary

For each PR, display:

- **PR title** and number (with URL)
- **Branch**: the head ref name
- **Review status**: approved, changes requested, review required, or commented
- **Unresolved comments**: list each with author, file/line, and the comment body
- **Approvals**: who approved and when

Group by urgency:
1. **Changes requested** — these need action
2. **Comments without decision** — may need a response
3. **Approved** — ready to merge

### 5. Offer Next Steps

Based on what was found, offer actionable options:

- If changes were requested: offer to check out that branch and address the feedback
- If approved with no unresolved comments: offer to merge with `gh pr merge <number> --squash --delete-branch`
- If there are review comments to respond to: offer to check out the branch

Ask the user what they'd like to do. If they pick a PR to work on, check out the branch:

```bash
git checkout <branch>
```

Then summarize the feedback that needs addressing.
