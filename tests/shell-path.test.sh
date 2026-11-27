#!/bin/bash
# dot_zshenv, dot_zprofile, env.zsh: every zsh (non-interactive `zsh -c` and `ssh host 'cmd'`,
# login, interactive) resolves node and pnpm to the mise shims and ghq to ~/.local/bin, ahead
# of anything else on PATH. run_once_after_mise-cleanup removes only what fnm and the old
# pnpm link left. Runs in a fake HOME with stub commands; nothing real is installed or read.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$2', want '$3'"; FAIL=1; fi; }

if ! command -v zsh >/dev/null 2>&1; then
  echo "skip shell-path tests: zsh is not installed"
  exit 0
fi

stub() { mkdir -p "${1%/*}"; printf '#!/bin/sh\n%s\n' "${2:-exit 0}" > "$1"; chmod +x "$1"; }

# ---- PATH from the dotfiles ----
H="$TMP/home"
SHIMS="$H/.local/share/mise/shims"
mkdir -p "$H/.config/shell"
cp "$ROOT/dot_zshenv" "$H/.zshenv"
cp "$ROOT/dot_zprofile" "$H/.zprofile"
cp "$ROOT/dot_zshrc" "$H/.zshrc"
cp "$ROOT/dot_config/shell/env.zsh" "$H/.config/shell/env.zsh"
stub "$SHIMS/node"; stub "$SHIMS/pnpm"
stub "$H/.local/bin/ghq"
stub "$H/.local/bin/pnpm"   # a stale link like the one fnm's Corepack left: the shim must win
# Interactive shells: mise activate (stub prints a marker) and brew (a fake prefix, so env.zsh
# never touches the real Homebrew).
stub "$H/.local/bin/mise" 'case "$1" in activate) echo "export MISE_ACTIVATED=1" ;; esac'
stub "$H/.local/bin/brew" "echo '$H/brew'"
stub "$TMP/sysbin/node"; stub "$TMP/sysbin/pnpm"   # a system Node (dnf, Homebrew) later on PATH

want="$SHIMS/node
$SHIMS/pnpm
$H/.local/bin/ghq"
# zsh <flags> <command>: a clean environment like sshd gives a command, nothing inherited.
z() { env -i HOME="$H" PATH="$TMP/sysbin:/usr/bin:/bin" TERM=dumb zsh "$@" 2>/dev/null; }

check "non-interactive zsh -c: node, pnpm from the mise shims, ghq from ~/.local/bin" \
  "$(z -c 'command -v node pnpm ghq')" "$want"
check "non-interactive zsh -c: GHQ_ROOT is ~/src" "$(z -c 'print -r -- $GHQ_ROOT')" "$H/src"
check "login zsh -lc (macOS path_helper runs in between): same" \
  "$(z -l -c 'command -v node pnpm ghq')" "$want"
check "interactive zsh -ic: same" \
  "$(z -i -c 'command -v node pnpm ghq' | tail -3)" "$want"
check "interactive zsh -ic: env.zsh runs mise activate" \
  "$(z -i -c 'print -r -- ${MISE_ACTIVATED:-no}' | tail -1)" 1
check "interactive zsh -ic: PNPM_HOME is not set" \
  "$(z -i -c 'print -r -- ${PNPM_HOME:-unset}' | tail -1)" unset
check "interactive zsh -ic: no fnm on PATH" "$(z -i -c 'whence fnm || echo none' | tail -1)" none

# ---- one-time cleanup ----
C="$TMP/cleanup"
mkdir -p "$C/.local/bin" "$C/.local/share/fnm/node-versions/v22.0.0/installation/lib/node_modules/corepack/dist" \
  "$C/.local/share/pnpm-standalone" "$C/.local/share/pnpm/store" "$C/elsewhere"
corepack="../share/fnm/node-versions/v22.0.0/installation/lib/node_modules/corepack/dist"
ln -s "$corepack/pnpm.js" "$C/.local/bin/pnpm"
ln -s "$corepack/pnpx.js" "$C/.local/bin/pnpx"
stub "$C/.local/bin/fnm"
stub "$C/.local/bin/ghq"
ln -s "$C/elsewhere/tool" "$C/.local/bin/tool"
script="$TMP/cleanup.sh"
chezmoi execute-template --source "$ROOT" < "$ROOT/run_once_after_mise-cleanup.sh.tmpl" > "$script"
env -i HOME="$C" PATH=/usr/bin:/bin /bin/bash "$script" >/dev/null
gone() { if [ -e "$1" ] || [ -L "$1" ]; then echo present; else echo gone; fi; }
check "cleanup: fnm's pnpm link removed" "$(gone "$C/.local/bin/pnpm")" gone
check "cleanup: fnm's pnpx link removed" "$(gone "$C/.local/bin/pnpx")" gone
check "cleanup: fnm removed" "$(gone "$C/.local/bin/fnm")" gone
check "cleanup: fnm's Node versions removed" "$(gone "$C/.local/share/fnm")" gone
check "cleanup: standalone pnpm removed" "$(gone "$C/.local/share/pnpm-standalone")" gone
check "cleanup: ghq kept" "$(gone "$C/.local/bin/ghq")" present
check "cleanup: other ~/.local/bin links kept" "$(gone "$C/.local/bin/tool")" present
check "cleanup: pnpm's package store kept" "$(gone "$C/.local/share/pnpm/store")" present

# A pnpm link the old dotfiles didn't make stays.
C2="$TMP/cleanup2"
mkdir -p "$C2/.local/bin"
ln -s /opt/other/pnpm "$C2/.local/bin/pnpm"
env -i HOME="$C2" PATH=/usr/bin:/bin /bin/bash "$script" >/dev/null
check "cleanup: unrelated pnpm link kept" "$(gone "$C2/.local/bin/pnpm")" present

exit "$FAIL"
