#!/bin/bash
# Claude Code status line: repo/path  branch*  ⇡n ⇣n
set -euo pipefail

input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')

# --- directory display ---
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git_root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
  repo_name=$(basename "$git_root")
  rel_path=$(python3 -c "import os; print(os.path.relpath('$cwd', '$git_root'))" 2>/dev/null || echo ".")
  if [ "$rel_path" = "." ]; then
    dir_display="$repo_name"
  else
    dir_display="$repo_name/$rel_path"
  fi
else
  dir_display=$(echo "$cwd" | awk -F'/' '{if (NF <= 3) print $0; else printf "%s/%s/%s", $(NF-2), $(NF-1), $NF}')
fi

output=$(printf "\033[1;36m%s\033[0m" "$dir_display")

# --- git branch + dirty + ahead/behind ---
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" branch --show-current 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    output="$output $(printf "\033[0;31m%s\033[0m" "$branch")"

    # dirty indicator
    if ! git -C "$cwd" diff --quiet 2>/dev/null || ! git -C "$cwd" diff --cached --quiet 2>/dev/null; then
      output="$output$(printf "\033[0;31m*\033[0m")"
    fi

    # ahead/behind upstream
    upstream=$(git -C "$cwd" rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)
    if [ -n "$upstream" ]; then
      counts=$(git -C "$cwd" rev-list --left-right --count --no-optional-locks HEAD...@{u} 2>/dev/null || true)
      ahead=$(echo "$counts" | cut -f1)
      behind=$(echo "$counts" | cut -f2)
      if [ -n "$ahead" ] && [ "$ahead" -gt 0 ]; then
        output="$output $(printf "\033[1;32m⇡%s\033[0m" "$ahead")"
      fi
      if [ -n "$behind" ] && [ "$behind" -gt 0 ]; then
        output="$output $(printf "\033[1;31m⇣%s\033[0m" "$behind")"
      fi
    fi
  fi
fi

echo "$output"
