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
  export MAC_SETUP_TM_PREFS="$T/tm-prefs"
  export HOME="$T/home" XDG_STATE_HOME="$T/state" XDG_CONFIG_HOME="$T/home/.config" MAC_SETUP_APPS="$T/Applications" MAC_SETUP_BREW="$T/none" MAC_SETUP_SYSAPPS="$T/System"
  export MAC_SETUP_LOCKHART="$T/lockhart" MAC_SETUP_ONEDRIVE="$T/OneDrive"
  mkdir -p "$T/OneDrive"
  STUBS="$HOME/.local/bin"
  mkdir -p "$STUBS" "$MAC_SETUP_APPS/BetterTouchTool.app" "$T/src/.git" "$T/brew"
  mkdir -p "$MAC_SETUP_APPS/Elgato Stream Deck.app/Contents"
  printf '<dict>\n\t<key>CFBundleShortVersionString</key>\n\t<string>8.0.1</string>\n</dict>\n' > "$MAC_SETUP_APPS/Elgato Stream Deck.app/Contents/Info.plist"
  mkdir -p "$MAC_SETUP_APPS/Elgato Stream Deck.app/Contents/Helpers"
  printf '#!/bin/sh\n' > "$MAC_SETUP_APPS/Elgato Stream Deck.app/Contents/Helpers/streamdeck-mcp"; chmod +x "$MAC_SETUP_APPS/Elgato Stream Deck.app/Contents/Helpers/streamdeck-mcp"
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
  stub system_profiler 'printf "        macOS: Firewall:\n        macOS: NinjaOne privacy permissions:\n        macOS: Terminal privacy permissions:\n"'
  stub nc          'exit 0'
  stub tmutil      'case "$1" in isexcluded) echo "[Excluded]  $2" ;; *) echo "Name          : backups" ;; esac'
  stub dscl        'exit 0'
  stub dsmemberutil 'echo "user is a member of the group"'
  printf '#!/bin/sh\n' > "$MAC_SETUP_LOCKHART"; chmod +x "$MAC_SETUP_LOCKHART"
  stub pgrep       'exit 0'
  stub xcode-select 'echo /Library/Developer/CommandLineTools'
  stub brew        "case \"\$1 \${2:-}\" in --prefix*) echo $T/brew ;; 'services info') echo '[{\"name\": \"colima\", \"registered\": true}]' ;; *) exit 0 ;; esac"
  stub colima      'exit 0'
  stub security    'exit 0'
  stub ollama      'exit 0'
  mkdir -p "$HOME/.config/claude-ha"; echo http://ha/api/webhook/x > "$HOME/.config/claude-ha/webhook-url"
  echo '{"mcpServers":{"homeassistant":{}}}' > "$HOME/.claude.json"
  stub op          'echo "URL ACCOUNT"'
  stub chezmoi     "case \"\$1\" in source-path) echo $T/src ;; *) exit 0 ;; esac"
  stub gh          'exit 0'
  stub doppler     'exit 0'
  stub tailscale   'printf "{\n  \"BackendState\": \"Running\",\n  \"Self\": {\n    \"DNSName\": \"test-mac.example.ts.net.\",\n    \"Tags\": [\"tag:echo-admin\"]\n  }\n}\n"'
  # The BTT check reads JSON with python3; the bash:3.2 image has none, so there BTT
  # looks up to date and the BTT preset tests are skipped (has_python).
  if command -v python3 >/dev/null 2>&1; then MAC_SETUP_PYTHON="$(command -v python3)"; export MAC_SETUP_PYTHON
  else stub python3 'echo 0'; export MAC_SETUP_PYTHON="$STUBS/python3"; fi
  # BTT has the preset's one global shortcut (⌃⌥←); app-specific ones don't count.
  mkdir -p "$T/src/macos/btt"
  printf '%s' '{"BTTPresetContent":[{"BTTAppBundleIdentifier":"BT.G","BTTTriggers":[{"BTTTriggerClass":"BTTTriggerTypeKeyboardShortcut","BTTShortcutKeyCode":123,"BTTShortcutModifierKeys":786432}]},{"BTTAppBundleIdentifier":"us.zoom.xos","BTTTriggers":[{"BTTTriggerClass":"BTTTriggerTypeKeyboardShortcut","BTTShortcutKeyCode":9,"BTTShortcutModifierKeys":1835008}]}]}' > "$T/src/macos/btt/Default.bttpreset"
  stub osascript   'echo "[{\"BTTTriggerClass\": \"BTTTriggerTypeKeyboardShortcut\", \"BTTShortcutKeyCode\": 123, \"BTTShortcutModifierKeys\": 786432}]"'
  stub open        'exit 0'
  stub mac-defaults 'exit 0'
  # Prints the LaunchServices handlers for any key: a preset with move/resize keys would see
  # them all as missing, so the BTT tests stub defaults themselves.
  stub defaults    'printf "    {\n        LSHandlerRoleAll = \"com.google.chrome\";\n        LSHandlerURLScheme = http;\n    },\n"'
  for a in OpenSCAD Festivitas Cursorful HueForge "MASSO Link" "EXStar Hub" 3DconnexionSettings gridfinity-studio; do
    mkdir -p "$MAC_SETUP_APPS/$a.app"
  done
  mark_done escrow
  mark_done remote
  mark_done ninja_backup_run
  mark_done licences
  mark_done hueforge_plugins
  export MAC_SETUP_DOWNLOADS="$T/downloads"; mkdir -p "$MAC_SETUP_DOWNLOADS"
  mark_done op_browser
  mark_done app_exports
  mkdir -p "$HOME/.claude/projects/-Users-x-src/memory"; touch "$HOME/.claude/projects/-Users-x-src/memory/user.md"
  mark_done vm
  mark_done raycast_sync
  mark_done raycast_local
  mark_done zoom
  mark_done widgets
  mkdir -p "$MAC_SETUP_ONEDRIVE/Apps/Mac app exports/Raycast/Test-Mac"
  touch "$MAC_SETUP_ONEDRIVE/Apps/Mac app exports/Raycast/Test-Mac/Raycast.rayconfig"
  stub app-prefs 'exit 0'
  stub 3dx-sync 'exit 0'
  export MAC_SETUP_ECHO_M365="$T/echo-m365"
  mkdir -p "$MAC_SETUP_ECHO_M365" "$HOME/.mg"
  printf "@{\n    TenantId = 'tid-1'\n    AdminAccount = 'admin@example.com'\n}\n" > "$MAC_SETUP_ECHO_M365/tenant.psd1"
  echo '{"username":"admin@example.com","tenantId":"tid-1"}' > "$HOME/.mg/mg.authrecord.tid-1.json"
  mkdir -p "$HOME/Library/Mobile Documents/com~apple~CloudDocs" "$HOME/Desktop" "$HOME/Documents"
  ln -s "$HOME/Desktop" "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Desktop"
  ln -s "$HOME/Documents" "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents"
  mkdir -p "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t"
  touch "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
}
teardown() { rm -rf "$T"; }

has_python() { [ "$MAC_SETUP_PYTHON" != "$STUBS/python3" ]; }
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
  assert_done "FileVault on (workstations)"; assert_done "FileVault key saved to 1Password"
  assert_done "Activation Lock code saved to 1Password"
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

test_server_flags_personal_logins() {
  stub gh 'echo "  - Token: gho_************************************" >&2; exit 0'
  stub doppler 'echo "{\"type\":\"cli\",\"name\":\"x\"}"'
  run "$SCRIPT_SERVER" --status
  assert_open "GitHub CLI without your personal login"; assert_open "Doppler without your personal login"
  run "$SCRIPT" --status
  assert_done "GitHub CLI signed in"; assert_done "Doppler signed in"
}

test_server_flags_doppler_personal_token() {
  stub doppler 'echo "{\"type\":\"personal\"}"'
  run "$SCRIPT_SERVER" --status
  assert_open "Doppler without your personal login"
}

test_server_gh_env_token_explained() {
  stub gh 'echo "  - Token: ghp_************************************" >&2; exit 0'
  printf 'y\nq\n' > "$T/answers"
  GH_TOKEN=x MAC_SETUP_TTY="$T/answers" run "$SCRIPT_SERVER"
  assert_has "GH_TOKEN or GITHUB_TOKEN"; assert_has "Unset GH_TOKEN/GITHUB_TOKEN first"
}

test_server_accepts_scoped_tokens_or_none() {
  stub gh 'echo "  - Token: github_pat_*************************" >&2; exit 0'
  stub doppler 'echo "{\"type\":\"service_token\"}"'
  run "$SCRIPT_SERVER" --status
  assert_done "GitHub CLI without your personal login"; assert_done "Doppler without your personal login"
  stub doppler 'echo "{\"type\":\"service_account\"}"'
  run "$SCRIPT_SERVER" --status
  assert_done "GitHub CLI without your personal login"; assert_done "Doppler without your personal login"
  stub gh 'exit 1'; stub doppler 'exit 1'
  run "$SCRIPT_SERVER" --status
  assert_done "GitHub CLI without your personal login"; assert_done "Doppler without your personal login"
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

test_server_flags_tailscale_app() {
  mkdir -p "$MAC_SETUP_APPS/Tailscale.app"
  run "$SCRIPT_SERVER" --status
  assert_open "No Tailscale app (servers use tailscaled)"
  run "$SCRIPT" --status
  assert_done "No Tailscale app (servers use tailscaled)"
}

test_server_tailscale_points_to_playbook() {
  stub tailscale 'echo "{ \"BackendState\": \"Stopped\" }"'
  printf 'q\n' > "$T/answers"
  MAC_SETUP_TTY="$T/answers" run "$SCRIPT_SERVER"
  assert_has "echo-core playbook"
  assert_lacks "Install the app, open it"
  assert_lacks "Do it now?"
}

test_workstation_tailscale_offers_action() {
  stub tailscale 'echo "{ \"BackendState\": \"Stopped\" }"'
  printf 'q\n' > "$T/answers"
  MAC_SETUP_TTY="$T/answers" run "$SCRIPT"
  assert_has "Install the app, open it"
  assert_has "Do it now?"
}

test_btt_from_homebrew_is_flagged() {
  mkdir -p "$T/brew/Caskroom/bettertouchtool"
  run "$SCRIPT" --status
  assert_open "BetterTouchTool installed from folivora.ai"
}

test_btt_in_user_applications_is_moved() {
  rm -rf "$MAC_SETUP_APPS/BetterTouchTool.app"; mkdir -p "$HOME/Applications/BetterTouchTool.app"
  stub osascript 'exit 0'; stub pkill 'exit 0'; stub open 'exit 0'
  run "$SCRIPT" --status
  assert_open "BetterTouchTool installed from folivora.ai"
  printf 'y\n\nq\n' > "$T/answers"
  MAC_SETUP_TTY="$T/answers" run "$SCRIPT"
  assert_has "is in ~/Applications"
  assert_done "BetterTouchTool installed from folivora.ai"
  [ -d "$MAC_SETUP_APPS/BetterTouchTool.app" ] && [ ! -d "$HOME/Applications/BetterTouchTool.app" ] || fail "not moved"
}

test_btt_in_user_applications_from_homebrew_is_not_moved() {
  rm -rf "$MAC_SETUP_APPS/BetterTouchTool.app"; mkdir -p "$HOME/Applications/BetterTouchTool.app" "$T/brew/Caskroom/bettertouchtool"
  stub open 'exit 0'
  printf 'n\nq\n' > "$T/answers"
  MAC_SETUP_TTY="$T/answers" run "$SCRIPT"
  assert_has "(not Homebrew)"
  assert_lacks "is in ~/Applications"
}

test_btt_move_fails_reopens_old_copy() {
  rm -rf "$MAC_SETUP_APPS/BetterTouchTool.app"; mkdir -p "$HOME/Applications/BetterTouchTool.app"
  stub osascript 'exit 0'; stub pkill 'exit 0'; stub mv 'exit 1'
  stub open "echo \"opened \$1\""
  printf 'y\nq\n' > "$T/answers"
  MAC_SETUP_TTY="$T/answers" run "$SCRIPT"
  assert_has "opened $HOME/Applications/BetterTouchTool.app"
  [ -d "$HOME/Applications/BetterTouchTool.app" ] || fail "old copy gone"
}

test_streamdeck_7_is_flagged() {
  sed -i.bak 's/8\.0\.1/7.6.1/' "$MAC_SETUP_APPS/Elgato Stream Deck.app/Contents/Info.plist"
  rm "$MAC_SETUP_APPS/Elgato Stream Deck.app/Contents/Helpers/streamdeck-mcp"
  run "$SCRIPT" --status
  assert_open "Stream Deck 8 installed (for its MCP server)"
  printf 'n\nq\n' > "$T/answers"
  MAC_SETUP_TTY="$T/answers" run "$SCRIPT"
  assert_has "Stream Deck is 7.x"
  run "$SCRIPT_SERVER" --status
  assert_done "Stream Deck 8 installed (for its MCP server)"
}

test_btt_preset_missing() {
  has_python || return 0
  stub osascript 'echo "no triggers"'
  run "$SCRIPT" --status
  assert_open "BetterTouchTool preset imported"
}

test_btt_preset_import_out_of_date() {
  has_python || return 0
  # An import from before the preset gained a shortcut: BTT has other triggers, not that one.
  stub osascript 'echo "[{\"BTTTriggerClass\": \"BTTTriggerTypeKeyboardShortcut\", \"BTTShortcutKeyCode\": 13, \"BTTShortcutModifierKeys\": 1179648}]"'
  run "$SCRIPT" --status
  assert_open "BetterTouchTool preset imported"
}

test_btt_move_resize_keys_differ() {
  has_python || return 0
  # shiftMove is off in the preset, so BTT not storing it is fine; optMove stored as 0 differs.
  printf '%s' '{"BTTGeneralSettings":{"cmdMove":true,"optMove":true,"shiftMove":false},"BTTPresetContent":[]}' > "$T/src/macos/btt/Default.bttpreset"
  stub defaults 'case "$*" in *BetterTouchTool\ cmdMove*) echo 1 ;; *BetterTouchTool\ optMove*) echo 0 ;; *) exit 1 ;; esac'
  run "$SCRIPT" --status
  assert_open "BetterTouchTool preset imported"
  # A modifier the preset turns off still on in BTT (an import from before the preset changed).
  stub defaults 'case "$*" in *BetterTouchTool*) echo 1 ;; *) exit 1 ;; esac'
  run "$SCRIPT" --status
  assert_open "BetterTouchTool preset imported"
  # Modifiers the preset doesn't list count as off.
  stub defaults 'case "$*" in *BetterTouchTool\ cmdMove*|*BetterTouchTool\ optMove*) echo 1 ;; *) exit 1 ;; esac'
  run "$SCRIPT" --status
  assert_done "BetterTouchTool preset imported"
}

test_btt_mcp_off() {
  stub nc 'case "$*" in *64832*) exit 1 ;; *) exit 0 ;; esac'
  run "$SCRIPT" --status
  assert_open "BetterTouchTool MCP server on"
}

test_raycast_backup_missing() {
  # Another Mac's export doesn't count; nor does one from this Mac older than a week.
  mkdir -p "$MAC_SETUP_ONEDRIVE/Apps/Mac app exports/Raycast/Other-Mac"
  mv "$MAC_SETUP_ONEDRIVE/Apps/Mac app exports/Raycast/Test-Mac/Raycast.rayconfig" "$MAC_SETUP_ONEDRIVE/Apps/Mac app exports/Raycast/Other-Mac/"
  run "$SCRIPT" --status
  assert_open "Raycast exports weekly to OneDrive"
  touch -t 202001010000 "$MAC_SETUP_ONEDRIVE/Apps/Mac app exports/Raycast/Test-Mac/old.rayconfig"
  run "$SCRIPT" --status
  assert_open "Raycast exports weekly to OneDrive"
}

test_m365_admin_signed_in() {
  run "$SCRIPT" --status
  assert_done "Generate TAP: echo-m365 signed in as its admin account"
  # Signed in as the daily account: New-Tap would ask Graph for a TAP for itself.
  echo '{"username":"daily@example.com","tenantId":"tid-1"}' > "$HOME/.mg/mg.authrecord.tid-1.json"
  run "$SCRIPT" --status
  assert_open "Generate TAP: echo-m365 signed in as its admin account"
  # MSAL's spacing and UPN case don't matter; tabs and double quotes in tenant.psd1 are read.
  printf '{"username": "Admin@Example.com", "tenantId": "tid-1"}' > "$HOME/.mg/mg.authrecord.tid-1.json"
  printf '@{\n\tTenantId = "tid-1"\n\tAdminAccount = "admin@example.com"\n}\n' > "$MAC_SETUP_ECHO_M365/tenant.psd1"
  run "$SCRIPT" --status
  assert_done "Generate TAP: echo-m365 signed in as its admin account"
  rm -f "$HOME/.mg/mg.authrecord.tid-1.json"
  run "$SCRIPT" --status
  assert_open "Generate TAP: echo-m365 signed in as its admin account"
  rm -f "$MAC_SETUP_ECHO_M365/tenant.psd1"
  run "$SCRIPT" "--status"
  assert_open "Generate TAP: echo-m365 signed in as its admin account"
}

test_m365_admin_not_on_servers() {
  echo '{"username":"daily@example.com","tenantId":"tid-1"}' > "$HOME/.mg/mg.authrecord.tid-1.json"
  run "$SCRIPT_SERVER" --status
  assert_done "Generate TAP: echo-m365 signed in as its admin account"
}

test_manual_steps_start_open() {
  rm -rf "$XDG_STATE_HOME/mac-setup"
  run "$SCRIPT" --status
  assert_open "FileVault key saved to 1Password"; assert_open "Activation Lock code saved to 1Password"
  assert_open "Fusion signed in or activated"; assert_open "Claude signed in or activated"
  assert_open "Chrome signed in to your Google profile"; assert_open "1Password connected to the browser"
  assert_open "1Password Quick Access on Cmd+Shift+Space"; assert_open "AutoFill from 1Password only (Apple Passwords off)"
  assert_open "Stream Deck export restored"; assert_open "BetterDisplay export restored"
  assert_lacks "BetterMouse export restored"
  assert_open "Virtual machines moved"; assert_open "Ninja Remote Screen Recording approved"
  assert_open "First Ninja Backup run succeeded"; assert_done "Ninja Backup deployed to this Mac"
  assert_open "Raycast Cloud Sync on"; assert_open "Raycast script folder, MCP server and app list set"
  assert_open "Zoom video shortcut is ⌃⇧⌘V"; assert_open "Desktop widgets placed"
  assert_has "30 step(s) left"
}

test_workstation_apps_missing() {
  stub brew "case \"\$1 \$2\" in 'bundle check') case \"\$*\" in *Brewfile.workstation*) exit 1 ;; esac ;; --prefix*) echo $T/brew ;; esac; exit 0"
  run "$SCRIPT" --status
  assert_open "Workstation apps installed"; assert_done "Brewfile packages installed"
}

test_workstation_apps_skip_self_managed() {
  # bundle check passes only when brew-why's skip list reaches it.
  stub brew "case \"\$1 \$2\" in 'bundle check') case \"\$*\" in *Brewfile.workstation*) [ \"\$HOMEBREW_BUNDLE_CASK_SKIP\" = onedrive ] ;; esac ;; --prefix*) echo $T/brew ;; esac; exit 0"
  stub brew-why '[ "$1" = --skip ] && echo onedrive'
  run "$SCRIPT" --status
  assert_done "Workstation apps installed"
}

test_workstation_apps_help_has_brew_why() {
  stub brew "case \"\$1 \$2\" in 'bundle check') case \"\$*\" in *Brewfile.workstation*) exit 1 ;; esac ;; --prefix*) echo $T/brew ;; esac; exit 0"
  stub brew-why 'echo "utm: UTM 4.7.4 is installed outside Homebrew (cask: 5.0.9). To let Homebrew replace and manage it: brew install --cask --force utm"'
  printf 'q\n' > "$T/answers"
  MAC_SETUP_TTY="$T/answers" run "$SCRIPT"
  assert_has "    utm: UTM 4.7.4 is installed outside Homebrew"; assert_has "brew install --cask --force utm"
}

test_vendor_app_missing_lists_its_site() {
  rm -rf "$MAC_SETUP_APPS/HueForge.app"
  run "$SCRIPT" --status
  assert_open "HueForge installed"; assert_done "Festivitas installed"
  printf 'n\nq\n' > "$T/answers"
  MAC_SETUP_TTY="$T/answers" run "$SCRIPT"
  assert_has "Download it from https://shop.thehueforge.com/apps/download"
}

test_vendor_app_installs_from_download() {
  rm -rf "$MAC_SETUP_APPS/HueForge.app"
  touch "$MAC_SETUP_DOWNLOADS/HueForge_MacOS_v0.9.4.4.zip" "$MAC_SETUP_DOWNLOADS/HugeForgePlugin_MacOS_1.2.0.zip"
  # ditto: unzipping makes the app; copying copies it.
  stub ditto 'if [ "$1" = -x ]; then mkdir -p "$4/HueForge.app"; else cp -R "$1" "$2"; fi'
  printf 'y\n\nq\n' > "$T/answers"
  MAC_SETUP_TTY="$T/answers" run "$SCRIPT"
  assert_has "Found HueForge_MacOS_v0.9.4.4.zip in Downloads"
  [ -d "$MAC_SETUP_APPS/HueForge.app" ] || fail "HueForge.app wasn't installed"
}

test_vendor_pkg_download_uses_installer() {
  rm -rf "$MAC_SETUP_APPS/EXStar Hub.app"
  touch "$MAC_SETUP_DOWNLOADS/EXStar Hub_v2.1.0-11_Release.pkg"
  stub sudo "echo \"sudo \$*\" >> \"$T/sudo.log\""
  printf 'y\nq\n' > "$T/answers"
  MAC_SETUP_TTY="$T/answers" run "$SCRIPT"
  grep -q "installer -pkg $MAC_SETUP_DOWNLOADS/EXStar Hub_v2.1.0-11_Release.pkg" "$T/sudo.log" || fail "installer wasn't run on the pkg"
}

test_hueforge_plugins_step() {
  rm -f "$XDG_STATE_HOME/mac-setup/hueforge_plugins"
  run "$SCRIPT" --status
  assert_open "HueForge plugins installed (FlatForge, HugeForge)"
  run "$SCRIPT_SERVER" --status
  assert_lacks "○ HueForge plugins"
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

test_spacemouse_settings_differ() {
  stub 3dx-sync 'exit 1'
  run "$SCRIPT" --status
  assert_open "SpaceMouse settings applied"
  run "$SCRIPT_SERVER" --status
  assert_done "SpaceMouse settings applied"
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

test_widgets_step_opens_desktop_settings() {
  rm -f "$XDG_STATE_HOME/mac-setup/widgets"
  stub open "echo \"open \$*\" >> '$T/opened'"
  printf 'y\ny\n' > "$T/answers"
  MAC_SETUP_TTY="$T/answers" run "$SCRIPT"
  assert_has "Edit Widgets"; assert_has "All done."
  grep -q 'com.apple.Desktop-Settings.extension' "$T/opened" || fail "Desktop & Dock settings not opened"
  [ -f "$XDG_STATE_HOME/mac-setup/widgets" ] || fail "widgets not remembered"
}

test_server_skips_workstation_steps() {
  rm -rf "$MAC_SETUP_APPS"/*.app "$XDG_STATE_HOME/mac-setup/licences" "$XDG_STATE_HOME/mac-setup/widgets"
  stub defaults 'exit 1'
  stub mac-defaults 'echo "  Dock: dockutil not installed"; exit 1'
  stub brew "case \"\$*\" in *Brewfile.workstation*) exit 1 ;; --prefix) echo $T/brew ;; esac; exit 0"
  run "$SCRIPT_SERVER" --status
  assert_done "Workstation apps installed"; assert_done "HueForge installed"
  assert_done "gridfinity-studio installed"; assert_done "Slack signed in or activated"
  assert_done "Default browser is Chrome"
  assert_done "BetterTouchTool installed from folivora.ai"
  assert_done "macOS settings and Dock"; assert_done "Desktop widgets placed"
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
  # Two escrow items (Done? y each), then gh (Do it now? y, Enter to re-check).
  printf 'y\ny\ny\n\n' > "$T/answers"
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

test_profiles_lists_missing_terminal_privacy() {
  stub system_profiler 'printf "        macOS: Firewall:\n        macOS: NinjaOne privacy permissions:\n"'
  run "$SCRIPT" --status
  assert_open "MDM profiles installed"
}

test_hostname_uses_local_hostname() {
  stub scutil 'case "$2" in ComputerName) echo "Test Mac" ;; *) echo Test-Mac ;; esac'
  run "$SCRIPT" --status
  assert_done "Computer name is Test-Mac"
}

test_hostname_must_match() {
  stub scutil 'echo Old-Name'
  run "$SCRIPT" --status
  assert_open "Computer name is Test-Mac"
}

test_ssh_server_needs_listener_and_access_group() {
  run "$SCRIPT" --status
  assert_done "Remote Login on, for you only"
  stub nc 'exit 1'
  run "$SCRIPT" --status
  assert_open "Remote Login on, for you only"
  stub nc 'exit 0'; stub dsmemberutil 'echo "user is not a member of the group"'
  run "$SCRIPT" --status
  assert_open "Remote Login on, for you only"
}

test_ninja_backup_needs_lockhart() {
  rm -f "$MAC_SETUP_LOCKHART"
  run "$SCRIPT" --status
  assert_open "Ninja Backup deployed to this Mac"
  run "$SCRIPT_SERVER" --status
  assert_done "Ninja Backup deployed to this Mac"
}

test_chezmoi_stale_config_template() {
  stub chezmoi "case \"\$1\" in source-path) echo $T/src ;; verify) echo 'chezmoi: warning: config file template has changed, run chezmoi init to regenerate config file' >&2 ;; esac; exit 0"
  run "$SCRIPT" --status
  assert_open "Dotfiles applied"
}

test_per_item_confirmations_are_separate() {
  rm -f "$XDG_STATE_HOME/mac-setup/licences"
  printf 'n\ny\nq\n' > "$T/answers"
  MAC_SETUP_TTY="$T/answers" run "$SCRIPT"
  run "$SCRIPT" --status
  assert_done "Microsoft 365 (Office) signed in or activated"
  assert_open "Fantastical signed in or activated"
}

test_combined_confirmation_still_counts() {
  run "$SCRIPT" --status
  assert_done "FileVault key saved to 1Password"; assert_done "Stream Deck export restored"
  assert_done "LightBurn signed in or activated"
}

test_onedrive_must_be_signed_in() {
  rm -rf "$T/OneDrive"
  run "$SCRIPT" --status
  assert_open "OneDrive signed in (Unstable Studios)"
}

test_icloud_docs_needs_both_links() {
  run "$SCRIPT" --status
  assert_done "Desktop & Documents in iCloud"
  rm "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents"
  mkdir "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents"
  run "$SCRIPT" --status
  assert_open "Desktop & Documents in iCloud"
  run "$SCRIPT_SERVER" --status
  assert_done "Desktop & Documents in iCloud"
}

test_icloud_optimize_storage_must_be_off() {
  run "$SCRIPT" --status
  assert_done "iCloud keeps files downloaded"
  stub defaults 'case "$*" in *com.apple.bird*) echo 1 ;; *) printf "    {\n        LSHandlerRoleAll = \"com.google.chrome\";\n        LSHandlerURLScheme = http;\n    },\n" ;; esac'
  run "$SCRIPT" --status
  assert_open "iCloud keeps files downloaded"
  run "$SCRIPT_SERVER" --status
  assert_done "iCloud keeps files downloaded"
}

test_license_confirmations_saved_as_licence_still_count() {
  rm -f "$XDG_STATE_HOME/mac-setup/licences"
  mark_done licence_Slack
  run "$SCRIPT" --status
  assert_done "Slack signed in or activated"; assert_open "Claude signed in or activated"
}

test_time_machine_needs_a_destination() {
  run "$SCRIPT" --status
  assert_done "Time Machine backs up to echo-nas"
  stub tmutil 'echo "tmutil: No destinations configured."'
  run "$SCRIPT" --status
  assert_open "Time Machine backs up to echo-nas"
  run "$SCRIPT_SERVER" --status
  assert_done "Time Machine backs up to echo-nas"
}

test_vms_must_be_excluded_from_time_machine() {
  run "$SCRIPT" --status
  assert_done "Virtual machines kept out of Time Machine"
  mkdir -p "$HOME/Parallels"
  stub tmutil 'case "$1" in isexcluded) echo "[Included]  $2" ;; *) echo "Name          : backups" ;; esac'
  run "$SCRIPT" --status
  assert_open "Virtual machines kept out of Time Machine"
  run "$SCRIPT_SERVER" --status
  assert_done "Virtual machines kept out of Time Machine"
}

test_time_machine_action_uses_1password_and_clipboard() {
  export MAC_SETUP_CLIP_SECONDS=0
  stub tmutil "case \"\$1\" in destinationinfo) [ -f $T/tm-set ] && echo 'Name          : backups' || echo 'tmutil: No destinations configured.' ;; isexcluded) echo \"[Excluded]  \$2\" ;; esac; exit 0"
  stub op 'case "$1 $2" in "account list") echo "[{\"user_uuid\": \"U1\"}]" ;; "item get") case "$*" in *label=username*) echo nasuser ;; *label=password*) echo s3cret ;; esac ;; *) echo "URL ACCOUNT" ;; esac'
  stub pbcopy "cat >> $T/clipboard"
  stub sudo "echo \"\$*\" >> $T/sudo-args; touch $T/tm-set"
  printf 'y\n\n' > "$T/answers"
  MAC_SETUP_TTY="$T/answers" run "$SCRIPT"
  assert_has "Automatic backups on; first backup started."
  grep -q 's3cret' "$T/clipboard" || fail "password not put on the clipboard"
  grep -q 'smb://nasuser@echo-nas/backups' "$T/sudo-args" || fail "destination not set with the 1Password user"
  ! grep -q 's3cret' "$T/sudo-args" || fail "password on the sudo command line"
}

test_time_machine_needs_automatic_backups_on() {
  stub defaults 'case "$*" in *tm-prefs*AutoBackup*) echo 0 ;; *) printf "    {\n        LSHandlerRoleAll = \"com.google.chrome\";\n        LSHandlerURLScheme = http;\n    },\n" ;; esac'
  run "$SCRIPT" --status
  assert_open "Time Machine backs up to echo-nas"
  stub sudo "echo \"\$*\" >> $T/sudo-args"
  printf 'y\n\n' > "$T/answers"
  MAC_SETUP_TTY="$T/answers" run "$SCRIPT"
  assert_has "Automatic backups on."
  grep -q '^tmutil enable' "$T/sudo-args" || fail "tmutil enable not run"
}

test_replaced_apps_must_be_gone() {
  run "$SCRIPT" --status
  assert_done "Replaced apps removed"
  mkdir -p "$MAC_SETUP_APPS/Rectangle.app"
  run "$SCRIPT" --status
  assert_open "Replaced apps removed"
  run "$SCRIPT_SERVER" --status
  assert_done "Replaced apps removed"
}

test_replaced_casks_must_be_uninstalled() {
  mkdir -p "$T/brew/Caskroom/docker-desktop"
  run "$SCRIPT" --status
  assert_open "Replaced apps removed"
  printf 'q\n' > "$T/answers"
  MAC_SETUP_TTY="$T/answers" run "$SCRIPT"
  assert_has "brew uninstall --cask docker-desktop"
  assert_lacks "does the job of: ."
}

test_colima_and_ollama_must_run() {
  run "$SCRIPT" --status
  assert_done "Docker engine (Colima) runs at login"
  assert_done "Ollama server runs at login"
  stub colima 'exit 1'
  stub ollama 'exit 1'
  run "$SCRIPT" --status
  assert_open "Docker engine (Colima) runs at login"
  assert_open "Ollama server runs at login"
  run "$SCRIPT_SERVER" --status
  assert_done "Docker engine (Colima) runs at login"
}

test_colima_running_but_not_at_login() {
  # A one-off `colima start` runs, but nothing starts it at login.
  stub brew "case \"\$1\" in --prefix) echo $T/brew ;; services) echo '[{\"name\": \"colima\", \"registered\": false}]' ;; *) exit 0 ;; esac"
  run "$SCRIPT" --status
  assert_open "Docker engine (Colima) runs at login"
}

test_claude_ha_steps() {
  run "$SCRIPT" --status
  assert_done "Claude Code reports sessions to Home Assistant"
  assert_done "Home Assistant MCP server in Claude Code"
  rm "$HOME/.config/claude-ha/webhook-url"; stub security 'exit 44'
  run "$SCRIPT" --status
  assert_open "Claude Code reports sessions to Home Assistant"
  assert_open "Home Assistant MCP server in Claude Code"
  run "$SCRIPT_SERVER" --status
  assert_done "Claude Code reports sessions to Home Assistant"
}

test_claude_code_memories_restored() {
  run "$SCRIPT" --status
  assert_done "Claude Code export restored"
  rm -rf "$HOME/.claude/projects"
  run "$SCRIPT" --status
  assert_open "Claude Code export restored"
  mark_done "export_Claude_Code"
  run "$SCRIPT" --status
  assert_done "Claude Code export restored"
}

test_btt_window_snapping_must_be_on() {
  run "$SCRIPT" --status
  assert_done "BetterTouchTool window snapping on"
  stub defaults 'case "$*" in *windowSnappingEnabled*) echo 0 ;; *) printf "    {\n        LSHandlerRoleAll = \"com.google.chrome\";\n        LSHandlerURLScheme = http;\n    },\n" ;; esac'
  run "$SCRIPT" --status
  assert_open "BetterTouchTool window snapping on"
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
