#!/bin/bash
# claude-sync import: a file that differs is saved as .imported.md, then .imported-2.md, and
# importing the same archive again adds nothing; a transcript that differs is left alone.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export CLAUDE_CONFIG_DIR="$T/here" CLAUDE_SYNC_DIR="$T/sync"
SYNC="$ROOT/dot_local/bin/executable_claude-sync"
M=projects/-p/memory
check() { # description, condition...
  local d="$1"; shift
  if "$@"; then echo "ok   $d"; else echo "FAIL $d"; FAIL=1; fi
}
archive() { # name, content of note.md
  mkdir -p "$T/src/$1/$M" "$CLAUDE_SYNC_DIR"
  printf '%s\n' "$2" > "$T/src/$1/$M/note.md"
  tar -czf "$CLAUDE_SYNC_DIR/$1.tar.gz" -C "$T/src/$1" projects
}
mkdir -p "$CLAUDE_CONFIG_DIR/$M"; echo local > "$CLAUDE_CONFIG_DIR/$M/note.md"
archive a first;  bash "$SYNC" import "$CLAUDE_SYNC_DIR/a.tar.gz" >/dev/null
archive b second; bash "$SYNC" import "$CLAUDE_SYNC_DIR/b.tar.gz" >/dev/null
bash "$SYNC" import "$CLAUDE_SYNC_DIR/b.tar.gz" >/dev/null
D="$CLAUDE_CONFIG_DIR/$M"
check "original kept"            grep -qx local "$D/note.md"
check "first import saved"       grep -qx first "$D/note.imported.md"
check "second import numbered"   grep -qx second "$D/note.imported-2.md"
check "re-import adds nothing"   test ! -e "$D/note.imported-3.md"
rm "$D/note.imported.md"; bash "$SYNC" import "$CLAUDE_SYNC_DIR/b.tar.gz" >/dev/null
check "re-import after a merge adds nothing" test ! -e "$D/note.imported.md"
# Transcripts (projects/<p>/<id>.jsonl) aren't merged: this Mac's copy stays, no copy is saved.
echo old > "$T/src/b/projects/-p/s.jsonl"; tar -czf "$CLAUDE_SYNC_DIR/c.tar.gz" -C "$T/src/b" projects
echo new > "$CLAUDE_CONFIG_DIR/projects/-p/s.jsonl"
bash "$SYNC" import "$CLAUDE_SYNC_DIR/c.tar.gz" >/dev/null
check "transcript kept"          grep -qx new "$CLAUDE_CONFIG_DIR/projects/-p/s.jsonl"
check "no transcript copy"       test -z "$(find "$CLAUDE_CONFIG_DIR/projects/-p" -maxdepth 1 -name '*imported*')"
exit "$FAIL"
