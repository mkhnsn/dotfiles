# Shared prelude for sudo-needing setup scripts that should run once.
# Usage (from a run_ script template): template "sudo-once.sh" "<name>"
#
# chezmoi marks run_once_ scripts done even when they bail out early, so a
# non-interactive apply that couldn't sudo would skip the work forever. These
# are plain run_ scripts that keep their own stamp instead: it holds a hash of
# the rendered script, is written only on a successful exit after sudo was
# acquired, and the script re-runs when its content changes.
# Defines $SUDO ("" when root, "sudo" otherwise).

{{ template "todo.sh" }}
STAMP_NAME={{ . | quote }}
STAMP_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
STAMP="$STAMP_DIR/$STAMP_NAME.done"
STAMP_HASH="$(sha256sum "$0" 2>/dev/null | cut -d' ' -f1 || true)"
STAMP_HASH="${STAMP_HASH:-$STAMP_NAME}"

if [[ "$(cat "$STAMP" 2>/dev/null)" == "$STAMP_HASH" ]]; then
  exit 0
fi

SUDO=""
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  if ! command -v sudo >/dev/null 2>&1; then
    echo "$STAMP_NAME: not root and sudo not available, skipping"
    todo "$STAMP_NAME: skipped (no sudo available)"
    exit 0
  fi
  SUDO="sudo"
  if ! sudo -n true 2>/dev/null; then
    if [[ -t 0 ]]; then
      echo "$STAMP_NAME: sudo needed"
      if ! sudo -v; then
        echo "$STAMP_NAME: no sudo; will retry on next 'chezmoi apply'"
        todo "$STAMP_NAME: skipped (sudo failed); re-run 'chezmoi apply'"
        exit 0
      fi
    else
      echo "$STAMP_NAME: sudo requires a password and no TTY; will retry on next 'chezmoi apply'"
      todo "$STAMP_NAME: skipped (sudo needs a password); run 'chezmoi apply' from a terminal"
      exit 0
    fi
  fi
fi

# From here on, a clean exit (including an early `exit 0`) records the stamp;
# a failure leaves it unset so the next apply retries. A step that failed
# without aborting the script can set RETRY_NEXT_APPLY=1 to skip the stamp too.
RETRY_NEXT_APPLY=""
trap 'rc=$?; if [[ $rc -eq 0 && -z "$RETRY_NEXT_APPLY" ]]; then mkdir -p "$STAMP_DIR" && printf "%s\n" "$STAMP_HASH" > "$STAMP"; fi' EXIT
