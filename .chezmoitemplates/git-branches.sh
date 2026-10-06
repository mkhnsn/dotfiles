# Shared branch helpers for git-sweep and empty-yard-debris.
# Usage (from a script template): template "git-branches.sh"
# Bash 3.2-compatible (stock macOS). Functions run in the current repo.

# Default branch name: origin/HEAD if set, else the first of main/master/trunk/develop that exists.
default_branch() {
  local b
  b=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null) && { echo "${b#origin/}"; return; }
  for b in main master trunk develop; do
    git show-ref --verify --quiet "refs/heads/$b" && { echo "$b"; return; }
  done
}

# Ref to compare against: origin/<default> when it exists (fresher), else the local branch.
base_ref() {
  local db="$1"
  if git show-ref --verify --quiet "refs/remotes/origin/$db"; then echo "origin/$db"; else echo "$db"; fi
}

# Local branches whose upstream was deleted on the remote ("[gone]"), one per line.
# Only as accurate as the last `git fetch --prune`.
gone_branches() {
  git for-each-ref --format='%(refname:short)%09%(upstream:track)' refs/heads/ 2>/dev/null \
    | awk -F'\t' '$2 == "[gone]" { print $1 }'
}

# How a branch relates to <base>: prints "merged", "squashed" or "unmerged".
#   merged   - its tip is already in base (a normal merge or fast-forward)
#   squashed - its combined changes already appear in base as one commit (squash merge)
#   unmerged - neither; deleting it would lose work
# The squash check builds a throwaway commit (never referenced, cleaned up by gc) and
# asks `git cherry` whether base already has an equivalent patch. If base has since
# changed the same lines, this reports "unmerged" -- it errs on the side of keeping.
branch_merge_state() {
  local b="$1" base="$2" mb tmp
  if git merge-base --is-ancestor "$b" "$base" 2>/dev/null; then echo merged; return; fi
  mb=$(git merge-base "$base" "$b" 2>/dev/null) || { echo unmerged; return; }
  tmp=$(GIT_AUTHOR_NAME=sweep GIT_AUTHOR_EMAIL=sweep@localhost \
        GIT_COMMITTER_NAME=sweep GIT_COMMITTER_EMAIL=sweep@localhost \
        git commit-tree --no-gpg-sign "$b^{tree}" -p "$mb" -m squash-check 2>/dev/null) \
    || { echo unmerged; return; }
  case "$(git cherry "$base" "$tmp" 2>/dev/null)" in
    -*) echo squashed ;;
    *)  echo unmerged ;;
  esac
}
