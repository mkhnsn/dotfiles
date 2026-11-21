#!/bin/bash
# PreToolUse hook (Bash): ask before committing or pushing on main/master.
# Auto mode's own rules cover destructive commands (force push, reset --hard, rm -rf of
# things you didn't ask for); this covers the house rule they don't: no work on main.
set -euo pipefail

command=$(jq -r '.tool_input.command // ""' 2>/dev/null) || exit 0
# Any git commit/push in the command, including `git -C dir commit` and `git -c k=v push`.
printf '%s\n' "$command" | grep -qE '(^|[;&|(]|[[:space:]])git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+(commit|push)([[:space:]]|$)' || exit 0

branch=$(git branch --show-current 2>/dev/null || true)
case "$branch" in
  main|master)
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"On %s. Commit on a branch instead (<type>/<short-description>), or confirm."}}\n' "$branch" ;;
esac
exit 0
