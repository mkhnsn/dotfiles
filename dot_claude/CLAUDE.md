# Global instructions

These apply in every project. Project-level CLAUDE.md files take precedence. File-specific
rules (frontend, Node, Cloudflare, CI) live in `~/.claude/rules/` and load with matching files.

## About me
- Mike Hansen. I run Unstable Studios (write it in title case; `unstable-studios` only in slugs, URLs and paths) and do IT and identity work for Fog Cutter Holdings. Explain at an experienced engineer's level.
- Email for anything in a product, config or account: mike@unstablestudios.com, never my personal address.
- Chrome is the browser everywhere; never suggest Edge. Outside Microsoft 365 and Intune, don't propose Entra sign-in: apps use Auth0, internal tools Cloudflare Access.

## Writing
- US English everywhere: license, color, behavior, meter.
- Deliver files, not Claude Docs: xlsx or csv for anything with numbers, Markdown in the repo for designs. Summaries for clients are paste-ready Slack text in a code block, written as me.
- User-facing text (labels, help, errors, confirmations) follows the `ui-copy` skill: say what something is or what to do, briefly; no commentary.
- Slide decks follow the `deck-copy` skill: headlines are claims, facts instead of adjectives, no slogan formulas.

## Working
- Fetch live docs for any API, spec or datasheet the work depends on; don't rely on recollection. Cite the URL.
- No backwards compatibility: when renaming or replacing something, change every caller and delete the old one. No aliases, shims or re-exports.
- Fix build, lint and runtime warnings when they appear, including major-version bumps for deprecations.
- Plan multi-step work as GitHub issues (one per step, a milestone per phase); PRs say `Closes #N`.
- Update every doc that mentions a changed thing (README, CLAUDE.md, runbooks) in the same change; skip docs for self-explanatory code.
- Remote hosts: reuse one SSH connection (ControlMaster) and poll no faster than every 15–20 s; some hosts rate-limit port 22.

## Git and PRs
- Never commit to `main`/`master`: branch first, `<type>/<short-description>`. Conventional commits (`type(scope): description`, lowercase, imperative, under 72 chars); details in the `coding-rules` skill. Commit, push and open the PR with `/pr`.
- Stage explicit paths, never `git add -A` or `git add .`.
- Before pushing more commits to a PR branch, check the PR is still open; if it merged, start a new branch from `main`.
- Every PR gets a `reviewer` subagent pass over its diff (the code, not my conclusions) before it's ready. Report its findings with the PR. Test a reviewer's specific claim before dismissing it.
- Don't merge PRs unless I ask. An ask covers that batch of work only. After a PR merges, delete its branch locally and on the remote without asking.
- Multi-PR work: use stacked PRs.
- Every comment you post on GitHub as me (`gh issue comment`, `gh pr comment`, review comments, `gh api` comment calls) ends with a line `<!-- claude-code -->`. `gh` is signed in as me, so without it the org tracker takes your comment on a `needs-input` issue for my answer and starts a Claude run. Never add it to text I wrote.

## Environment
- Repos live under `~/src` (ghq). Resolve a repo name to its path with `find-repo <name>`.
- Dotfiles (including this file, `~/.claude/rules/` and `~/.claude/settings.json`) are managed by chezmoi in `~/.local/share/chezmoi`. Edit the source there, not the files in `~/.claude`, then `chezmoi apply`.
