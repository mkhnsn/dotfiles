#!/usr/bin/env bash
# Start each apply with an empty manual-follow-up list (see .chezmoitemplates/todo.sh).
rm -f "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/todo"
