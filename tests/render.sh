#!/bin/bash
# Render templated scripts into tests/.build with fixed test data, for tests and shellcheck.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/tests/.build"
mkdir -p "$OUT"
# --override-data merges with this machine's own chezmoi data, so every key the script
# reads is set here.
render() { chezmoi execute-template --source "$ROOT" --override-data "$2" < "$ROOT/$1"; }
render dot_local/bin/executable_mac-setup.tmpl '{"hostname":"Test-Mac","is_server":false,"op_mode":"account"}' > "$OUT/mac-setup"
render dot_local/bin/executable_mac-setup.tmpl '{"hostname":"Test-Mac","is_server":true,"op_mode":"account"}'  > "$OUT/mac-setup-server"
echo "rendered into $OUT"
