#!/bin/bash
# Tests for mac-setup, run against stub commands so they work on Linux CI.
# Bash 3.2-compatible, no dependencies. Run with the bash you want to test:
#   tests/render.sh && bash tests/mac-setup.test.sh
# MAC_SETUP_BASH picks the bash that runs mac-setup (default: the one running this).

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUILD="$HERE/.build"
SCRIPT="$BUILD/mac-setup"
SCRIPT_SERVER="$BUILD/mac-setup-server"
RUN_BASH="${MAC_SETUP_BASH:-$BASH}"
[ -f "$SCRIPT" ] && [ -f "$SCRIPT_SERVER" ] || { echo "run tests/render.sh first"; exit 2; }

PASS=0 FAIL=0 OUT="" RC=0

# ---- Sandbox: a fake HOME whose ~/.local/bin holds stub commands ------------------

setup() {
  T="$(mktemp -d)"
  export HOME="$T/home" XDG_STATE_HOME="$T/state" MAC_SETUP_APPS="$T/Applications" MAC_SETUP_BREW="$T/none"
  STUBS="$HOME/.local/bin"
  mkdir -p "$STUBS" "$MAC_SETUP_APPS/BetterTouchTool.app" "$T/src/.git" "$T/brew"
  export PATH="$STUBS:/usr/bin:/bin"
  # Everything passes by default; tests break one thing at a time.
  stub uname       'echo Darwin'
  stub id          '[ "${1:-}" = -u ] && echo 501 || /usr/bin/id "$@"'
  stub ioreg       'echo "    | \"IOPlatformSerialNumber\" = \"TESTSERIAL\""'
  stub scutil      'echo Test-Mac'
  stub sw_vers     'echo 27.2'
  stub profiles    'echo "MDM enrollment: Yes (User Approved)"'
  stub fdesetup    'echo "FileVault is On."'
  stub system_profiler 'printf "        macOS: Firewall:\n        macOS: NinjaOne privacy permissions:\n"'
  stub pgrep       'exit 0'
  stub xcode-select 'echo /Library/Developer/CommandLineTools'
  stub brew        "case \"\$1\" in --prefix) echo $T/brew ;; *) exit 0 ;; esac"
  stub op          'echo "URL ACCOUNT"'
  stub chezmoi     "case \"\$1\" in source-path) echo $T/src ;; *) exit 0 ;; esac"
  stub gh          'exit 0'
  stub doppler     'exit 0'
  stub tailscale   'printf "{\n  \"BackendState\": \"Running\",\n  \"Self\": {\n    \"DNSName\": \"test-mac.example.ts.net.\",\n    \"Tags\": [\"tag:echo-admin\"]\n  }\n}\n"'
  stub osascript   'echo "Litra On/Off"'
  stub open        'exit 0'
  mark_done escrow
  mark_done remote
}
teardown() { rm -rf "$T"; }

stub() { printf '#!/bin/sh\n%s\n' "$2" > "$STUBS/$1"; chmod +x "$STUBS/$1"; }
mark_done() { mkdir -p "$XDG_STATE_HOME/mac-setup"; touch "$XDG_STATE_HOME/mac-setup/$1"; }
# Run mac-setup with no stdin and a watchdog, so a prompt that escapes the answer
# file (e.g. reads /dev/tty) fails the test instead of hanging it.
run() {
  "$RUN_BASH" "$@" >"$T/out" 2>&1 </dev/null &
  local pid=$! dog
  ( sleep 20; kill "$pid" 2>/dev/null ) & dog=$!
  wait "$pid"; RC=$?
  kill "$dog" 2>/dev/null; wait "$dog" 2>/dev/null
  OUT="$(cat "$T/out")"
}

# ---- Assertions ------------------------------------------------------------------

CUR=""
ok()   { :; }
fail() { FAIL=$((FAIL+1)); printf 'FAIL %s: %s\n' "$CUR" "$1"; printf '%s\n' "$OUT" | sed 's/^/    | /'; }
assert_rc()       { [ "$RC" -eq "$1" ] || fail "exit $RC, want $1"; }
assert_has()      { printf '%s' "$OUT" | grep -qF -- "$1" || fail "missing: $1"; }
assert_lacks()    { printf '%s' "$OUT" | grep -qF -- "$1" && fail "unexpected: $1"; return 0; }
assert_done()     { assert_has "✓ $1"; }
assert_open()     { assert_has "○ $1"; }

t() { CUR="$1"; setup; "$1"; teardown; PASS=$((PASS+1)); }

# ---- Tests -----------------------------------------------------------------------

test_all_done() {
  run "$SCRIPT" --status
  assert_rc 0; assert_has "All done."; assert_lacks "○"
}

test_header_shows_mac() {
  run "$SCRIPT" --status
  assert_has "Test-Mac (TESTSERIAL), 27.2"
}

test_header_shows_role() {
  run "$SCRIPT" --status
  assert_has "Role: workstation"
  run "$SCRIPT_SERVER" --status
  assert_has "Role: server"
}

test_root_is_flagged() {
  stub id '[ "${1:-}" = -u ] && echo 0'
  run "$SCRIPT" --status
  assert_rc 1; assert_open "Running as your own user"; assert_has "1 step(s) left"
}

test_not_enrolled() {
  stub profiles 'echo "MDM enrollment: No"'
  run "$SCRIPT" --status
  assert_open "Enrolled in SimpleMDM"
}

test_filevault_off() {
  stub fdesetup 'echo "FileVault is Off."'
  run "$SCRIPT" --status
  assert_open "FileVault on"
}

test_profiles_need_both() {
  stub system_profiler 'echo "        macOS: Firewall:"'
  run "$SCRIPT" --status
  assert_open "MDM profiles installed"
}

test_ninja_not_running() {
  stub pgrep 'exit 1'
  run "$SCRIPT" --status
  assert_open "NinjaOne agent running"
}

test_stale_clt_via_brew_doctor() {
  stub brew "case \"\$1\" in doctor) exit 1 ;; --prefix) echo $T/brew ;; *) exit 0 ;; esac"
  run "$SCRIPT" --status
  assert_open "Command Line Tools current"; assert_done "Homebrew installed"
}

test_no_brew() {
  rm "$STUBS/brew"
  run "$SCRIPT" --status
  assert_open "Homebrew installed"; assert_open "Brewfile packages installed"
}

test_op_without_accounts() {
  stub op 'exit 0'
  run "$SCRIPT" --status
  assert_open "1Password CLI connected"
}

test_dotfiles_need_git_source() {
  rm -rf "$T/src/.git"
  run "$SCRIPT" --status
  assert_open "Dotfiles applied"
}

test_dotfiles_verify_skips_templates_and_scripts() {
  stub chezmoi "case \"\$1\" in source-path) echo $T/src ;; verify) [ \"\$2\" = --exclude=scripts,templates ] ;; *) exit 0 ;; esac"
  run "$SCRIPT" --status
  assert_done "Dotfiles applied"
}

test_brewfile_check_ignores_outdated() {
  stub brew "case \"\$1 \$2\" in 'bundle check') [ \"\$3\" = --no-upgrade ] ;; --prefix*) echo $T/brew ;; *) exit 0 ;; esac"
  run "$SCRIPT" --status
  assert_done "Brewfile packages installed"
}

test_gh_and_doppler_signed_out() {
  stub gh 'exit 1'; stub doppler 'exit 1'
  run "$SCRIPT" --status
  assert_open "GitHub CLI signed in"; assert_open "Doppler signed in"
}

test_tailscale_stopped() {
  stub tailscale 'echo "{ \"BackendState\": \"Stopped\" }"'
  run "$SCRIPT" --status
  assert_open "Tailscale connected"
}

test_tailscale_name_is_dns_label_not_hostname() {
  stub tailscale 'printf "{\n  \"BackendState\": \"Running\",\n  \"Self\": {\n    \"HostName\": \"Test-Mac\",\n    \"DNSName\": \"test-mac-1.example.ts.net.\",\n    \"Tags\": [\"tag:echo-admin\"]\n  }\n}\n"'
  run "$SCRIPT" --status
  assert_open "Tailscale name is test-mac"
}

test_tailscale_found_in_app_bundle() {
  rm "$STUBS/tailscale"
  mkdir -p "$MAC_SETUP_APPS/Tailscale.app/Contents/MacOS"
  printf '#!/bin/sh\nprintf "{ \\"BackendState\\": \\"Running\\" }\\n"\n' > "$MAC_SETUP_APPS/Tailscale.app/Contents/MacOS/Tailscale"
  chmod +x "$MAC_SETUP_APPS/Tailscale.app/Contents/MacOS/Tailscale"
  run "$SCRIPT" --status
  assert_done "Tailscale connected"
}

test_admin_tag_missing() {
  stub tailscale 'printf "{\n  \"BackendState\": \"Running\",\n  \"Self\": {\n    \"DNSName\": \"test-mac.example.ts.net.\",\n    \"Tags\": []\n  }\n}\n"'
  run "$SCRIPT" --status
  assert_open "Tailscale tag tag:echo-admin"
}

test_server_expects_core_tag() {
  run "$SCRIPT_SERVER" --status
  assert_open "Tailscale tag tag:echo-core"
}

test_btt_from_homebrew_is_flagged() {
  mkdir -p "$T/brew/Caskroom/bettertouchtool"
  run "$SCRIPT" --status
  assert_open "BetterTouchTool installed from folivora.ai"
}

test_btt_preset_missing() {
  stub osascript 'echo "no triggers"'
  run "$SCRIPT" --status
  assert_open "BetterTouchTool preset imported"
}

test_manual_steps_start_open() {
  rm -rf "$XDG_STATE_HOME/mac-setup"
  run "$SCRIPT" --status
  assert_open "FileVault key and Activation Lock code saved to 1Password"
  assert_open "Ninja Remote Screen Recording approved"; assert_has "2 step(s) left"
}

test_reset_forgets_manual_steps() {
  run "$SCRIPT" --reset
  assert_rc 0
  run "$SCRIPT" --status
  assert_open "Ninja Remote Screen Recording approved"
}

test_unknown_flag() {
  run "$SCRIPT" --bogus
  assert_rc 1; assert_has "usage: mac-setup"
}

test_not_macos() {
  stub uname 'echo Linux'
  run "$SCRIPT" --status
  assert_rc 1; assert_has "macOS only"
}

test_guided_needs_a_terminal() {
  MAC_SETUP_TTY="$T/missing" run "$SCRIPT"
  assert_rc 1; assert_has "needs a terminal"
}

test_guided_runs_action_then_rechecks() {
  # gh signed out; the action "logs in" by flipping the stub, then the re-check passes.
  stub gh "if [ \"\$1\" = auth ] && [ \"\$2\" = login ]; then printf '#!/bin/sh\nexit 0\n' > $STUBS/gh; exit 0; fi; exit 1"
  printf 'y\n\n' > "$T/answers"
  MAC_SETUP_TTY="$T/answers" run "$SCRIPT"
  assert_rc 0; assert_done "GitHub CLI signed in"; assert_has "All done."
}

test_guided_prompts_and_action_output_are_shown() {
  # Regression: `exec 3<tty 2>/dev/null` silenced stderr, hiding prompts and gh's login code.
  stub gh "if [ \"\$1 \$2\" = 'auth login' ]; then echo 'one-time code: ABCD-1234' >&2; printf '#!/bin/sh\nexit 0\n' > $STUBS/gh; exit 0; fi; exit 1"
  rm -f "$XDG_STATE_HOME/mac-setup/escrow"
  printf 'y\ny\n\n' > "$T/answers"
  MAC_SETUP_TTY="$T/answers" run "$SCRIPT"
  assert_has "Done? [y/N/q]"
  assert_has "Do it now? [Y/n/s=skip/q=quit]"
  assert_has "one-time code: ABCD-1234"
  assert_has "Enter to re-check"
  assert_has "All done."
}

test_guided_skip_leaves_step_open() {
  stub doppler 'exit 1'
  printf 's\n' > "$T/answers"
  MAC_SETUP_TTY="$T/answers" run "$SCRIPT"
  assert_has "skipped"; assert_has "1 step(s) left"; assert_rc 0
}

test_guided_manual_step_is_remembered() {
  rm -f "$XDG_STATE_HOME/mac-setup/remote"
  printf 'y\n' > "$T/answers"
  MAC_SETUP_TTY="$T/answers" run "$SCRIPT"
  assert_has "All done."
  [ -f "$XDG_STATE_HOME/mac-setup/remote" ] || fail "remote not remembered"
}

test_guided_quit() {
  stub doppler 'exit 1'
  printf 'q\n' > "$T/answers"
  MAC_SETUP_TTY="$T/answers" run "$SCRIPT"
  assert_rc 1; assert_lacks "Tailscale connected"
}

# ---- Run -------------------------------------------------------------------------

tests="$(grep -oE '^test_[a-z0-9_]+' "$0")"
for name in $tests; do
  before=$FAIL
  t "$name"
  [ "$FAIL" -eq "$before" ] && printf 'ok   %s\n' "$name"
done
echo
echo "$((PASS)) tests, $FAIL failure(s) ($("$RUN_BASH" -c 'echo $BASH_VERSION'))"
[ "$FAIL" -eq 0 ]
