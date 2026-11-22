#!/bin/bash
# Tests for cf-mcp-headers, against a stub `security` (no Keychain needed).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../dot_local/bin/executable_cf-mcp-headers"
PASS=0 FAIL=0
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin"
stub() { printf '#!/bin/sh\n%s\n' "$2" > "$T/bin/$1"; chmod +x "$T/bin/$1"; }
check() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); printf 'FAIL %s\n  want: %s\n  got:  %s\n' "$1" "$3" "$2"; fi; }
run() { OUT="$(PATH="$T/bin:/usr/bin:/bin" sh "$SCRIPT" "$@" 2>&1)"; RC=$?; }

stub security 'echo abc_DEF-123'
run; check "prints the header as JSON" "$RC $OUT" '0 {"Authorization": "Bearer abc_DEF-123"}'

stub security 'exit 44'
run; check "no token: exit 1" "$RC" 1
case "$OUT" in *"--store-token"*) PASS=$((PASS+1)) ;; *) FAIL=$((FAIL+1)); echo "FAIL no token: says how to store it: $OUT" ;; esac

stub security 'echo "abc\"}, \"x\": \"y"'
run; check "token that would break the JSON: exit 1" "$RC" 1

run --bogus; check "unknown argument: exit 2" "$RC" 2

stub op 'echo "bad token!"'
run --store-token; check "--store-token rejects an odd token" "$RC" 1

echo "cf-mcp-headers: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
