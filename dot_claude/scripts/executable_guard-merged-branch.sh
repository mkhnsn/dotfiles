#!/bin/bash
# PreToolUse hook: warn when working on a branch whose PR has been merged.
# Fires on Edit, Write, and Bash (git commit/push). Advisory — always exits 0.
set -euo pipefail

input=$(cat)
tool=$(echo "$input" | jq -r '.tool_name // ""')

warn() {
  cat <<ENDJSON
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"$1"}}
ENDJSON
  exit 0
}

# --- Determine if this action is worth checking ---
case "$tool" in
  Edit|Write) ;;
  Bash)
    command=$(echo "$input" | jq -r '.tool_input.command // ""')
    # Only check for git commit/push commands
    if ! echo "$command" | head -1 | grep -qE '(^|&&|;)\s*git\s+(commit|push)'; then
      exit 0
    fi
    ;;
  *) exit 0 ;;
esac

# --- Must be in a git repo ---
git_root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0

# --- Get current branch ---
branch=$(git branch --show-current 2>/dev/null) || exit 0
[[ -n "$branch" ]] || exit 0

# Skip main/master — other hooks handle those
[[ "$branch" != "main" && "$branch" != "master" ]] || exit 0

# --- Cache: avoid hitting gh on every keystroke ---
# Cache result for 60 seconds per branch per repo
cache_dir="${TMPDIR:-/tmp}/claude-merged-branch-cache"
mkdir -p "$cache_dir"
cache_key=$(echo "${git_root}:${branch}" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "${git_root}:${branch}" | md5 2>/dev/null | tr -d ' ')
cache_file="$cache_dir/$cache_key"

if [[ -f "$cache_file" ]]; then
  cache_age=$(( $(date +%s) - $(stat -f%m "$cache_file" 2>/dev/null || stat -c%Y "$cache_file" 2>/dev/null || echo 0) ))
  if (( cache_age < 60 )); then
    cached=$(cat "$cache_file")
    if [[ "$cached" == "merged" ]]; then
      warn "WARNING: Branch '$branch' has already been merged. You are likely working on a stale branch. Switch to main and create a new branch for further work."
    fi
    exit 0
  fi
fi

# --- Check if this branch's PR was merged ---
# gh pr view exits 0 if a PR exists for this branch; check its state
pr_state=$(gh pr view "$branch" --json state --jq '.state' 2>/dev/null) || exit 0

if [[ "$pr_state" == "MERGED" ]]; then
  echo "merged" > "$cache_file"
  warn "WARNING: Branch '$branch' has already been merged. You are likely working on a stale branch. Switch to main and create a new branch for further work."
else
  echo "open" > "$cache_file"
fi

exit 0
