#!/bin/bash
# Render templated scripts into tests/.build with fixed test data, for tests and shellcheck.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/tests/.build"
mkdir -p "$OUT"
render() { chezmoi execute-template --source "$ROOT" --override-data "$2" < "$ROOT/$1"; }
render dot_local/bin/executable_mac-setup.tmpl '{"hostname":"Test-Mac","is_server":false}' > "$OUT/mac-setup"
render dot_local/bin/executable_mac-setup.tmpl '{"hostname":"Test-Mac","is_server":true}'  > "$OUT/mac-setup-server"
echo "rendered into $OUT"
