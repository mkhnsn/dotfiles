---
paths:
  - "**/*.{tsx,jsx,vue,svelte,css,scss,html}"
---

# Frontend

- Icons come from `lucide-react` (or the project's icon library), never hand-drawn or inline SVG. Prefer icons over text for repeated row actions, with accessible names and tooltips.
- Every async action shows feedback right away: disabled with a spinner while running, then a success or error state; long operations show progress. "Nothing visibly happened" is a bug.
- Support light and dark themes, with consistent spacing.
- UI text follows the `ui-copy` skill. Slide decks follow `deck-copy` instead.
