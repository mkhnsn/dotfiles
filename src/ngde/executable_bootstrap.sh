#!/usr/bin/env bash
# Clone the NGDE repos into this directory and recreate the iac-pl3 worktree.
# Safe to re-run: existing checkouts are left alone.
set -euo pipefail

cd "$(dirname "$0")"
BASE=https://www.trmc.osd.mil/bitbucket/scm/aftc_cdss

repos=(arbiter arbiter-ui ctdss-api ctdss-ui iac nas-airflow pipeline-shared-lib)

for r in "${repos[@]}"; do
  if [[ -d $r/.git ]]; then
    echo "ok    $r"
  else
    echo "clone $r"
    git clone --recurse-submodules "$BASE/$r.git" "$r"
  fi
done

# Second checkout of iac for PL3 work, sharing iac's object store.
if [[ -e iac-pl3/.git ]]; then
  echo "ok    iac-pl3"
else
  echo "add   iac-pl3 (worktree of iac, detached at origin/Dev)"
  git -C iac fetch origin
  git -C iac worktree add --detach ../iac-pl3 origin/Dev
fi

# scan-triage is local working notes, not a repo
mkdir -p scan-triage
