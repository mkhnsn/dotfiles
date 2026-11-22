#!/usr/bin/env python3
"""streamdeck-library: indexes a library folder into library.json and checks it.
Standard library only:  python3 -I tests/streamdeck_library_test.py"""
import json
import os
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOL = os.path.join(ROOT, "dot_local", "bin", "executable_streamdeck-library")

PROFILES = [
    "Individual Profiles/Outlook (New)/Profiles/Mac/Outlook New Plain, Stream Deck XL.streamDeckProfile",
    "Profiles/Win/Slack Dark, StreamDeckNeo.streamDeckProfile",
    "Profiles/Mac/iTerm2 Brand, Galleon 100 SD.streamDeckProfile",
    "Profiles/Mac/Claude Code Plain, Stream Deck +.streamDeckProfile",
    "Google Chrome Profiles 1.1/Profiles/Windows/Google Chrome SD+ Windows.streamDeckProfile",
    "Blender Pro Stream Deck V5/Stream Deck Profiles/Blender Pro SD MK V5.streamDeckProfile",
    "Fusion 360 Pro/Profiles/XL Light Labelled/Fusion 360 Pro XL Labelled Light.streamDeckProfile",
    "__MACOSX/Profiles/Mac/._x.streamDeckProfile",
]
WANT = [  # sorted by path, as the tool lists them
    ("Blender Pro", None, "standard", "mac"),
    ("Fusion 360 Pro", "labelled-light", "xl", "mac"),
    ("Google Chrome", None, "plus", "win"),
    ("Outlook New", "plain", "xl", "mac"),
    ("Claude Code", "plain", "plus", "mac"),
    ("iTerm2", "brand", "galleon", "mac"),
    ("Slack", "dark", "neo", "win"),
]


class Library(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = self.tmp.name
        os.makedirs(os.path.join(self.dir, "packs", "adx"))
        os.makedirs(os.path.join(self.dir, "plugins", "acme"))
        with zipfile.ZipFile(os.path.join(self.dir, "packs", "adx", "office-3.zip"), "w") as z:
            for p in PROFILES:
                z.writestr(p, "profile")
            z.writestr("README.txt", "not a profile")
        with open(os.path.join(self.dir, "plugins", "acme", "com.acme.tool-1.0.streamDeckPlugin"), "w") as f:
            f.write("plugin")

    def tearDown(self):
        self.tmp.cleanup()

    def run_tool(self, *args):
        return subprocess.run([sys.executable, "-I", TOOL, *args, "--dir", self.dir],
                              capture_output=True, text=True)

    def index(self):
        with open(os.path.join(self.dir, "library.json")) as f:
            return json.load(f)

    def test_build_indexes_packs_and_plugins(self):
        r = self.run_tool("build")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("new: packs/adx/office-3.zip", r.stdout)
        d = self.index()
        pack = d["packs"][0]
        self.assertEqual((pack["id"], pack["vendor"], pack["version"]), ("office", "adx", "3"))
        got = [(v["app"], v["style"], v["device"], v["platform"]) for v in pack["variants"]]
        self.assertEqual(sorted(got), sorted(WANT))
        self.assertEqual(len(d["plugins"]), 1)
        self.assertEqual(len(d["plugins"][0]["sha256"]), 64)

    def test_rebuild_keeps_hand_fields_and_drops_missing(self):
        self.run_tool("build")
        d = self.index()
        d["packs"][0]["title"] = "Office pack"
        d["packs"][0]["installed"] = "XL: Outlook"
        with open(os.path.join(self.dir, "library.json"), "w") as f:
            json.dump(d, f)
        os.remove(os.path.join(self.dir, "plugins", "acme", "com.acme.tool-1.0.streamDeckPlugin"))
        r = self.run_tool("build")
        self.assertIn("gone: plugins/acme/com.acme.tool-1.0.streamDeckPlugin", r.stdout)
        d = self.index()
        self.assertEqual((d["packs"][0]["title"], d["packs"][0]["installed"]), ("Office pack", "XL: Outlook"))
        self.assertEqual(d["plugins"], [])

    def test_rebuild_keeps_variant_order_and_skips_non_zips(self):
        self.run_tool("build")
        d = self.index()
        d["packs"][0]["variants"].reverse()
        with open(os.path.join(self.dir, "library.json"), "w") as f:
            json.dump(d, f)
        with open(os.path.join(self.dir, "packs", "adx", "notes-1.txt"), "w") as f:
            f.write("not a zip")
        r = self.run_tool("build")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("not a zip: packs/adx/notes-1.txt", r.stdout)
        self.assertEqual(self.index()["packs"][0]["variants"], d["packs"][0]["variants"])

    def test_extract_copies_matching_mac_variants(self):
        self.run_tool("build")
        out = os.path.join(self.dir, "out")
        r = self.run_tool("extract", "office", "--app", "outlook new", "--out", out)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(os.listdir(out), ["Outlook New Plain, Stream Deck XL.streamDeckProfile"])
        r = self.run_tool("extract", "office", "--app", "Outlook New", "--style", "Plain", "--out", out)
        self.assertIn("would overwrite", r.stderr)  # already extracted above
        r = self.run_tool("extract", "office", "--device", "mini", "--out", out)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("nothing in office", r.stderr)

    def test_check_without_index_fails(self):
        self.assertNotEqual(self.run_tool("check").returncode, 0)

    def test_check_finds_changed_and_missing_files(self):
        self.run_tool("build")
        self.assertEqual(self.run_tool("check").returncode, 0)
        with open(os.path.join(self.dir, "plugins", "acme", "com.acme.tool-1.0.streamDeckPlugin"), "a") as f:
            f.write("!")
        r = self.run_tool("check")
        self.assertEqual(r.returncode, 1)
        self.assertIn("changed: plugins/acme/", r.stdout)
        os.remove(os.path.join(self.dir, "packs", "adx", "office-3.zip"))
        self.assertIn("missing: packs/adx/office-3.zip", self.run_tool("check").stdout)


if __name__ == "__main__":
    unittest.main()
