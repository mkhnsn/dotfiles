#!/bin/bash
# run_05-op-service-token.sh.tmpl: service-account boxes save the 1Password token, on any OS.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
render() { chezmoi execute-template --source "$ROOT" --override-data "$1" < "$ROOT/run_05-op-service-token.sh.tmpl"; }
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$2', want '$3'"; FAIL=1; fi; }
mode() { if [ "$(uname -s)" = Darwin ]; then stat -f %Lp "$1"; else stat -c %a "$1"; fi; }
# run <home> <token or ""> <data>: run the rendered script with that HOME and token.
run() {
  local home="$1" token="$2" script="$TMP/script.sh"
  render "$3" > "$script"
  [ -s "$script" ] || return 0   # chezmoi skips a script that renders empty
  env -u OP_SERVICE_ACCOUNT_TOKEN ${token:+OP_SERVICE_ACCOUNT_TOKEN="$token"} HOME="$home" /bin/bash "$script" >/dev/null
}
FILE=.config/op/service-account.env

for os in darwin linux; do
  data="{\"chezmoi\":{\"os\":\"$os\"},\"full_setup\":true,\"op_mode\":\"service\"}"
  h="$TMP/$os"; mkdir -p "$h"
  run "$h" 'ops_test value' "$data"
  check "$os: token saved" "$(env -u OP_SERVICE_ACCOUNT_TOKEN /bin/bash -c ". '$h/$FILE' && printf %s \"\$OP_SERVICE_ACCOUNT_TOKEN\"" 2>/dev/null)" 'ops_test value'
  check "$os: file is 0600" "$(mode "$h/$FILE" 2>/dev/null)" 600
  check "$os: directory is 0700" "$(mode "$h/.config/op" 2>/dev/null)" 700
  run "$h" ops_other "$data"
  check "$os: existing file kept" "$(grep -c ops_other "$h/$FILE")" 0
done

h="$TMP/notoken"; mkdir -p "$h"
run "$h" '' '{"full_setup":true,"op_mode":"service"}'
check "no token in the environment: nothing written" "$([ -e "$h/$FILE" ] && echo written || echo none)" none

for data in '{"full_setup":true,"op_mode":"account"}' '{"full_setup":false,"op_mode":"service"}' '{"full_setup":true}'; do
  check "renders empty with $data" "$(render "$data" | tr -d '[:space:]')" ''
done
exit "$FAIL"
