# zsh-better-npm-completion
PLUGIN_DIR="$HOME/.config/zsh/plugins/zsh-better-npm-completion"

if [[ -r "$PLUGIN_DIR/zsh-better-npm-completion.plugin.zsh" ]]; then
  source "$PLUGIN_DIR/zsh-better-npm-completion.plugin.zsh"
fi

# Prefer the plugin's completion for npm if it defined _npm
if typeset -f _npm >/dev/null 2>&1; then
  compdef _npm npm
fi
