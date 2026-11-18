#!/bin/sh
# tmux-yank copy command. Copies stdin to the desktop clipboard when this tmux
# server has one. Over ssh/mosh there is none, so it discards the input: tmux's
# set-clipboard (OSC 52) already sends the copy to the client's clipboard.
if [ "$(uname)" = Darwin ]; then exec pbcopy; fi
if [ -n "$WAYLAND_DISPLAY" ] && command -v wl-copy >/dev/null; then exec wl-copy; fi
if [ -n "$DISPLAY" ] && command -v xclip >/dev/null; then exec xclip -selection clipboard; fi
cat >/dev/null
