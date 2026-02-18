#!/bin/bash
# PostToolUse hook: run linters after Edit/Write on supported file types.
# Exits 0 always — linting is advisory, never blocks.
set -euo pipefail

input=$(cat)
tool=$(echo "$input" | jq -r '.tool_name // ""')
file=$(echo "$input" | jq -r '.tool_input.file_path // ""')

# Only act on Edit and Write
[[ "$tool" == "Edit" || "$tool" == "Write" ]] || exit 0
[[ -n "$file" && -f "$file" ]] || exit 0

# Find project root (for running project-local linters)
project_root=$(git -C "$(dirname "$file")" rev-parse --show-toplevel 2>/dev/null || echo "")

ext="${file##*.}"

case "$ext" in
  ts|tsx|js|jsx|mjs|cjs)
    if [[ -n "$project_root" ]]; then
      # Prefer project-local eslint, fall back to npx
      if [[ -x "$project_root/node_modules/.bin/eslint" ]]; then
        "$project_root/node_modules/.bin/eslint" --no-error-on-unmatched-pattern --fix "$file" 2>/dev/null || true
      fi
    fi
    ;;
  py)
    if command -v ruff >/dev/null 2>&1; then
      ruff check --fix "$file" 2>/dev/null || true
    fi
    ;;
  rs)
    if command -v rustfmt >/dev/null 2>&1; then
      rustfmt --edition 2021 "$file" 2>/dev/null || true
    fi
    ;;
  go)
    if command -v gofmt >/dev/null 2>&1; then
      gofmt -w "$file" 2>/dev/null || true
    fi
    ;;
  sh|bash|zsh)
    if command -v shfmt >/dev/null 2>&1; then
      shfmt -w "$file" 2>/dev/null || true
    fi
    ;;
esac

exit 0
