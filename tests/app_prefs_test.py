#!/usr/bin/env python3
"""Tests for app-prefs, with a fake `defaults` and `lsappinfo`. Standard library only:
    python3 -I tests/app_prefs_test.py
Also guards the committed macos/prefs: every saved key is allow-listed and nothing in
them looks like a license, token or email address (the repo is public)."""
import glob
import os
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TOOL = os.path.join(ROOT, "dot_local", "bin", "executable_app-prefs")

FAKE_DEFAULTS = """#!/bin/sh
# fake defaults: domains are plist files in $FAKE_PREFS
f="$FAKE_PREFS/$2.plist"
case "$1" in
  export) [ -f "$f" ] && cat "$f" || exit 1 ;;
  import) cat > "$f" ;;
esac
"""
FAKE_LSAPPINFO = """#!/bin/sh
# fake lsappinfo: apps listed in $FAKE_RUNNING (or the file $FAKE_RUN_FILE) are running
id="${2#bundleid=}"
run="${FAKE_RUNNING:-}"; [ -n "${FAKE_RUN_FILE:-}" ] && run="$(cat "$FAKE_RUN_FILE")"
case " $run " in *" $id "*) echo "ASN:0x0-0x1-\\"$id\\":" ;; esac
"""
# fake osascript: "quit" empties $FAKE_RUN_FILE unless $FAKE_STUBBORN is set
FAKE_OSASCRIPT = """#!/bin/sh
echo "$2" >> "$FAKE_OPENED.osascript"
[ -n "${FAKE_DENIED:-}" ] && { echo "Not authorized to send Apple events (-1743)" >&2; exit 1; }
[ -n "${FAKE_STUBBORN:-}" ] || : > "$FAKE_RUN_FILE"
"""
# fake open: records the bundle id it was asked to open
FAKE_OPEN = """#!/bin/sh
echo "$@" >> "$FAKE_OPENED"
"""


class AppPrefs(unittest.TestCase):
    def setUp(self):
        self.t = tempfile.mkdtemp()
        self.prefs = os.path.join(self.t, "prefs")      # the Mac's settings
        self.repo = os.path.join(self.t, "repo")        # macos/prefs
        self.bin = os.path.join(self.t, "bin")
        for d in (self.prefs, self.repo, self.bin):
            os.makedirs(d)
        for name, body in (("defaults", FAKE_DEFAULTS), ("lsappinfo", FAKE_LSAPPINFO),
                           ("osascript", FAKE_OSASCRIPT), ("open", FAKE_OPEN)):
            p = os.path.join(self.bin, name)
            with open(p, "w") as f:
                f.write(body)
            os.chmod(p, 0o755)
        with open(os.path.join(self.repo, "allowlist"), "w") as f:
            f.write("# test\ncom.example.app\tshow*\ncom.example.app\tlayout\n")
        self.env = dict(os.environ, PATH=self.bin + os.pathsep + os.environ["PATH"],
                        APP_PREFS_DIR=self.repo, FAKE_PREFS=self.prefs, FAKE_RUNNING="")

    def tearDown(self):
        shutil.rmtree(self.t)

    def mac(self, domain, data):
        with open(os.path.join(self.prefs, domain + ".plist"), "wb") as f:
            plistlib.dump(data, f)

    def read_mac(self, domain):
        with open(os.path.join(self.prefs, domain + ".plist"), "rb") as f:
            return plistlib.load(f)

    def saved(self, domain):
        with open(os.path.join(self.repo, domain + ".plist"), "rb") as f:
            return plistlib.load(f)

    def run_tool(self, *args, **env):
        e = dict(self.env, **env)
        return subprocess.run([sys.executable, "-I", TOOL, *args], env=e, capture_output=True, text=True)

    def test_export_keeps_only_allowlisted_keys(self):
        self.mac("com.example.app", {"showIcons": True, "layout": {"a": 1}, "license": "SECRET-123"})
        r = self.run_tool("export")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.saved("com.example.app"), {"showIcons": True, "layout": {"a": 1}})
        self.assertNotIn("SECRET-123", r.stdout)
        self.assertIn("saved 2 of 3 keys", r.stdout)

    def test_apply_merges_and_keeps_local_license(self):
        self.mac("com.example.app", {"showIcons": True, "layout": {"a": 1}})
        self.run_tool("export")
        self.mac("com.example.app", {"license": "NEW-MAC", "showIcons": False})
        r = self.run_tool("apply")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.read_mac("com.example.app"),
                         {"license": "NEW-MAC", "showIcons": True, "layout": {"a": 1}})

    def test_apply_creates_missing_domain(self):
        self.mac("com.example.app", {"layout": [1, 2]})
        self.run_tool("export")
        os.remove(os.path.join(self.prefs, "com.example.app.plist"))
        self.run_tool("apply")
        self.assertEqual(self.read_mac("com.example.app"), {"layout": [1, 2]})

    def test_apply_skips_running_app(self):
        self.mac("com.example.app", {"showIcons": True})
        self.run_tool("export")
        self.mac("com.example.app", {"showIcons": False})
        r = self.run_tool("apply", FAKE_RUNNING="com.example.app")
        self.assertEqual(r.returncode, 1)
        self.assertIn("app is running", r.stdout)
        self.assertEqual(self.read_mac("com.example.app"), {"showIcons": False})

    def running_file(self, ids):
        p = os.path.join(self.t, "running")
        with open(p, "w") as f:
            f.write(ids)
        return p

    def test_apply_restart_quits_applies_and_reopens(self):
        self.mac("com.example.app", {"showIcons": True})
        self.run_tool("export")
        self.mac("com.example.app", {"showIcons": False})
        opened = os.path.join(self.t, "opened")
        r = self.run_tool("apply", "--restart", FAKE_RUN_FILE=self.running_file("com.example.app"), FAKE_OPENED=opened)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(self.read_mac("com.example.app"), {"showIcons": True})
        with open(opened) as f:
            self.assertIn("com.example.app", f.read())
        with open(opened + ".osascript") as f:
            self.assertIn('tell application id "com.example.app" to quit', f.read())

    def test_apply_restart_leaves_stopped_app_closed(self):
        self.mac("com.example.app", {"showIcons": True})
        self.run_tool("export")
        self.mac("com.example.app", {"showIcons": False})
        opened = os.path.join(self.t, "opened")
        r = self.run_tool("apply", "--restart", FAKE_RUN_FILE=self.running_file(""), FAKE_OPENED=opened)
        self.assertEqual(r.returncode, 0)
        self.assertEqual(self.read_mac("com.example.app"), {"showIcons": True})
        self.assertFalse(os.path.exists(opened))
        self.assertFalse(os.path.exists(opened + ".osascript"))

    def test_apply_restart_reports_denied_automation(self):
        self.mac("com.example.app", {"showIcons": True})
        self.run_tool("export")
        self.mac("com.example.app", {"showIcons": False})
        r = self.run_tool("apply", "--restart", FAKE_RUN_FILE=self.running_file("com.example.app"),
                          FAKE_DENIED="1", FAKE_OPENED=os.path.join(self.t, "opened"))
        self.assertEqual(r.returncode, 1)
        self.assertIn("-1743", r.stdout)
        self.assertEqual(self.read_mac("com.example.app"), {"showIcons": False})

    def test_apply_restart_leaves_matching_app_running(self):
        self.mac("com.example.app", {"showIcons": True})
        self.run_tool("export")
        opened = os.path.join(self.t, "opened")
        r = self.run_tool("apply", "--restart", FAKE_RUN_FILE=self.running_file("com.example.app"), FAKE_OPENED=opened)
        self.assertEqual(r.returncode, 0)
        self.assertIn("already matches", r.stdout)
        self.assertFalse(os.path.exists(opened))

    def test_apply_restart_skips_app_that_wont_quit(self):
        self.mac("com.example.app", {"showIcons": True})
        self.run_tool("export")
        self.mac("com.example.app", {"showIcons": False})
        r = self.run_tool("apply", "--restart", FAKE_RUN_FILE=self.running_file("com.example.app"),
                          FAKE_STUBBORN="1", APP_PREFS_QUIT_WAIT="1", FAKE_OPENED=os.path.join(self.t, "opened"))
        self.assertEqual(r.returncode, 1)
        self.assertIn("didn't quit", r.stdout)
        self.assertEqual(self.read_mac("com.example.app"), {"showIcons": False})

    def test_check_and_diff_name_keys_not_values(self):
        self.mac("com.example.app", {"showIcons": True, "layout": "wide"})
        self.run_tool("export")
        self.assertEqual(self.run_tool("check").returncode, 0)
        self.mac("com.example.app", {"showIcons": True, "layout": "narrow"})
        self.assertEqual(self.run_tool("check").returncode, 1)
        r = self.run_tool("diff")
        self.assertIn("com.example.app: layout", r.stdout)
        self.assertNotIn("narrow", r.stdout)
        self.assertNotIn("wide", r.stdout)

    def test_apply_ignores_keys_dropped_from_allowlist(self):
        with open(os.path.join(self.repo, "com.example.app.plist"), "wb") as f:
            plistlib.dump({"showIcons": True, "secretThing": "x"}, f)
        self.mac("com.example.app", {})
        self.run_tool("apply")
        self.assertEqual(self.read_mac("com.example.app"), {"showIcons": True})

    # ---- BetterMouse: nested binary plists, flat key/value maps, one entry per device ----
    BM = "com.naotanhaocan.BetterMouse"

    def bm_mice(self, *mice):
        return plistlib.dumps({"mice": list(mice)}, fmt=plistlib.FMT_BINARY)

    def mouse(self, product, speed, order=1):
        tw = [{"HScroll": {}}, speed, {"VScroll": {}}, 1.0]
        if order < 0:
            tw = tw[2:] + tw[:2]
        return {"name": {"product": product, "vendor": "Logitech"}, "twSpeed": tw}

    def bm_setup(self):
        with open(os.path.join(self.repo, "allowlist"), "a") as f:
            f.write(f"{self.BM}\tmice\n")

    def test_bettermouse_reordered_maps_and_devices_match(self):
        self.bm_setup()
        self.mac(self.BM, {"mice": self.bm_mice(self.mouse("MX", 1.7), self.mouse("MX-BT", 1.0))})
        self.run_tool("export")
        # BetterMouse saves the same settings with maps and devices in another order.
        self.mac(self.BM, {"mice": self.bm_mice(self.mouse("MX-BT", 1.0, -1), self.mouse("MX", 1.7, -1))})
        self.assertEqual(self.run_tool("check").returncode, 0, self.run_tool("diff").stdout)

    def test_bettermouse_device_only_here_is_ignored_and_kept(self):
        self.bm_setup()
        self.mac(self.BM, {"mice": self.bm_mice(self.mouse("MX", 1.7))})
        self.run_tool("export")
        # A new connection adds a device here; check passes, apply keeps it.
        self.mac(self.BM, {"mice": self.bm_mice(self.mouse("MX", 1.7), self.mouse("MX-BT", 3.0))})
        self.assertEqual(self.run_tool("check").returncode, 0)
        self.mac(self.BM, {"mice": self.bm_mice(self.mouse("MX", 9.0), self.mouse("MX-BT", 3.0))})
        self.assertEqual(self.run_tool("check").returncode, 1)
        self.assertEqual(self.run_tool("apply").returncode, 0)
        mice = plistlib.loads(self.read_mac(self.BM)["mice"])["mice"]
        self.assertEqual([m["name"]["product"] for m in mice], ["MX", "MX-BT"])
        self.assertEqual(mice[0]["twSpeed"][1], 1.7)
        self.assertEqual(mice[1]["twSpeed"][1], 3.0)
        self.assertEqual(self.run_tool("check").returncode, 0)

    def bm_check_after(self, saved_mice, here_mice):
        self.bm_setup()
        self.mac(self.BM, {"mice": self.bm_mice(*saved_mice)})
        self.run_tool("export")
        self.mac(self.BM, {"mice": self.bm_mice(*here_mice)})
        return self.run_tool("check").returncode

    def test_bettermouse_reordered_button_map_matches(self):
        def items(btn):
            return {"appitems": plistlib.dumps({"apps": [{"btn": btn}]}, fmt=plistlib.FMT_BINARY)}
        with open(os.path.join(self.repo, "allowlist"), "a") as f:
            f.write(f"{self.BM}\tappitems\n")
        click, back = [0, [{"Click": {}}, 1]], [0, [{"Back": {}}, 2]]
        self.mac(self.BM, items([10, click, 11, back]))
        self.run_tool("export")
        self.mac(self.BM, items([11, back, 10, click]))
        self.assertEqual(self.run_tool("check").returncode, 0, self.run_tool("diff").stdout)
        # The same mapping saved with its dict keys in another order still matches.
        self.mac(self.BM, items([10, [0, [{"x": 1, "y": 2}, 1]], 11, back]))
        self.run_tool("export")
        self.mac(self.BM, items([11, back, 10, [0, [{"y": 2, "x": 1}, 1]]]))
        self.assertEqual(self.run_tool("check").returncode, 0, self.run_tool("diff").stdout)
        self.mac(self.BM, items([11, click, 10, [0, [{"y": 2, "x": 1}, 1]]]))
        self.assertEqual(self.run_tool("check").returncode, 1)

    def test_bettermouse_other_lists_keep_their_order(self):
        a = {"name": {"product": "MX"}, "pattern": [1, 2, 3, 4]}
        b = {"name": {"product": "MX"}, "pattern": [3, 4, 1, 2]}
        self.assertEqual(self.bm_check_after([a], [b]), 1)

    def test_bettermouse_same_name_entries_match_themselves(self):
        bolt = {"name": {"product": "MX"}, "via": "bolt"}
        bt = {"name": {"product": "MX"}, "via": "bt"}
        self.assertEqual(self.bm_check_after([bolt, bt], [bt, bolt]), 0)
        self.assertEqual(self.bm_check_after([bolt, bt], [bolt, {"name": {"product": "MX"}, "via": "usb"}]), 1)

    def test_bettermouse_unnamed_devices_are_kept(self):
        self.bm_setup()
        self.mac(self.BM, {"mice": self.bm_mice({"v": 1}, {"v": 2})})
        self.run_tool("export")
        self.mac(self.BM, {"mice": self.bm_mice({"v": 3})})
        self.assertEqual(self.run_tool("check").returncode, 1)
        self.run_tool("apply")
        mice = plistlib.loads(self.read_mac(self.BM)["mice"])["mice"]
        self.assertEqual(mice, [{"v": 3}, {"v": 1}, {"v": 2}])
        self.assertEqual(self.run_tool("check").returncode, 0)

    def test_other_apps_compare_nested_data_as_bytes(self):
        self.mac("com.example.app", {"layout": plistlib.dumps({"a": 1}, fmt=plistlib.FMT_BINARY)})
        self.run_tool("export")
        self.mac("com.example.app", {"layout": plistlib.dumps({"a": 1.0}, fmt=plistlib.FMT_BINARY)})
        self.assertEqual(self.run_tool("check").returncode, 1)

    def test_order_still_matters_for_other_apps(self):
        self.mac("com.example.app", {"layout": [1, 2, 3, 4]})
        self.run_tool("export")
        self.mac("com.example.app", {"layout": [3, 4, 1, 2]})
        self.assertEqual(self.run_tool("check").returncode, 1)

    def test_unknown_domain_is_an_error(self):
        r = self.run_tool("export", "com.not.listed")
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("not in the allowlist", r.stderr)

    def test_source_dir_from_chezmoi_env(self):
        # Inside `chezmoi apply`, CHEZMOI_SOURCE_DIR is the only reliable way to the repo.
        src = os.path.join(self.t, "src")
        os.makedirs(os.path.join(src, "macos"))
        shutil.copytree(self.repo, os.path.join(src, "macos", "prefs"))
        self.mac("com.example.app", {"showIcons": True})
        env = {k: v for k, v in self.env.items() if k != "APP_PREFS_DIR"}
        r = subprocess.run([sys.executable, "-I", TOOL, "export"], env=dict(env, CHEZMOI_SOURCE_DIR=src),
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue(os.path.exists(os.path.join(src, "macos", "prefs", "com.example.app.plist")))

    def test_missing_allowlist_is_a_clear_error(self):
        os.remove(os.path.join(self.repo, "allowlist"))
        r = self.run_tool("check")
        self.assertEqual(r.returncode, 2)
        self.assertIn("no allowlist at", r.stderr)
        self.assertNotIn("Traceback", r.stderr)

    def test_allowlist_line_needs_a_tab(self):
        with open(os.path.join(self.repo, "allowlist"), "w") as f:
            f.write("com.example.app showIcons\n")
        r = self.run_tool("check")
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("domain<TAB>pattern", r.stderr)


class CommittedPrefs(unittest.TestCase):
    """The saved settings in the repo are public: guard what goes in."""
    SECRET = re.compile(rb"licen[cs]e|paddle|purchase|receipt|serial|token|password|apikey|api_key|"
                        rb"[\w.+-]+@[\w-]+\.[a-z]{2,}", re.I)
    PREFS = os.path.join(ROOT, "macos", "prefs")

    def rules(self):
        out = {}
        with open(os.path.join(self.PREFS, "allowlist")) as f:
            for line in f:
                if line.strip() and not line.startswith("#"):
                    d, _, p = line.rstrip("\n").partition("\t")
                    out.setdefault(d, []).append(p)
        return out

    def test_saved_keys_are_allowlisted(self):
        import fnmatch
        rules = self.rules()
        for path in glob.glob(os.path.join(self.PREFS, "*.plist")):
            domain = os.path.basename(path)[:-len(".plist")]
            self.assertIn(domain, rules, f"{domain} has saved settings but no allowlist entry")
            with open(path, "rb") as f:
                for key in plistlib.load(f):
                    self.assertTrue(any(fnmatch.fnmatchcase(key, p) for p in rules[domain]),
                                    f"{domain}: {key} is saved but not allow-listed")

    def test_saved_settings_have_no_secret_like_content(self):
        # Allowed: menu bar item ids in Bartender's profile for the 1Password and Passwords apps.
        allowed = re.compile(rb"com\.1password\.1password[\w.-]*|com\.apple\.Passwords[\w.-]*", re.I)
        for path in glob.glob(os.path.join(self.PREFS, "*.plist")):
            with open(path, "rb") as f:
                raw = allowed.sub(b"", f.read())
            with open(path, "rb") as f:
                data = plistlib.load(f)
            blobs = b"".join(v for v in data.values() if isinstance(v, bytes))
            for chunk in (raw, allowed.sub(b"", blobs)):
                m = self.SECRET.search(chunk)
                # Report where, never what: a CI log is public too.
                if m:  # self.fail, not assertIsNone, which would print the match itself
                    self.fail(f"{os.path.basename(path)}: secret-like content at byte {m.start()}")


if __name__ == "__main__":
    unittest.main(verbosity=1)
