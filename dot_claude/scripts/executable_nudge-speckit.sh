#!/bin/bash
# PreToolUse hook: nudge user to write specs before coding.
# Advisory only — always exits 0. Silent if specs exist or .specifyignore is present.
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

# Opt-out: .specifyignore at repo root silences the nudge
[[ -f "$git_root/.specifyignore" ]] && exit 0

specify_dir="$git_root/.specify"

# Features live in specs/<NNN-name>/ (.specify/memory only holds the constitution).
if [[ -d "$specify_dir" ]]; then
  if [[ -n "$(ls -A "$git_root/specs" 2>/dev/null)" ]]; then
    # Specs exist — no nudge needed
    exit 0
  fi

  # .specify/ exists but no specs written yet — nudge to write specs
  echo "spec-kit: .specify/ found but no specs yet. Run /speckit-specify to draft a spec before writing code." >&2
  exit 0
fi

# No .specify/ at all — nudge to try spec-kit
echo "spec-kit: Consider trying spec-kit for this project. Run \`specify init --here --integration claude\` to start (commands are /speckit-<name>, e.g. /speckit-plan). Add .specifyignore to silence this." >&2
exit 0
