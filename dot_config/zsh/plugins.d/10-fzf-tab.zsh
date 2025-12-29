PLUGIN_DIR="$HOME/.config/zsh/plugins/fzf-tab"

# fzf-tab needs to be sourced after compinit (you load plugins after compinit, so we're good)
if [[ -r "$PLUGIN_DIR/fzf-tab.plugin.zsh" ]]; then
  source "$PLUGIN_DIR/fzf-tab.plugin.zsh"
fi

# Optional: behavior tweaks
zstyle ':fzf-tab:*' sort false
zstyle ':fzf-tab:*' switch-group ',' '.'