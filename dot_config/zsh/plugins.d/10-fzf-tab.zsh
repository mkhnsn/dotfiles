PLUGIN_DIR="$HOME/.config/zsh/plugins/fzf-tab"

if [[ -r "$PLUGIN_DIR/fzf-tab.plugin.zsh" ]]; then
  source "$PLUGIN_DIR/fzf-tab.plugin.zsh"
fi

# --- fzf-tab settings ---
# Don't reorder completion candidates (keeps things predictable)
zstyle ':fzf-tab:*' sort false

# Let you switch completion groups with , and .
zstyle ':fzf-tab:*' switch-group ',' '.'

# Previews for directories when completing `cd`
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -la $realpath'

# Preview files/directories for most completions
zstyle ':fzf-tab:complete:*:*' fzf-preview '
  if [[ -f $realpath ]]; then
    (bat --style=numbers --color=always --line-range :200 $realpath 2>/dev/null || sed -n "1,200p" $realpath)
  else
    ls -la $realpath
  fi
'