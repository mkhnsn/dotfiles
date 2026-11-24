#!/usr/bin/env python3
"""Tests for brew-why, with synthetic casks and a fake Applications folder.
Standard library only:  python3 -I tests/brew_why_test.py"""
import importlib.machinery
import importlib.util
import os
import plistlib
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
TOOL = os.path.join(os.path.dirname(HERE), "dot_local", "bin", "executable_brew-why")
loader = importlib.machinery.SourceFileLoader("brew_why", TOOL)
spec = importlib.util.spec_from_loader("brew_why", loader)
bw = importlib.util.module_from_spec(spec)
loader.exec_module(bw)


def app(apps, name, version=None):
    contents = os.path.join(apps, name + ".app", "Contents")
    os.makedirs(contents)
    if version is not None:
        with open(os.path.join(contents, "Info.plist"), "wb") as f:
            plistlib.dump({"CFBundleShortVersionString": version}, f)


def cask(token, version, app_name=None, deletes=None, name=None, suite=None):
    arts = []
    if suite:
        arts.append({"suite": [suite], "target": "/Applications/" + suite})
    if app_name:
        arts.append({"app": [app_name + ".app"]})
    if deletes:
        arts.append({"uninstall": [{"delete": deletes}]})
    return {"token": token, "version": version, "name": [name or token], "artifacts": arts}


class Explain(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.apps = self.tmp.name
        os.environ["BREW_WHY_APPS"] = self.apps

    def tearDown(self):
        self.tmp.cleanup()

    def why(self, c):
        return bw.explain(c["token"], c, "Brewfile.workstation")[1]

    def skip(self, c):
        return bw.explain(c["token"], c, "Brewfile.workstation")[0]

    def test_older_copy_suggests_force(self):
        app(self.apps, "UTM", "4.7.4")
        line = self.why(cask("utm", "5.0.9-2", "UTM"))
        self.assertIn("UTM 4.7.4 is installed outside Homebrew (cask: 5.0.9-2)", line)
        self.assertIn("brew install --cask --force utm", line)
        self.assertIn('remove cask "utm" from Brewfile.workstation', line)

    def test_newer_copy_never_suggests_force(self):
        app(self.apps, "xTool Studio", "1.10.21")
        line = self.why(cask("xtool-studio", "1.2.11,121,abc", "xTool Studio"))
        self.assertIn("newer than the cask (1.2.11)", line)
        self.assertNotIn("--force", line)
        self.assertTrue(self.skip(cask("xtool-studio", "1.2.11", "xTool Studio")))

    def test_same_version_suggests_adopt(self):
        app(self.apps, "Blender", "5.3.0")
        self.assertIn("brew install --cask --adopt blender", self.why(cask("blender", "5.3.0", "Blender")))

    def test_unknown_version_suggests_force(self):
        app(self.apps, "LightBurn", "{APP_VERSION}")
        line = self.why(cask("lightburn", "2.2.01", "LightBurn"))
        self.assertIn("LightBurn is installed outside Homebrew (cask: 2.2.01)", line)
        self.assertIn("--force lightburn", line)

    def test_installer_package_found_via_uninstall_paths(self):
        app(self.apps, "Autodesk Fusion Service Utility")
        app(self.apps, "Autodesk Fusion")
        c = cask("autodesk-fusion", "latest", deletes=[os.path.join(self.apps, "Autodesk Fusion Service Utility.app"),
                                                         os.path.join(self.apps, "Autodesk Fusion.app")], name="Autodesk Fusion 360")
        line = self.why(c)
        self.assertTrue(line.startswith("autodesk-fusion: Autodesk Fusion is installed by its own installer"), line)
        self.assertNotIn("--force", line)
        self.assertTrue(self.skip(c), "installer apps that update themselves are skipped here")

    def test_suite_cask_finds_the_app_in_its_folder(self):
        kicad = cask("kicad", "10.0.8", suite="KiCad", name="KiCad")
        self.assertIn("not installed. Install it: brew install --cask kicad", self.why(kicad))
        app(self.apps, "KiCad/Bitmap2Component", "9.0.2")
        app(self.apps, "KiCad/KiCad", "9.0.2")
        line = self.why(kicad)
        self.assertIn("KiCad 9.0.2 is installed outside Homebrew (cask: 10.0.8)", line)
        self.assertIn("brew install --cask --force kicad", line)
        self.assertFalse(self.skip(kicad))
        self.assertTrue(self.skip(cask("kicad", "9.0.1", suite="KiCad", name="KiCad")), "newer than the cask")

    def test_fixable_ones_are_not_skipped(self):
        app(self.apps, "UTM", "4.7.4")
        self.assertFalse(self.skip(cask("utm", "5.0.9", "UTM")), "an older copy has a fix (--force), so it's reported")
        self.assertFalse(self.skip(cask("raycast", "1.0", "Raycast")), "not installed: Homebrew installs it")
        self.assertFalse(self.skip(cask("onedrive", "26.1", name="OneDrive")), "other machines still get installer casks")

    def test_brewfile_casks(self):
        bf = os.path.join(self.apps, "Brewfile")
        with open(bf, "w") as f:
            f.write('brew "jq"\ncask "utm"\n  cask "user/tap/thing", args: {}\nmas "Xcode", id: 1\n')
        self.assertEqual(bw.brewfile_casks(bf), ["utm", "user/tap/thing"])

    def test_not_installed(self):
        self.assertIn("not installed. Install it: brew install --cask raycast", self.why(cask("raycast", "1.0", "Raycast")))
        self.assertIn("in a terminal", self.why(cask("onedrive", "26.1", name="OneDrive")))

    def test_unknown_cask(self):
        self.assertIn("doesn't know this cask", bw.explain("nope", None, "Brewfile.workstation")[1])

    def test_version_order(self):
        self.assertLess(bw.version_key("v2.0.4"), bw.version_key("2.0.12"))
        self.assertLess(bw.version_key("1.2.11"), bw.version_key("1.10.21"))
        self.assertLess(bw.version_key("02.02.01.60"), bw.version_key("02.09.01.70"))


if __name__ == "__main__":
    unittest.main()
