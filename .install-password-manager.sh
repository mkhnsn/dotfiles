#!/usr/bin/env bash
# Install the 1Password CLI before chezmoi reads the source state.
#
# chezmoi renders every template (private_dot_ntfy.yml.tmpl calls onepasswordRead)
# before it runs any run_ script, so a run_ script can't install `op` in time.
# .chezmoi.toml.tmpl wires this in as hooks.read-source-state.pre on full_setup
# machines. It runs before every chezmoi command, so it exits at once when `op`
# is already there. The leading dot keeps chezmoi from deploying it.
set -euo pipefail

command -v op >/dev/null 2>&1 && exit 0

log() { printf '[1password] %s\n' "$*" >&2; }

case "$(uname -s)" in
  Darwin)
    for brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
      [[ -x "$brew" ]] && eval "$("$brew" shellenv)" && break
    done
    if ! command -v brew >/dev/null 2>&1; then
      log "Homebrew isn't installed. Run install.sh, or install Homebrew, then run chezmoi again."
      exit 1
    fi
    log "Installing 1Password and its CLI"
    brew install --cask 1password 1password-cli

    # Service-account mode reads a token; there's no app to sign in to.
    [[ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]] && exit 0

    open -a 1Password || true
    log "Sign in to 1Password, then turn on Settings > Developer > Integrate with 1Password CLI."
    # Wait for the app integration so the templates can read secrets in this run.
    while ! op account list 2>/dev/null | grep -q .; do
      if [[ -r /dev/tty ]]; then
        read -r -p "[1password] Press Enter when done, or type s to skip: " answer </dev/tty || answer=s
        [[ "$answer" == "s" ]] && { log "Skipped. Templates that read secrets will fail until the CLI integration is on."; exit 0; }
      else
        log "No terminal to wait on. Turn on the CLI integration, then run chezmoi apply."
        exit 0
      fi
    done
    log "1Password CLI is connected"
    ;;
  *)
    # Linux installs `op` in run_once_05-1password, which runs after templates.
    # On a fresh full-setup box, install 1password-cli first (or set
    # OP_SERVICE_ACCOUNT_TOKEN and run install.sh), then run chezmoi again.
    log "1Password CLI not found. Install 1password-cli before templates can read secrets."
    ;;
esac
