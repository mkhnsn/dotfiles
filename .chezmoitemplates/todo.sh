# Manual follow-ups for the end-of-apply summary (run_after_zz-todo-summary).
# Usage (from a script template): template "todo.sh"
# then: todo "what needs doing, including the command to run"
# run_before_00-todo-reset clears the list at the start of each apply.
DOTFILES_TODO="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/todo"
todo() {
  mkdir -p "${DOTFILES_TODO%/*}" && printf '%s\n' "$*" >> "$DOTFILES_TODO"
}
