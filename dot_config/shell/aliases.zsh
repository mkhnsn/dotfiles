# Aliases (managed by chezmoi)

if command -v eza >/dev/null 2>&1; then
  alias ll='eza -alF --group-directories-first'
  alias la='eza -A'
  alias l='eza'
else
  alias ll='ls -alF'
  alias la='ls -A'
  alias l='ls -CF'
fi