---
paths:
  - "**/package.json"
  - "**/*.{ts,tsx,js,jsx,mjs,cjs}"
---

# Node projects

- Use the project's package manager, which is pnpm unless the lockfile says otherwise: `pnpm test`, `pnpm exec <tool>` for project binaries (wrangler, vitest, tsc), `pnpm dlx` for one-offs. Not `npm`/`npx`.
- Typecheck the way CI does: `tsc -b` can reject syntax that `tsc --noEmit` allows.
