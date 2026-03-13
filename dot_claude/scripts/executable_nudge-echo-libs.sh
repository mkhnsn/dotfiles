#!/bin/bash
# PreToolUse hook: when editing a file that imports @unstable-studios/*,
# remind Claude to read the relevant package README(s) from node_modules.
# Advisory only — always exits 0.
set -euo pipefail

input=$(cat)
tool=$(echo "$input" | jq -r '.tool_name // ""')

# Only act on code-modifying tools
case "$tool" in
  Edit|Write) ;;
  *) exit 0 ;;
esac

file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""')
[[ -n "$file_path" ]] || exit 0

# Only care about source files that could have imports
case "$file_path" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.mts) ;;
  *) exit 0 ;;
esac

# Skip if the file is inside echo-libs itself
[[ "$file_path" == */echo-libs/* ]] && exit 0

# Skip if the file doesn't exist yet (new file being created)
[[ -f "$file_path" ]] || exit 0

# Find @unstable-studios/* imports in the file
packages=$(grep -oE '@unstable-studios/[a-z0-9-]+' "$file_path" 2>/dev/null | sort -u) || true
[[ -n "$packages" ]] || exit 0

# Find node_modules relative to the file
dir=$(dirname "$file_path")
while [[ "$dir" != "/" ]]; do
  [[ -d "$dir/node_modules/@unstable-studios" ]] && break
  dir=$(dirname "$dir")
done
[[ -d "$dir/node_modules/@unstable-studios" ]] || exit 0

nm="$dir/node_modules"

# Collect READMEs that exist for the imported packages
readmes=()
while IFS= read -r pkg; do
  name="${pkg#@unstable-studios/}"
  readme="$nm/$pkg/README.md"
  [[ -f "$readme" ]] && readmes+=("$readme")
done <<< "$packages"

[[ ${#readmes[@]} -gt 0 ]] || exit 0

echo "echo-libs: This file imports @unstable-studios packages. Read the docs before making changes:" >&2
for r in "${readmes[@]}"; do
  echo "  → $r" >&2
done
exit 0
