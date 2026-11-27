#!/bin/bash
# dot_zshenv, dot_zprofile, env.zsh: every zsh (non-interactive `zsh -c` and `ssh host 'cmd'`,
# login, interactive) resolves node and pnpm to the mise shims and ghq to ~/.local/bin, ahead
# of anything else on PATH. run_after_mise-2-cleanup removes only what fnm and the old pnpm
# link left, and only once mise works. Runs in a fake HOME with stub commands and writes
# nothing outside it. On macOS the login and interactive shells still run the real
# `brew shellenv` (dot_zprofile) and whatever env.zsh finds in /opt/homebrew/bin (starship,
# ntfy), read-only; Linux CI has no path_helper, so the login case matters most on a Mac.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$2', want '$3'"; FAIL=1; fi; }

for tool in zsh chezmoi; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "skip shell-path tests: $tool is not installed"
    exit 0
  fi
done

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
stub "$TMP/sysbin/fnm" 'echo "export FNM_HOOKED=1"'  # an fnm still installed: env.zsh mustn't hook it

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
check "interactive zsh -ic: env.zsh doesn't run fnm env" \
  "$(z -i -c 'print -r -- ${FNM_HOOKED:-no}' | tail -1)" no

# ---- one-time cleanup ----
SCRIPT="$TMP/cleanup.sh"
chezmoi execute-template --source "$ROOT" < "$ROOT/run_after_mise-2-cleanup.sh.tmpl" > "$SCRIPT"
gone() { if [ -e "$1" ] || [ -L "$1" ]; then echo present; else echo gone; fi; }
cleanup() { env -i HOME="$1" PATH=/usr/bin:/bin /bin/bash "$SCRIPT" >/dev/null; }
todos() { cat "$1/.local/state/dotfiles/todo" 2>/dev/null; }
# old_setup <home>: what the fnm setup left (as on echo-turbine), plus things that must stay.
old_setup() {
  local h="$1" nv="$1/.local/share/fnm/node-versions/v22.0.0/installation/lib/node_modules"
  mkdir -p "$h/.local/bin" "$nv/corepack/dist" "$nv/npm" "$nv/wrangler" "$nv/@scope/cli" \
    "$h/.local/share/pnpm-standalone" "$h/.local/share/pnpm/store" "$h/elsewhere"
  ln -s ../share/fnm/node-versions/v22.0.0/installation/lib/node_modules/corepack/dist/pnpm.js "$h/.local/bin/pnpm"
  ln -s ../share/fnm/node-versions/v22.0.0/installation/lib/node_modules/corepack/dist/pnpx.js "$h/.local/bin/pnpx"
  stub "$h/.local/bin/fnm"
  stub "$h/.local/bin/ghq"
  ln -s "$h/elsewhere/tool" "$h/.local/bin/tool"
}

# mise isn't working yet (download failed): nothing is removed, and it tries again next apply.
C="$TMP/cleanup"
old_setup "$C"
cleanup "$C"
check "cleanup without mise: fnm kept" "$(gone "$C/.local/bin/fnm")" present
check "cleanup without mise: pnpm link kept" "$(gone "$C/.local/bin/pnpm")" present
check "cleanup without mise: says why" "$(todos "$C" | grep -c 'fnm and the old pnpm link stay')" 1
stub "$C/.local/bin/mise" 'case "$1" in which) exit 1 ;; esac'
cleanup "$C"
check "cleanup before mise install works: fnm's Node kept" "$(gone "$C/.local/share/fnm")" present

# mise serves node and pnpm: the old setup goes.
stub "$C/.local/bin/mise" 'exit 0'
rm -f "$C/.local/state/dotfiles/todo"
cleanup "$C"
check "cleanup: fnm's pnpm link removed" "$(gone "$C/.local/bin/pnpm")" gone
check "cleanup: fnm's pnpx link removed" "$(gone "$C/.local/bin/pnpx")" gone
check "cleanup: fnm removed" "$(gone "$C/.local/bin/fnm")" gone
check "cleanup: fnm's Node versions removed" "$(gone "$C/.local/share/fnm")" gone
check "cleanup: standalone pnpm removed" "$(gone "$C/.local/share/pnpm-standalone")" gone
check "cleanup: npm globals under fnm listed" \
  "$(todos "$C" | grep -o 'are gone ([^)]*)')" "are gone (@scope/cli wrangler )"
check "cleanup: ghq kept" "$(gone "$C/.local/bin/ghq")" present
check "cleanup: other ~/.local/bin links kept" "$(gone "$C/.local/bin/tool")" present
check "cleanup: mise kept" "$(gone "$C/.local/bin/mise")" present
check "cleanup: pnpm's package store kept" "$(gone "$C/.local/share/pnpm/store")" present

# Once done, it doesn't run again (the marker), even if something matching comes back.
stub "$C/.local/bin/fnm"
cleanup "$C"
check "cleanup: runs once" "$(gone "$C/.local/bin/fnm")" present

# A pnpm link the old dotfiles didn't make stays.
C2="$TMP/cleanup2"
mkdir -p "$C2/.local/bin"
stub "$C2/.local/bin/mise" 'exit 0'
ln -s /opt/other/pnpm "$C2/.local/bin/pnpm"
cleanup "$C2"
check "cleanup: unrelated pnpm link kept" "$(gone "$C2/.local/bin/pnpm")" present

exit "$FAIL"
