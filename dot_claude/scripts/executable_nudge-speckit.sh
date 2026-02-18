#!/bin/bash
# PreToolUse hook: nudge user to write specs before coding in spec-kit-enabled projects.
# Advisory only — always exits 0. Silent in projects without .specify/.
set -euo pipefail

input=$(cat)
tool=$(echo "$input" | jq -r '.tool_name // ""')

# Only act on code-modifying tools
case "$tool" in
  Edit|Write) ;;
  *) exit 0 ;;
esac

# Get the file path being edited/written
file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""')
[[ -n "$file_path" ]] || exit 0

# Find the git root for this file
dir=$(dirname "$file_path")
git_root=$(cd "$dir" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || exit 0

specify_dir="$git_root/.specify"

# No .specify/ directory → not a spec-kit project, pass silently
[[ -d "$specify_dir" ]] || exit 0

# Check if any spec documents exist in .specify/memory/
memory_dir="$specify_dir/memory"
if [[ -d "$memory_dir" ]] && [[ -n "$(ls -A "$memory_dir" 2>/dev/null)" ]]; then
  # Specs exist — no nudge needed
  exit 0
fi

# .specify/ exists but no specs written yet — nudge
cat <<'ENDJSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"This project uses spec-kit (.specify/ found) but has no specs yet. Consider running `specify` to draft a spec before writing code — it helps Claude produce better results."}}
ENDJSON
exit 0
