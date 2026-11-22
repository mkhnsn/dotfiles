#!/bin/bash
# .chezmoiignore.tmpl: files read from 1Password are skipped when secrets can't be read.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0
# SSH=1 in the environment of a call simulates an SSH session.
render() { env -u OP_SERVICE_ACCOUNT_TOKEN -u SSH_CONNECTION ${SSH:+SSH_CONNECTION=x} chezmoi execute-template --source "$ROOT" --override-data "$1" < "$ROOT/.chezmoiignore.tmpl"; }
expect() { # data, path, want (ignored|kept)
  local got=kept
  render "$1" | grep -qxF "$2" && got=ignored
  if [ "$got" = "$3" ]; then echo "ok   $2 $3 with $1"; else echo "FAIL $2: $got, want $3, with $1"; FAIL=1; fi
}
expect '{"full_setup":false,"op_mode":"account"}' .ssh/authorized_keys ignored
expect '{"full_setup":true,"op_mode":"account"}'  .ssh/authorized_keys kept
expect '{"full_setup":true,"op_mode":"service"}'  .ssh/authorized_keys ignored   # no token in the env
expect '{"full_setup":false,"op_mode":"account"}' .ntfy.yml ignored
SSH=1 expect '{"full_setup":true,"op_mode":"account"}' .ssh/authorized_keys ignored   # desktop app unreachable
exit "$FAIL"
