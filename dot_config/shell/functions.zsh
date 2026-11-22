# ---- portable clipboard / opener ----
if [[ "${OSTYPE:-}" == darwin* ]]; then
  alias clip='pbcopy'
  # open is native on macOS
elif command -v wl-copy >/dev/null 2>&1; then
  alias clip='wl-copy'
  alias open='xdg-open'
elif command -v xclip >/dev/null 2>&1; then
  alias clip='xclip -selection clipboard'
  alias open='xdg-open'
fi

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

# Every GitHub repo you can see under your account and your organizations (not archived),
# as github.com/owner/name lines. Cached for cproj; refreshed in the background once a day.
CPROJ_REMOTE="${XDG_CACHE_HOME:-$HOME/.cache}/cproj/remote"
cproj-refresh() {
  emulate -L zsh
  setopt nounset pipefail
  command -v gh >/dev/null 2>&1 || { print -u2 "gh not installed"; return 1; }
  local me o tmp
  local -a owners
  me="$(gh api user --jq .login)" || return 1
  # Orgs need the read:org scope; without it, list your own repos only.
  owners=($me ${(f)"$(gh api user/orgs --paginate --jq '.[].login' 2>/dev/null)"})
  mkdir -p "${CPROJ_REMOTE:h}"
  tmp="$(mktemp "$CPROJ_REMOTE.XXXXXX")" || return 1
  for o in $owners; do
    gh repo list "$o" --limit 5000 --no-archived --json nameWithOwner --jq '.[].nameWithOwner' || exit 1
  done | sed 's|^|github.com/|' | sort -u > "$tmp" && mv "$tmp" "$CPROJ_REMOTE" || { rm -f "$tmp"; return 1; }
}

# cd into any repo with fzf: cloned ones, plus repos on GitHub you haven't cloned yet
# (marked "clone"), which are cloned with ghq first. `cproj-refresh` updates that list now.
cproj() {
  emulate -L zsh
  setopt nounset pipefail

  command -v ghq >/dev/null 2>&1 || { print -u2 "ghq not installed"; return 1; }
  command -v fzf >/dev/null 2>&1 || { print -u2 "fzf not installed"; return 1; }

  # First use: list in the foreground. A failure still leaves an (empty) cache, so it's
  # retried in a day, not on every call. Later: refresh in the background once a day,
  # touching the cache first so repeated calls don't start more refreshes.
  if [[ ! -e "$CPROJ_REMOTE" ]]; then
    print -u2 "Listing your GitHub repos (once; then daily in the background)..."
    cproj-refresh || { print -u2 "Couldn't list GitHub repos (cproj-refresh to retry); showing cloned ones only."
                       mkdir -p "${CPROJ_REMOTE:h}"; touch "$CPROJ_REMOTE"; }
  elif [[ -n "$(find "$CPROJ_REMOTE" -mmin +1440 2>/dev/null)" ]]; then
    touch "$CPROJ_REMOTE"
    ( cproj-refresh >/dev/null 2>&1 & )
  fi

  # host/owner/name only: ghq also lists the top-level links that link-unstable makes.
  local -a cloned remote
  cloned=(${(M)${(f)"$(ghq list)"}:#*/*/*})
  [[ -s "$CPROJ_REMOTE" ]] && remote=(${(f)"$(<"$CPROJ_REMOTE")"})
  # Drop the ones already cloned, ignoring case (GitHub names aren't case-sensitive).
  local -A have
  local r
  for r in $cloned; do have[${(L)r}]=1; done
  remote=(${remote:#(${(j:|:)${(@kq)have}})})
  local -a fresh
  for r in $remote; do (( ${+have[${(L)r}]} )) || fresh+=("$r"); done

  local pick
  pick="$(print -rl -- $cloned ${^fresh}$'\tclone' | fzf --prompt='repo> ' --delimiter=$'\t' --nth=1)" || return
  [[ -n "$pick" ]] || return 0
  if [[ "$pick" == *$'\t'clone ]]; then
    gget "${${pick%$'\t'clone}#github.com/}"
  else
    cd "$(ghq root)/$pick"
  fi
}

corg() {
  setopt local_options pipefail extendedglob

  command -v ghq >/dev/null 2>&1 || { print -u2 "ghq not installed"; return 1; }
  command -v fzf >/dev/null 2>&1 || { print -u2 "fzf not installed"; return 1; }

  local org="${1:-unstable-studios}"
  local host="${2:-github.com}"
  local prefix="$host/$org/"
  local root
  root="$(ghq root)"

  # ----- build LOCAL list -----
  local -a items
  items=("${(@f)$(ghq list 2>/dev/null | grep -E "^${prefix}" 2>/dev/null)}")

  (( ${#items[@]} > 0 )) || { print -u2 "No local repos found for $org on $host"; return 1; }

  # ----- create preview script -----
  local preview_script
  preview_script="$(mktemp -t corg-preview.XXXXXX)" || return 1

  cat > "$preview_script" <<'SH'
#!/bin/sh
repo="$1"
root=$(ghq root 2>/dev/null)
path="$root/$repo"

[ -d "$path" ] || { echo "Not found: $path"; exit 0; }

for f in README.md readme.md Readme.md README.MD README.markdown readme.markdown README.txt readme.txt; do
  if [ -f "$path/$f" ]; then
    if command -v glow >/dev/null 2>&1; then
      sed 's/\r$//' "$path/$f" | glow -s dark -w 80 -
    elif command -v bat >/dev/null 2>&1; then
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
SH

  chmod +x "$preview_script"

  # ----- run fzf -----
  local selection
  selection="$(printf "%s\n" "${items[@]}" | fzf \
    --prompt="corg $org> " \
    --height=75% \
    --layout=reverse \
    --preview-window=right:60%:wrap \
    --header=$'ENTER: open   CTRL-O: browser   CTRL-D: delete   CTRL-Y: copy URL' \
    --expect=ctrl-o,ctrl-d,ctrl-y \
    --preview="$preview_script {}"
  )"

  rm -f "$preview_script"

  # Parse keypress (first line) and selection (second line)
  local keypress="${${(@f)selection}[1]}"
  local repo="${${(@f)selection}[2]}"
  [[ -n "$repo" ]] || return 0

  local path="$root/$repo"
  local url="https://$repo"

  case "$keypress" in
    ctrl-o)
      open "$url"
      ;;
    ctrl-y)
      echo -n "$url" | clip
      print "Copied: $url"
      ;;
    ctrl-d)
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
    *)
      cd "$path"
      ;;
  esac
}

# ---- yazi (TUI file manager) ----

# Wrapper: quit yazi and cd to the directory you were in
y() {
  local tmp cwd
  tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
  command yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd < "$tmp"
  [[ "$cwd" != "$PWD" ]] && [[ -d "$cwd" ]] && builtin cd -- "$cwd"
  rm -f -- "$tmp"
}

# ---- git worktree helpers ----

# Create a worktree as a sibling directory: repo@branch
# usage:
#   gwt feature-branch          — checkout existing branch in a new worktree
#   gwt -b new-branch           — create new branch + worktree
#   gwt -b new-branch origin/main — create new branch from base + worktree
gwt() {
  emulate -L zsh
  setopt errexit nounset pipefail

  if [[ -z "${1:-}" ]]; then
    print -u2 "usage: gwt [-b] <branch> [<base>]"
    return 1
  fi

  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    print -u2 "Not in a git repository"
    return 1
  }

  local repo_name="${repo_root:t}"
  local parent="${repo_root:h}"

  if [[ "$1" == "-b" ]]; then
    local branch="${2:?branch name required}"
    local base="${3:-}"
    local wt_dir="$parent/${repo_name}@${branch}"
    if [[ -n "$base" ]]; then
      git worktree add -b "$branch" "$wt_dir" "$base"
    else
      git worktree add -b "$branch" "$wt_dir"
    fi
  else
    local branch="$1"
    local wt_dir="$parent/${repo_name}@${branch}"
    git worktree add "$wt_dir" "$branch"
  fi

  cd "$wt_dir"
}

# List worktrees with short paths
gwl() {
  emulate -L zsh
  git worktree list
}

# Remove a worktree by branch name (from within any worktree of the same repo)
gwr() {
  emulate -L zsh
  setopt errexit nounset pipefail

  if [[ -z "${1:-}" ]]; then
    print -u2 "usage: gwr <branch>"
    return 1
  fi

  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    print -u2 "Not in a git repository"
    return 1
  }

  # If we're in a worktree, find the main repo root
  local main_root
  main_root="$(git -C "$repo_root" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
  main_root="${main_root%/.git}"

  local repo_name="${main_root:t}"
  local parent="${main_root:h}"
  local wt_dir="$parent/${repo_name}@${1}"

  if [[ ! -d "$wt_dir" ]]; then
    print -u2 "Worktree not found: $wt_dir"
    return 1
  fi

  # If we're inside the worktree being removed, cd out first
  if [[ "$(pwd)" == "$wt_dir"* ]]; then
    cd "$main_root"
  fi

  git worktree remove "$wt_dir"
}

# ---- help viewer (bat-powered) ----

# Pretty-print --help output through bat
help() {
  "$@" --help 2>&1 | bat --language=help --style=plain
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
