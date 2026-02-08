# Coding Ground Rules

This skill defines the standard coding conventions for all projects. These rules apply automatically whenever you are writing code, making commits, or working with git.

## Git Workflow

### Feature Branches Required

Never commit directly to `main` or `master`. Always create a feature branch first:

- `feat/<description>` — new features
- `fix/<description>` — bug fixes
- `docs/<description>` — documentation changes
- `chore/<description>` — maintenance tasks
- `refactor/<description>` — code restructuring
- `test/<description>` — adding or updating tests
- `style/<description>` — formatting, linting
- `perf/<description>` — performance improvements
- `ci/<description>` — CI/CD changes
- `build/<description>` — build system changes

Before starting work, check the current branch. If on `main` or `master`, create and switch to an appropriate feature branch.

### Conventional Commits

All commit messages must follow the conventional commit format:

```
type(scope): description
```

**Types:** `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `style`, `perf`, `ci`, `build`

**Rules:**
- Type is required, scope is optional but encouraged
- Description must be lowercase, imperative mood, no period at end
- Keep the subject line under 72 characters
- Use the body for additional context when needed

**Examples:**
```
feat(auth): add OAuth2 login flow
fix(api): handle null response from upstream
docs: update API reference for v2 endpoints
chore(deps): bump express to 4.18.2
refactor(db): extract connection pooling logic
```

### Atomic Commits

Each commit should represent a single logical change. Don't bundle unrelated changes together.

- One feature per commit
- One bug fix per commit
- Refactoring separate from behavior changes
- If you need to say "and" to describe what a commit does, it should probably be two commits

### PR Workflow

- Push feature branches to the remote
- Open pull requests for merging into main/master
- Don't merge directly into main/master without a PR
- Use descriptive PR titles and summaries

## Documentation

- Update or create documentation alongside code changes when behavior changes
- READMEs should reflect the current state of the project
- Document public APIs, configuration options, and non-obvious behavior
- Don't add docs for self-explanatory code — only when it adds value

## Working With These Rules

When the user asks you to make changes:

1. Check the current branch — if on main/master, create a feature branch first
2. Make the changes
3. Commit with conventional commit format
4. If the user asks to commit/push/PR, follow the PR workflow

These rules complement the `commit-commands:commit` plugin. When using that plugin, ensure the commit message follows conventional commit format.
