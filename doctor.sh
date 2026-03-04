#!/usr/bin/env bash
set -euo pipefail

# Minimal diagnostics for this dotfiles/chezmoi setup.
# Safe to run anywhere; should never fail hard just because something is missing.

ok()   { printf "✅ %s\n" "$*"; }
warn() { printf "⚠️  %s\n" "$*"; }
info() { printf "ℹ️  %s\n" "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

hr() { printf "\n--- %s ---\n" "$*"; }

hr "Core binaries"
if have chezmoi; then ok "chezmoi: $(chezmoi --version)"; else warn "chezmoi: MISSING"; fi
if have zsh; then ok "zsh:    $(zsh --version)"; else warn "zsh:    MISSING"; fi
if have git; then ok "git:    $(git --version)"; else warn "git:    MISSING"; fi
if have gh; then ok "gh:     $(gh --version | head -n 1)"; else warn "gh:     MISSING"; fi
if have op; then ok "op:     $(op --version 2>/dev/null || true)"; else info "op:     not installed (fine unless you use op:// secrets)"; fi

hr "Node toolchain"
if have node; then
  if node_ver=$(node -v 2>&1); then
    ok "node:   $node_ver"
  else
    warn "node:   BROKEN — $(echo "$node_ver" | head -1)"
    warn "        likely a Homebrew dylib mismatch; try: brew reinstall node"
  fi
else
  warn "node:   MISSING"
fi

if have pnpm; then
  if pnpm_ver=$(pnpm -v 2>&1); then
    ok "pnpm:   $pnpm_ver"
  else
    warn "pnpm:   BROKEN — $(echo "$pnpm_ver" | head -1)"
    warn "        likely a Homebrew dylib mismatch; try: brew reinstall node"
  fi
else
  warn "pnpm:   MISSING"
fi

if have corepack; then
  ok "corepack: $(corepack --version)"
else
  warn "corepack: MISSING"
fi

# pnpm globals sanity (this is what bit you)
info "PNPM_HOME:   ${PNPM_HOME:-<unset>}"
if have pnpm; then
  # Where pnpm thinks global binaries should go
  info "pnpm global-bin-dir: $(pnpm config get global-bin-dir 2>/dev/null || echo unknown)"
fi

if [[ -n "${PNPM_HOME:-}" ]]; then
  case ":$PATH:" in
    *":$PNPM_HOME:"*) ok "PNPM_HOME is on PATH" ;;
    *) warn "PNPM_HOME is NOT on PATH" ;;
  esac
fi

hr "Useful paths"
info "HOME:        ${HOME}"
info "XDG_CACHE:   ${XDG_CACHE_HOME:-$HOME/.cache}"
info "ZDOTDIR:     ${ZDOTDIR:-$HOME}"

# Where we expect zsh compdump
ZSH_COMPDUMP_DEFAULT="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
info "compdump:    ${ZSH_COMPDUMP_DEFAULT}"
[[ -r "$ZSH_COMPDUMP_DEFAULT" ]] && ok "compdump exists" || info "compdump missing (will be created on next compinit)"

hr "zsh plugins present"
PLUGDIR="$HOME/.config/zsh/plugins"
if [[ -d "$PLUGDIR" ]]; then
  ls -1 "$PLUGDIR" | sed 's/^/ - /'
else
  warn "No plugin dir at $PLUGDIR"
fi

hr "zsh completion wiring"
# Run a login interactive zsh so it loads your dotfiles, then inspect state.
# If zsh isn't installed, skip.
if have zsh; then
  zsh -lic '
    set -e
    echo "fpath (first 10):"
    print -l $fpath | head -n 10 | sed "s/^/ - /"

    echo ""
    echo "Completion mappings (_comps):"
    echo " - npm  -> ${_comps[npm]-<none>}"
    echo " - pnpm -> ${_comps[pnpm]-<none>}"
    echo " - gh   -> ${_comps[gh]-<none>}"
    echo " - git  -> ${_comps[git]-<none>}"

    echo ""
    echo "Autoload checks (whence -v):"
    whence -v _npm 2>/dev/null || echo "_npm not found"
    whence -v _pnpm 2>/dev/null || echo "_pnpm not found"
    whence -v _gh 2>/dev/null || echo "_gh not found"
    whence -v _git 2>/dev/null || echo "_git not found"

    echo ""
    echo "Managed completion files (if present):"
    for f in "$HOME/.config/zsh/completions/_npm" "$HOME/.config/zsh/completions/_pnpm" "$HOME/.config/zsh/completions/_gh"; do
      [[ -r "$f" ]] && echo " - $f" || true
    done
  ' 2>/dev/null || warn "zsh completion check failed (non-fatal)"
else
  warn "Skipping zsh completion wiring (zsh not installed)"
fi

hr "Homebrew linkage (macOS only)"
if have brew; then
  # Quick check: try a few key binaries for dylib load errors
  broken=()
  for bin in node ruby python3; do
    if have "$bin"; then
      if ! "$bin" --version >/dev/null 2>&1; then
        broken+=("$bin")
      fi
    fi
  done
  if (( ${#broken[@]} > 0 )); then
    warn "Broken binaries detected: ${broken[*]}"
    warn "Likely cause: brew upgraded a dependency without relinking dependents"
    warn "Fix: brew reinstall ${broken[*]}"
  else
    ok "Key binaries load OK"
  fi
else
  info "brew not installed — skipping linkage check"
fi

hr "Git config signing sanity"
if have git; then
  # Only show relevant config, and redact obvious key material.
  git config --list --show-origin \
    | grep -Ei 'signing|gpg|ssh|allowed|credential|gh' \
    | sed -E 's/(ssh-(ed25519|rsa) )[^ ]+/\1<redacted>/' \
    || true
fi

hr "GitHub auth quick check"
if have gh; then
  # This prints status without dumping tokens.
  gh auth status -h github.com 2>/dev/null || info "gh auth status unavailable (not logged in?)"
fi

hr "Done"
ok "doctor.sh completed"