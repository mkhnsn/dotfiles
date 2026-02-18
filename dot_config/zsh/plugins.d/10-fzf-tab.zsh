PLUGIN_DIR="$HOME/.config/zsh/plugins/fzf-tab"

if [[ -r "$PLUGIN_DIR/fzf-tab.plugin.zsh" ]]; then
  source "$PLUGIN_DIR/fzf-tab.plugin.zsh"
fi

# --- fzf-tab settings ---

# Colorize completion entries using LS_COLORS (if set) or a sensible default
if [[ -n "${LS_COLORS:-}" ]]; then
  zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
else
  zstyle ':completion:*' list-colors "di=34:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43"
fi

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
