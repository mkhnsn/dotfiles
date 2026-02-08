#!/bin/bash
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // ""')

# Only check git commit and git push commands
if ! echo "$command" | grep -qE '^\s*git\s+(commit|push)'; then
  exit 0
fi

# Get current branch
branch=$(git branch --show-current 2>/dev/null || echo "")

if [[ "$branch" == "main" || "$branch" == "master" ]]; then
  cat >&2 <<ENDJSON
{"hookSpecificOutput":{"permissionDecision":"ask"},"systemMessage":"WARNING: You are on the '$branch' branch. Committing/pushing directly to $branch is discouraged. Ask the user if they really want to proceed, or suggest creating a feature branch first."}
ENDJSON
  exit 2
fi

exit 0
