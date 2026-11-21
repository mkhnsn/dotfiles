#!/bin/bash
# PreToolUse hook (Bash): ask before committing or pushing on main/master.
# Auto mode's own rules cover destructive commands (force push, reset --hard, rm -rf of
# things you didn't ask for); this covers the house rule they don't: no work on main.
set -euo pipefail

command=$(jq -r '.tool_input.command // ""')
printf '%s\n' "$command" | head -1 | grep -qE '(^|&&|;)[[:space:]]*git[[:space:]]+(commit|push)' || exit 0

branch=$(git branch --show-current 2>/dev/null || true)
case "$branch" in
  main|master)
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"On %s. Commit on a branch instead (<type>/<short-description>), or confirm."}}\n' "$branch" ;;
esac
exit 0
