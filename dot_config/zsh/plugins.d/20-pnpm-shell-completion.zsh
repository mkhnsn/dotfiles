# pnpm-shell-completion (only enable if helper exists; otherwise skip quietly)
PLUGIN_DIR="$HOME/.config/zsh/plugins/pnpm-shell-completion"

if [[ -x "$PLUGIN_DIR/pnpm-shell-completion" ]] && [[ -r "$PLUGIN_DIR/pnpm-shell-completion.plugin.zsh" ]]; then
  source "$PLUGIN_DIR/pnpm-shell-completion.plugin.zsh"
fi