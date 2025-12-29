#!/usr/bin/env bash
set -euo pipefail

echo "chezmoi: $(chezmoi --version 2>/dev/null || echo MISSING)"
echo "zsh:    $(zsh --version 2>/dev/null || echo MISSING)"

echo "--- plugins present ---"
ls -1 "$HOME/.config/zsh/plugins" 2>/dev/null || true

echo "--- completion mappings (zsh) ---"
zsh -lic 'echo "npm -> ${_comps[npm]-<none>}"; echo "pnpm -> ${_comps[pnpm]-<none>}"' 2>/dev/null || true