PLUGIN_DIR="$HOME/.config/zsh/plugins/fzf-tab"

if [[ -r "$PLUGIN_DIR/fzf-tab.plugin.zsh" ]]; then
  source "$PLUGIN_DIR/fzf-tab.plugin.zsh"
fi

# --- fzf-tab settings ---

# set list-colors to enable filename colorizing
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# Let you switch completion groups with < and > (shift+, and shift+.)
zstyle ':fzf-tab:*' switch-group '<' '>'

# Make the UI consistent and avoid heavy preview churn by default
zstyle ':fzf-tab:*' fzf-flags \
  --height=40% \
  --layout=reverse \
  --border \
  --preview-window=right,55%:wrap \
  --style minimal

zstyle ':fzf-tab:*' fzf-bindings 'space:accept'
zstyle ':fzf-tab:*' accept-line enter
