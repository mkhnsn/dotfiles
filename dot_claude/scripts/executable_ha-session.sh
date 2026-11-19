#!/bin/bash
# Report this Claude Code session's state to Home Assistant, for the desk panel and phone
# notifications (echo-core: homeassistant/config/packages/claude_sessions.yaml).
# Runs as an async hook on SessionStart, UserPromptSubmit, Notification, Stop and SessionEnd,
# with the hook's JSON on stdin. Never blocks or fails Claude: no webhook URL file (mac-setup
# writes it from 1Password) means nothing is sent, and errors are ignored.

url_file="${XDG_CONFIG_HOME:-$HOME/.config}/claude-ha/webhook-url"
[ -r "$url_file" ] || exit 0
url="$(head -1 "$url_file")"
[ -n "$url" ] || exit 0

input="$(cat)"
cwd="$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)"
# Project = the git repo's folder name, else the working folder's.
top="$(git -C "${cwd:-.}" rev-parse --show-toplevel 2>/dev/null || echo "${cwd:-?}")"
host="$(scutil --get LocalHostName 2>/dev/null || hostname -s)"
target=""
[ -n "${TMUX:-}" ] && target="$(tmux display-message -p '#S:#I' 2>/dev/null)"

payload="$(jq -c --arg project "${top##*/}" --arg host "$host" --arg tmux "$target" \
  '{session_id, event: .hook_event_name, project: $project, host: $host, tmux: $tmux,
    message: (.message // "")}' <<<"$input" 2>/dev/null)" || exit 0

curl -s -m 3 -o /dev/null -X POST -H 'Content-Type: application/json' --data "$payload" "$url" || true
exit 0
