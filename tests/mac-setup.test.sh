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
  export HOME="$T/home" XDG_STATE_HOME="$T/state" MAC_SETUP_APPS="$T/Applications" MAC_SETUP_BREW="$T/none" MAC_SETUP_SYSAPPS="$T/System"
  STUBS="$HOME/.local/bin"
  mkdir -p "$STUBS" "$MAC_SETUP_APPS/BetterTouchTool.app" "$T/src/.git" "$T/brew"
  export PATH="$STUBS:/usr/bin:/bin"
  # Everything passes by default; tests break one thing at a time.
  stub uname       '[ "${1:-}" = -m ] && echo arm64 || echo Darwin'
  stub arch        'exit 0'
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
  stub mac-defaults 'exit 0'
  stub defaults    'printf "    {\n        LSHandlerRoleAll = \"com.google.chrome\";\n        LSHandlerURLScheme = http;\n    },\n"'
  for a in OpenSCAD Festivitas Cursorful HueForge "MASSO Link" "EXStar Hub" 3DconnexionSettings gridfinity-studio; do
    mkdir -p "$MAC_SETUP_APPS/$a.app"
  done
  mark_done escrow
  mark_done remote
  mark_done licences
  mark_done op_browser
  mark_done app_exports
  mark_done vm
  stub app-prefs 'exit 0'
  mkdir -p "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t"
  touch "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
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
  assert_open "FileVault on (workstations)"
}

test_server_skips_filevault_and_escrow() {
  stub fdesetup 'echo "FileVault is Off."'
  rm -f "$XDG_STATE_HOME/mac-setup/escrow"
  run "$SCRIPT_SERVER" --status
  assert_done "FileVault on (workstations)"; assert_done "FileVault key and Activation Lock code saved"
  run "$SCRIPT" --status
  assert_open "FileVault on (workstations)"
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

test_rosetta_missing_on_apple_silicon() {
  stub arch 'exit 1'
  run "$SCRIPT" --status
  assert_open "Rosetta installed"
  stub uname '[ "${1:-}" = -m ] && echo x86_64 || echo Darwin'
  run "$SCRIPT" --status
  assert_done "Rosetta installed"
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
  assert_open "Apps signed in and activated"
  assert_open "Chrome signed in, 1Password browser integration"
  assert_open "Private app exports restored"; assert_open "Virtual machines moved"
  assert_open "Ninja Remote Screen Recording approved"; assert_has "6 step(s) left"
}

test_workstation_apps_missing() {
  stub brew "case \"\$1 \$2\" in 'bundle check') case \"\$*\" in *Brewfile.workstation*) exit 1 ;; esac ;; --prefix*) echo $T/brew ;; esac; exit 0"
  run "$SCRIPT" --status
  assert_open "Workstation apps installed"; assert_done "Brewfile packages installed"
}

test_vendor_app_missing_lists_its_site() {
  rm -rf "$MAC_SETUP_APPS/HueForge.app"
  run "$SCRIPT" --status
  assert_open "Apps without a cask installed"
  printf 'q\n' > "$T/answers"
  MAC_SETUP_TTY="$T/answers" run "$SCRIPT"
  assert_has "HueForge  https://shop.thehueforge.com"; assert_lacks "Festivitas  https"
}

test_op_ssh_agent_off() {
  rm -f "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
  run "$SCRIPT" --status
  assert_open "1Password SSH agent on"
  run "$SCRIPT_SERVER" --status
  assert_done "1Password SSH agent on"
}

test_app_prefs_differ_lists_apps() {
  stub app-prefs '[ "$1" = diff ] && echo "  com.surteesstudios.Bartender: ProfileSettings"; exit 1'
  run "$SCRIPT" --status
  assert_open "Saved app settings applied"
  printf 'n\nq\n' > "$T/answers"
  MAC_SETUP_TTY="$T/answers" run "$SCRIPT"
  assert_has "com.surteesstudios.Bartender: ProfileSettings"
  run "$SCRIPT_SERVER" --status
  assert_done "Saved app settings applied"
}

test_gridfinity_missing() {
  rm -rf "$MAC_SETUP_APPS/gridfinity-studio.app"
  run "$SCRIPT" --status
  assert_open "gridfinity-studio installed"
}

test_settings_differ_shows_diff() {
  stub mac-defaults '[ "$1" = --diff ] && echo "  com.apple.dock autohide: 0 (want true)"; exit 1'
  run "$SCRIPT" --status
  assert_open "macOS settings and Dock"
  printf 'n\nq\n' > "$T/answers"
  MAC_SETUP_TTY="$T/answers" run "$SCRIPT"
  assert_has "com.apple.dock autohide: 0 (want true)"
}

test_default_browser_safari() {
  stub defaults 'printf "    {\n        LSHandlerRoleAll = \"com.apple.safari\";\n        LSHandlerURLScheme = http;\n    },\n    {\n        LSHandlerRoleAll = \"com.google.chrome\";\n        LSHandlerURLScheme = mailto;\n    },\n"'
  run "$SCRIPT" --status
  assert_open "Default browser is Chrome"
}

test_server_skips_workstation_steps() {
  rm -rf "$MAC_SETUP_APPS"/*.app "$XDG_STATE_HOME/mac-setup/licences"
  stub defaults 'exit 1'
  stub brew "case \"\$*\" in *Brewfile.workstation*) exit 1 ;; --prefix) echo $T/brew ;; esac; exit 0"
  run "$SCRIPT_SERVER" --status
  assert_done "Workstation apps installed"; assert_done "Apps without a cask installed"
  assert_done "gridfinity-studio installed"; assert_done "Apps signed in and activated"
  assert_done "Default browser is Chrome"
  assert_done "BetterTouchTool installed from folivora.ai"
}

# ---- mac-defaults ------------------------------------------------------------------

DEFAULTS_SCRIPT="$HERE/../dot_local/bin/executable_mac-defaults"

# A fake `defaults` that stores values in files, and a fake dockutil with a Dock list.
fake_prefs() {
  mkdir -p "$T/prefs"
  stub defaults "f=\"$T/prefs/\$2.\${3:-}\"; case \"\$1\" in
    read) if [ -z \"\${3:-}\" ] && [ -f \"\$2\" ]; then cat \"\$2\"; elif [ -f \"\$f\" ]; then cat \"\$f\"; else exit 1; fi ;;
    import) cp \"\$3\" \"$T/prefs/\$2.\" ;;
    export) cp \"$T/prefs/\$2.\" \"\$3\" ;;
    write) v=\"\$5\"; [ \"\$v\" = true ] && v=1; [ \"\$v\" = false ] && v=0; echo \"\$v\" > \"\$f\" ;;
  esac"
  stub killall 'exit 0'
  : > "$T/dock"
  stub dockutil "case \"\$1\" in
    --list) while IFS= read -r n; do printf '%s\tfile:///x/\tpersistentApps\tplist\tid\n' \"\$n\"; done < $T/dock ;;
    --remove) : > $T/dock ;;
    --add) basename \"\$2\" .app >> $T/dock ;;
  esac"
  for a in "Google Chrome" Mail Ghostty; do mkdir -p "$MAC_SETUP_APPS/$a.app"; done
  echo "shortcuts-v1" > "$T/shortcuts.plist"
  export MAC_DEFAULTS_SHORTCUTS="$T/shortcuts.plist"
}

test_defaults_check_fails_then_apply_fixes_it() {
  fake_prefs
  run "$DEFAULTS_SCRIPT" --check; assert_rc 1
  run "$DEFAULTS_SCRIPT"; assert_rc 0
  run "$DEFAULTS_SCRIPT" --check; assert_rc 0
}

test_defaults_dock_skips_missing_apps_in_order() {
  fake_prefs
  run "$DEFAULTS_SCRIPT" --dock
  assert_has "left out of the Dock"
  [ "$(paste -sd, - < "$T/dock")" = "Google Chrome,Mail,Ghostty" ] || fail "dock order: $(paste -sd, - < "$T/dock")"
}

test_defaults_diff_names_the_setting() {
  fake_prefs
  "$RUN_BASH" "$DEFAULTS_SCRIPT" >/dev/null 2>&1
  echo 0 > "$T/prefs/com.apple.dock.autohide"
  run "$DEFAULTS_SCRIPT" --diff
  assert_has "com.apple.dock autohide: 0 (want true)"; assert_lacks "tilesize"
}

test_defaults_shortcuts_applied_and_checked() {
  fake_prefs
  run "$DEFAULTS_SCRIPT" --check; assert_rc 1
  "$RUN_BASH" "$DEFAULTS_SCRIPT" >/dev/null 2>&1
  [ "$(cat "$T/prefs/com.apple.symbolichotkeys." 2>/dev/null)" = shortcuts-v1 ] || fail "shortcuts not imported"
  run "$DEFAULTS_SCRIPT" --check; assert_rc 0
  echo changed > "$T/prefs/com.apple.symbolichotkeys."
  run "$DEFAULTS_SCRIPT" --diff; assert_has "Keyboard shortcuts differ"
}

test_defaults_finds_shortcuts_via_chezmoi_source_dir() {
  # Regression: inside `chezmoi apply`, `chezmoi source-path` is empty and shortcuts were skipped.
  fake_prefs
  unset MAC_DEFAULTS_SHORTCUTS
  stub chezmoi 'exit 0'
  mkdir -p "$T/src/macos"; echo shortcuts-v2 > "$T/src/macos/symbolichotkeys.plist"
  CHEZMOI_SOURCE_DIR="$T/src" run "$DEFAULTS_SCRIPT"
  [ "$(cat "$T/prefs/com.apple.symbolichotkeys." 2>/dev/null)" = shortcuts-v2 ] || fail "shortcuts not imported from CHEZMOI_SOURCE_DIR"
}

test_defaults_without_source_skips_shortcuts_cleanly() {
  fake_prefs
  unset MAC_DEFAULTS_SHORTCUTS
  stub chezmoi 'exit 0'
  run "$DEFAULTS_SCRIPT"
  assert_rc 0; assert_has "shortcuts file not found, skipped"
}

test_defaults_export_shortcuts() {
  fake_prefs
  echo mine > "$T/prefs/com.apple.symbolichotkeys."
  run "$DEFAULTS_SCRIPT" --export-shortcuts
  assert_rc 0; [ "$(cat "$T/shortcuts.plist")" = mine ] || fail "not exported"
}

test_defaults_new_app_breaks_dock_check() {
  fake_prefs
  "$RUN_BASH" "$DEFAULTS_SCRIPT" >/dev/null 2>&1
  mkdir -p "$MAC_SETUP_APPS/Slack.app"
  run "$DEFAULTS_SCRIPT" --check; assert_rc 1
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
