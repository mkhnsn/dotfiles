# Windows/Git Bash specific environment settings (managed by chezmoi)
# This file is sourced by env.zsh when running on Windows/MSYS

# ---- Windows-specific PATH additions ----
# Git Bash uses Unix-style paths (/c/Users/...), but some tools need Windows paths

# Ensure Windows binaries are accessible
# Git Bash usually handles this, but we can add common locations if needed
if [[ -d "/c/Program Files/PowerShell/7" ]]; then
  export PATH="/c/Program Files/PowerShell/7:$PATH"
fi

# ---- Windows pnpm home ----
# On Windows, pnpm uses a different default location
export PNPM_HOME="$HOME/AppData/Local/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# ---- Handle missing tools gracefully ----
# Homebrew doesn't exist on Windows, so we need to skip brew-dependent logic

# Override the fpath_prepend calls for brew if it doesn't exist
# (env.zsh already checks for brew, but we're being extra cautious)

# ---- Windows Terminal specific settings ----
# Windows Terminal handles some things differently

# Disable SSH agent override since 1Password SSH on Windows uses different paths
# (env.zsh already checks for macOS specifically, so this is just a note)

# ---- Git Bash specific fixes ----
# Git Bash has some quirks with certain tools

# ---- Optional: Windows-specific aliases ----
# Add any Windows-specific aliases here if needed
# alias open='start'  # Use 'start' to open files in default apps
