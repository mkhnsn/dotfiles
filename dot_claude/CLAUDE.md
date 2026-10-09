# Global instructions

These apply in every project. Project-level CLAUDE.md files take precedence.

## Git
- Never commit to `main`/`master`. Check the branch first and create one if needed: `<type>/<short-description>`.
- Conventional commits: `type(scope): description` — lowercase, imperative, no trailing period, subject under 72 chars. Types: feat, fix, docs, chore, refactor, test, style, perf, ci, build.
- Keep commits atomic; merge to main only via PR (`/pr`).
- Full conventions: the `/coding-rules` skill.

## Docs
- Update docs (README, CLAUDE.md) in the same change when behavior changes; skip docs for self-explanatory code.

## Environment
- Repos live under `~/src` (ghq). Resolve a repo name to its path with `find-repo <name>`.
- Dotfiles (including this file and `~/.claude/settings.json`) are managed by chezmoi in `~/.local/share/chezmoi`. Edit the source there, not the files in `~/.claude`, then `chezmoi apply`.
