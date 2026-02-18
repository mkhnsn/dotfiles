#!/bin/bash
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // ""')

warn() {
  # Exit 0 + hookSpecificOutput with permissionDecision "ask" = prompt user for approval.
  # hookEventName is required for Claude Code to apply the permission decision.
  # permissionDecisionReason is shown to the user in the approval prompt.
  # Exit 2 would hard-block with no override, which is NOT what we want.
  cat <<ENDJSON
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"$1"}}
ENDJSON
  exit 0
}

# Strip heredoc bodies and quoted strings so we don't match text inside
# commit messages, echo statements, etc. Only match actual commands.
clean_cmd=$(printf '%s\n' "$command" \
  | sed "/<<['\\ ]*EOF/,/^[[:space:]]*EOF/d" \
  | sed 's/"[^"]*"//g' \
  | sed "s/'[^']*'//g")

# ---- Guard: commits/pushes to main/master ----
# Use the first line of the raw command (git commit is always the outer command)
if echo "$command" | head -1 | grep -qE '(^|&&|;)\s*git\s+(commit|push)'; then
  branch=$(git branch --show-current 2>/dev/null || echo "")
  if [[ "$branch" == "main" || "$branch" == "master" ]]; then
    warn "WARNING: You are on the '$branch' branch. Committing/pushing directly to $branch is discouraged. Ask the user if they really want to proceed, or suggest creating a feature branch first."
  fi
fi

# ---- Guard: force push ----
if echo "$clean_cmd" | grep -qE 'git\s+push\s+.*--force|git\s+push\s+-f'; then
  warn "WARNING: Force push detected. This can overwrite remote history and is usually destructive. Ask the user to confirm."
fi

# ---- Guard: hard reset ----
if echo "$clean_cmd" | grep -qE 'git\s+reset\s+--hard'; then
  warn "WARNING: git reset --hard will discard all uncommitted changes. Ask the user to confirm."
fi

# ---- Guard: discard working tree changes ----
if echo "$clean_cmd" | grep -qE 'git\s+(checkout|restore)\s+\.\s*$'; then
  warn "WARNING: This will discard all unstaged changes in the working tree. Ask the user to confirm."
fi

# ---- Guard: git clean ----
if echo "$clean_cmd" | grep -qE 'git\s+clean\s+-[a-zA-Z]*f'; then
  warn "WARNING: git clean -f will permanently delete untracked files. Ask the user to confirm."
fi

# ---- Guard: delete branch ----
if echo "$clean_cmd" | grep -qE 'git\s+branch\s+-[a-zA-Z]*D'; then
  warn "WARNING: git branch -D force-deletes a branch without checking merge status. Ask the user to confirm."
fi

# ---- Guard: rm -rf ----
if echo "$clean_cmd" | grep -qE '(^|&&|;|\|)\s*rm\s+-[a-zA-Z]*r[a-zA-Z]*f|(^|&&|;|\|)\s*rm\s+-[a-zA-Z]*f[a-zA-Z]*r'; then
  warn "WARNING: rm -rf detected. This recursively deletes files without confirmation. Ask the user to confirm the path is correct."
fi

exit 0
