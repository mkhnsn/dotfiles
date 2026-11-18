#!/usr/bin/env zsh
# Key cheat sheet for the C-a ? popup. Colors match the hint row in tmux.conf.
b=$'\e[1;34m' g=$'\e[1;32m' y=$'\e[1;33m' m=$'\e[1;35m' d=$'\e[2m' r=$'\e[0m'

print -r -- "
  ${d}Press C-a, then the key.${r}

  ${b}Tabs${r}                          ${g}Splits${r}
    ${b}c${r}      new tab                ${g}|${r}      split side by side
    ${b}1-9${r}    go to tab              ${g}-${r}      split top/bottom
    ${b}n  p${r}   next / previous        ${g}h j k l${r}  move
    ${b},${r}      rename                 ${g}z${r}      zoom in/out
    ${b}&${r}      close                  ${g}x${r}      close
    ${b}w${r}      pick from list         ${g}q${r}      show numbers

  ${y}Scroll and copy${r}               ${m}Session${r}
    ${y}[${r}      scroll mode (q exits)  ${m}d${r}      detach
    ${y}v  y${r}   select / copy          ${m}s${r}      pick session
    ${y}]${r}      paste                  ${m}\$${r}      rename
    ${d}drag with the mouse to copy${r}   ${m}C-s${r}    save now
                                  ${m}C-r${r}    restore saved

  Other
    r  reload config   :  command   H  hide hint row
    m  mouse on/off
    Full list: C-a :list-keys

  ${d}Press any key to close.${r}"
read -sk1
