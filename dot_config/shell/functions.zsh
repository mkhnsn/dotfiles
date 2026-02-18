# ---- ghq helpers (zsh-native) ----

# Clone into ghq root, optionally auto-link unstable-studios, then cd into repo.
# usage:
#   gget org/repo
#   gget https://github.com/org/repo
#   gget git@github.com:org/repo.git
gget() {
  emulate -L zsh
  setopt errexit nounset pipefail
  setopt extendedglob

  command -v ghq >/dev/null 2>&1 || { print -u2 "ghq not installed"; return 1; }

  local src="${1:-}"
  [[ -n "$src" ]] || { print -u2 "usage: gget <org/repo | url | ssh>"; return 1; }

  # Always clone via ghq so it lands in GHQ_ROOT correctly.
  ghq get "$src"

  local host org repo
  host=""
  org=""
  repo=""

  # Parse inputs (zsh regex captures go into $match[])
  if [[ "$src" =~ '^git@([^:]+):([^/]+)/([^/]+)(\.git)?$' ]]; then
    host="${match[1]}"
    org="${match[2]}"
    repo="${match[3]}"
  elif [[ "$src" =~ '^https?://([^/]+)/([^/]+)/([^/]+)(\.git)?/?$' ]]; then
    host="${match[1]}"
    org="${match[2]}"
    repo="${match[3]}"
  elif [[ "$src" =~ '^([^/]+)/([^/]+)$' ]]; then
    host="github.com"
    org="${match[1]}"
    repo="${match[2]}"
  else
    # If we can't parse it, at least drop you into ghq root.
    cd "$(ghq root)"
    return 0
  fi

  # Auto-link if it's your main org on GitHub
  if [[ "$host" == "github.com" && "$org" == "unstable-studios" ]] && command -v link-unstable >/dev/null 2>&1; then
    link-unstable >/dev/null 2>&1 || true
  fi

  cd "$(ghq root)/$host/$org/$repo"
}

# Symlink all repos under github.com/unstable-studios into ~/src/
link-unstable() {
  emulate -L zsh
  setopt nounset pipefail

  local org="unstable-studios"
  local base="$HOME/src/github.com/$org"
  local dest="$HOME/src"

  [[ -d "$base" ]] || { print -u2 "missing: $base"; return 1; }

  local d name link
  for d in "$base"/*; do
    [[ -d "$d" ]] || continue
    name="${d:t}"
    link="$dest/$name"
    [[ -e "$link" ]] || ln -s "$d" "$link"
  done
}

# cd into any ghq repo using fzf
cproj() {
  emulate -L zsh
  setopt nounset pipefail

  command -v ghq >/dev/null 2>&1 || { print -u2 "ghq not installed"; return 1; }
  command -v fzf >/dev/null 2>&1 || { print -u2 "fzf not installed"; return 1; }

  cd "$(ghq list --full-path | fzf)" || return
}

corg() {
  emulate -L zsh
  setopt pipefail
  setopt extendedglob

  command -v ghq >/dev/null 2>&1 || { print -u2 "ghq not installed"; return 1; }
  command -v fzf >/dev/null 2>&1 || { print -u2 "fzf not installed"; return 1; }

  local org="${1:-unstable-studios}"
  local host="${2:-github.com}"
  local prefix="$host/$org/"
  local root
  root="$(ghq root)"

  # ----- build LOCAL list -----
  local -a local_items
  local_items=("${(@f)$(ghq list 2>/dev/null | grep -E "^${prefix}" 2>/dev/null)}")

  # ----- build REMOTE list (GitHub only) -----
  local -a remote_items
  remote_items=()
  if [[ "$host" == "github.com" ]] && command -v gh >/dev/null 2>&1; then
    remote_items=("${(@f)$(gh repo list "$org" --limit 500 --json nameWithOwner --jq '.[].nameWithOwner' 2>/dev/null)}")
  fi

  # ----- merge + dedupe (prefer LOCAL) -----
  local -A seen
  local -a combined
  combined=()

  local item key
  for item in "${local_items[@]}"; do
    seen["$item"]=1
    combined+=("LOCAL  $item")
  done

  for item in "${remote_items[@]}"; do
    key="github.com/$item"
    [[ -z "${seen[$key]:-}" ]] && combined+=("REMOTE $item")
  done

  (( ${#combined[@]} > 0 )) || { print -u2 "No repos found for $org on $host"; return 1; }

  # ----- create a robust preview script (no quote soup) -----
  local preview_script
  preview_script="$(mktemp -t corg-preview.XXXXXX)" || return 1

  cat > "$preview_script" <<'SH'
#!/bin/sh
# fzf passes the selected line as $1
line="$1"

label=$(printf "%s" "$line" | awk '{print $1}')
repo=$(printf "%s" "$line" | awk '{print $2}')

root=$(ghq root 2>/dev/null)

[ -n "$repo" ] || { echo "No selection"; exit 0; }

if [ "$label" = "LOCAL" ]; then
  path="$root/$repo"

  for f in README.md readme.md Readme.md README.MD README.markdown readme.markdown README.txt readme.txt; do
    if [ -f "$path/$f" ]; then
      if command -v glow >/dev/null 2>&1; then
        # Render markdown nicely in the preview pane.
        # Normalize CRLF to LF; glow is more reliable when fed via stdin.
        sed 's/\r$//' "$path/$f" | glow -s dark -w 80 -

        # Optional: show a quick preview of the first local image referenced in the markdown.
        # iTerm2 supports inline images via `imgcat`. VS Code's integrated terminal generally does not.
        img=$(grep -m1 -E '!\\[[^]]*\\]\\([^)]+\\)' "$path/$f" 2>/dev/null | \
          sed -E 's/.*!\\[[^]]*\\]\\(([^)]+)\\).*/\\1/' | \
          sed -E 's/["'"'"']//g')
        case "$img" in
          http*|"" ) : ;;
          * )
            imgpath="$path/$img"
            if [ -f "$imgpath" ]; then
              echo ""
              echo "[image preview: $img]"

              # Prefer iTerm2 inline images if available
              if command -v imgcat >/dev/null 2>&1; then
                imgcat "$imgpath" 2>/dev/null
              # Fallback: ANSI/ASCII preview that works anywhere
              elif command -v chafa >/dev/null 2>&1; then
                chafa -s 80x20 "$imgpath" 2>/dev/null
              else
                echo "(Install chafa for terminal previews)"
              fi
            fi
            ;;
        esac

      elif command -v bat >/dev/null 2>&1; then
        # Syntax-highlighted fallback
        bat --paging=never "$path/$f"
      else
        sed -n "1,200p" "$path/$f"
      fi
      exit 0
    fi
  done

  echo "No README found in:"
  echo "$path"
  echo ""
  ls -la "$path" 2>/dev/null | sed -n "1,120p"

else
  echo "Remote repo: $repo"
  echo ""
  if command -v gh >/dev/null 2>&1; then
    gh repo view "$repo" --json description,stargazerCount,forkCount \
      --jq "\"⭐ Stars: \(.stargazerCount)\n🍴 Forks: \(.forkCount)\n\n\(.description)\"" 2>/dev/null
  else
    echo "(Install gh for remote details)"
  fi
fi
SH

  chmod +x "$preview_script"

  # ----- run fzf with key capture -----
  local -a out
  out=("${(@f)$(
    printf "%s\n" "${combined[@]}" | fzf \
      --prompt="corg $org> " \
      --height=75% \
      --layout=reverse \
      --preview-window=right:60%:wrap \
      --expect=ctrl-o,ctrl-g,ctrl-d,ctrl-y \
      --header=$'ENTER: open   CTRL-O: browser   CTRL-G: clone   CTRL-D: delete   CTRL-Y: copy URL' \
      --preview="$preview_script {}"
  )}")

  # cleanup preview script
  rm -f "$preview_script"

  local keypress="${out[1]:-}"
  local selection="${out[2]:-}"
  [[ -n "$selection" ]] || return 0

  local label repo
  label="${selection%% *}"
  repo="${selection#* }"

  local path url
  if [[ "$label" == "LOCAL" ]]; then
    path="$root/$repo"
    url="https://$repo"
  else
    path="$root/github.com/$repo"
    url="https://github.com/$repo"
  fi

  case "$keypress" in
    ctrl-o)
      open "$url"
      ;;
    ctrl-y)
      echo -n "$url" | pbcopy
      print "Copied: $url"
      ;;
    ctrl-d)
      [[ "$label" == "LOCAL" ]] || { print -u2 "Not cloned"; return 1; }
      print -n "Delete $repo ? [y/N]: "
      local confirm
      read -r confirm
      if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        rm -rf "$path"
        print "Deleted $repo"
      else
        print "Canceled"
      fi
      ;;
    ctrl-g)
      [[ "$label" == "REMOTE" ]] || { print -u2 "Already cloned"; return 1; }
      if command -v gget >/dev/null 2>&1; then
        gget "$repo"
      else
        ghq get "$repo" && cd "$path"
      fi
      ;;
    *)
      # ENTER default
      if [[ "$label" == "LOCAL" ]]; then
        cd "$path"
      else
        if command -v gget >/dev/null 2>&1; then
          gget "$repo"
        else
          ghq get "$repo" && cd "$path"
        fi
      fi
      ;;
  esac
}

# ---- claude pipe-mode helpers ----

# Generate a commit message from staged changes
ai-commit() {
  emulate -L zsh
  if ! command -v claude >/dev/null 2>&1; then print -u2 "claude not installed"; return 1; fi
  local diff
  diff=$(git diff --cached)
  [[ -n "$diff" ]] || { print -u2 "Nothing staged. Use git add first."; return 1; }
  local msg
  msg=$(echo "$diff" | claude -p "Write a concise conventional commit message for these staged changes. Output ONLY the commit message, nothing else. Use the format: type(scope): description. Keep it under 72 chars.")
  print "$msg"
  print -n "\nCommit with this message? [y/N]: "
  local confirm
  read -r confirm
  if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    git commit -m "$msg"
  fi
}

# Review uncommitted changes
ai-review() {
  emulate -L zsh
  if ! command -v claude >/dev/null 2>&1; then print -u2 "claude not installed"; return 1; fi
  local diff
  diff=$(git diff)
  [[ -n "$diff" ]] || diff=$(git diff --cached)
  [[ -n "$diff" ]] || { print -u2 "No changes to review."; return 1; }
  echo "$diff" | claude -p "Review these code changes. Focus on bugs, security issues, and logic errors. Be concise. Skip style nitpicks."
}

# Explain a file or piped input
ai-explain() {
  emulate -L zsh
  if ! command -v claude >/dev/null 2>&1; then print -u2 "claude not installed"; return 1; fi
  if [[ -n "${1:-}" ]]; then
    claude -p "Explain what this code does. Be concise." < "$1"
  elif [[ ! -t 0 ]]; then
    claude -p "Explain what this code does. Be concise."
  else
    print -u2 "Usage: ai-explain <file> or pipe input"
    return 1
  fi
}

# Quick question from the terminal
ai() {
  emulate -L zsh
  if ! command -v claude >/dev/null 2>&1; then print -u2 "claude not installed"; return 1; fi
  [[ -n "${1:-}" ]] || { print -u2 "Usage: ai \"your question\""; return 1; }
  claude -p "$*"
}
