#!/usr/bin/env python3
"""Tests for app-prefs, with a fake `defaults` and `lsappinfo`. Standard library only:
    python3 -I tests/app_prefs_test.py
Also guards the committed macos/prefs: every saved key is allow-listed and nothing in
them looks like a licence, token or email address (the repo is public)."""
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
# fake lsappinfo: apps listed in $FAKE_RUNNING are running
id="${2#bundleid=}"
case " ${FAKE_RUNNING:-} " in *" $id "*) echo "ASN:0x0-0x1-\\"$id\\":" ;; esac
"""


class AppPrefs(unittest.TestCase):
    def setUp(self):
        self.t = tempfile.mkdtemp()
        self.prefs = os.path.join(self.t, "prefs")      # the Mac's settings
        self.repo = os.path.join(self.t, "repo")        # macos/prefs
        self.bin = os.path.join(self.t, "bin")
        for d in (self.prefs, self.repo, self.bin):
            os.makedirs(d)
        for name, body in (("defaults", FAKE_DEFAULTS), ("lsappinfo", FAKE_LSAPPINFO)):
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
        self.mac("com.example.app", {"showIcons": True, "layout": {"a": 1}, "licence": "SECRET-123"})
        r = self.run_tool("export")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.saved("com.example.app"), {"showIcons": True, "layout": {"a": 1}})
        self.assertNotIn("SECRET-123", r.stdout)
        self.assertIn("saved 2 of 3 keys", r.stdout)

    def test_apply_merges_and_keeps_local_licence(self):
        self.mac("com.example.app", {"showIcons": True, "layout": {"a": 1}})
        self.run_tool("export")
        self.mac("com.example.app", {"licence": "NEW-MAC", "showIcons": False})
        r = self.run_tool("apply")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.read_mac("com.example.app"),
                         {"licence": "NEW-MAC", "showIcons": True, "layout": {"a": 1}})

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
