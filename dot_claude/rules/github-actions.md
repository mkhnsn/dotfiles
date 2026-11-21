---
paths:
  - ".github/workflows/**"
  - "**/release-please-config.json"
---

# GitHub Actions

- unstable-studios repos use the org's shared reusable workflows (`unstable-studios/.github`), pinned to `@main` on purpose; don't SHA-pin them.
- Packages published to GitHub Packages start private; CI in another repo gets 403 until it's granted access.
- Fix action deprecation warnings (Node versions, action majors) when they appear.
- Before pushing a `Release-As` commit, check for an open release-please PR; conventional commits open one already.
