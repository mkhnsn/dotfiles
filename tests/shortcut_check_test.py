"""Tests for shortcut-check (dot_local/bin/executable_shortcut-check). Standard library only."""
import importlib.machinery, importlib.util, json, os, plistlib, shutil, tempfile, unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
path = os.path.join(REPO, "dot_local/bin/executable_shortcut-check")
loader = importlib.machinery.SourceFileLoader("shortcut_check", path)
sc = importlib.util.module_from_spec(importlib.util.spec_from_loader("shortcut_check", loader))
loader.exec_module(sc)

CMD, SHIFT, CTRL, OPT = 1 << 20, 1 << 17, 1 << 18, 1 << 19


class Fixture(unittest.TestCase):
    def setUp(self):
        self.d = tempfile.mkdtemp()
        os.makedirs(os.path.join(self.d, "macos/btt"))
        os.makedirs(os.path.join(self.d, "macos/prefs"))
        self.symbolic({})
        self.btt([])
        self.alttab({"holdShortcut": "⌘", "nextWindowShortcut": "⇥", "shortcutCount": "1"})

    def tearDown(self):
        shutil.rmtree(self.d)

    def symbolic(self, hk):
        with open(os.path.join(self.d, "macos/symbolichotkeys.plist"), "wb") as f:
            plistlib.dump({"AppleSymbolicHotKeys": hk}, f)

    def btt(self, triggers):
        with open(os.path.join(self.d, "macos/btt/Default.bttpreset"), "w") as f:
            json.dump({"BTTPresetContent": [{"BTTAppBundleIdentifier": "BT.G", "BTTTriggers": triggers}]}, f)

    def alttab(self, prefs):
        with open(os.path.join(self.d, "macos/prefs/com.lwouis.alt-tab-macos.plist"), "wb") as f:
            plistlib.dump(prefs, f)

    def registry(self, text):
        with open(os.path.join(self.d, "macos/shortcuts.toml"), "w") as f:
            f.write(text)
        return sc.check(self.d, os.path.join(self.d, "macos/shortcuts.toml"))

    def test_normalize_orders_modifiers(self):
        self.assertEqual(sc.normalize("⌘⇧W"), "⇧⌘W")
        self.assertEqual(sc.normalize("⌘⌥⌃←"), "⌃⌥⌘←")

    def test_clean_registry_passes(self):
        _, problems, warnings = self.registry('[[shortcut]]\nkeys = "⌘⇥"\nowner = "alttab"\naction = "switcher"\n')
        self.assertEqual(problems, [])
        self.assertEqual(warnings, [])

    def test_conflict_between_owners(self):
        _, problems, _ = self.registry(
            '[[shortcut]]\nkeys = "⌘⇥"\nowner = "alttab"\naction = "switcher"\n'
            '[[shortcut]]\nkeys = "⌘⇥"\nowner = "raycast"\naction = "switch windows"\n')
        self.assertTrue(any(p.startswith("conflict: ⌘⇥") for p in problems))

    def test_app_scoped_bindings_dont_conflict_with_each_other(self):
        _, problems, _ = self.registry(
            '[[shortcut]]\nkeys = "⌘⇥"\nowner = "alttab"\naction = "switcher"\n'
            '[[shortcut]]\nkeys = "⌃⌥K"\nowner = "app-a"\nscope = "com.a"\naction = "x"\n'
            '[[shortcut]]\nkeys = "⌃⌥K"\nowner = "app-b"\nscope = "com.b"\naction = "y"\n')
        self.assertEqual(problems, [])

    def test_accepted_conflict_is_a_warning(self):
        _, problems, warnings = self.registry(
            '[[shortcut]]\nkeys = "⌘⇥"\nowner = "alttab"\naction = "switcher"\n'
            '[[shortcut]]\nkeys = "⌘⇥"\nowner = "app-menus"\naction = "x"\naccepted = "temporary"\n')
        self.assertEqual(problems, [])
        self.assertEqual(len(warnings), 1)

    def test_undeclared_btt_trigger(self):
        self.btt([{"BTTTriggerClass": "BTTTriggerTypeKeyboardShortcut", "BTTShortcutKeyCode": 13,
                   "BTTShortcutModifierKeys": SHIFT | CMD, "BTTTriggerName": "reset"}])
        _, problems, _ = self.registry('[[shortcut]]\nkeys = "⌘⇥"\nowner = "alttab"\naction = "switcher"\n')
        self.assertIn("undeclared: btt binds ⇧⌘W", problems[0])

    def test_implicit_fn_on_arrows_is_ignored(self):
        FN = 1 << 23
        self.btt([{"BTTTriggerClass": "BTTTriggerTypeKeyboardShortcut", "BTTShortcutKeyCode": 123,
                   "BTTShortcutModifierKeys": CTRL | OPT | FN, "BTTGestureNotes": "left half"}])
        _, problems, _ = self.registry('[[shortcut]]\nkeys = "⌘⇥"\nowner = "alttab"\naction = "switcher"\n'
                                       '[[shortcut]]\nkeys = "⌃⌥←"\nowner = "btt"\naction = "left half"\n')
        self.assertEqual(problems, [])

    def test_stale_registry_entry(self):
        _, problems, _ = self.registry(
            '[[shortcut]]\nkeys = "⌘⇥"\nowner = "alttab"\naction = "switcher"\n'
            '[[shortcut]]\nkeys = "⌃⌥←"\nowner = "btt"\naction = "left half"\n')
        self.assertTrue(any(p.startswith("stale: the registry lists btt ⌃⌥←") for p in problems))

    def test_enabled_system_shortcut_is_read(self):
        self.symbolic({"28": {"enabled": True, "value": {"type": "standard", "parameters": [51, 20, SHIFT | CMD]}},
                       "29": {"enabled": False, "value": {"type": "standard", "parameters": [51, 20, CTRL | SHIFT | CMD]}}})
        _, problems, _ = self.registry('[[shortcut]]\nkeys = "⌘⇥"\nowner = "alttab"\naction = "switcher"\n')
        self.assertEqual([p for p in problems if "macos" in p], ["undeclared: macos binds ⇧⌘3 (Screenshot: screen to file, scope global); add it to the registry"])

    def test_alttab_defaults_when_unset(self):
        self.alttab({})
        _, problems, _ = self.registry('[[shortcut]]\nkeys = "⌥⇥"\nowner = "alttab"\naction = "switcher"\n'
                                       '[[shortcut]]\nkeys = "⌥`"\nowner = "alttab"\naction = "app windows"\n')
        self.assertEqual(problems, [])


class RepoRegistry(unittest.TestCase):
    def test_this_repo_has_no_conflicts(self):
        _, problems, _ = sc.check(REPO, os.path.join(REPO, "macos/shortcuts.toml"))
        self.assertEqual(problems, [])


if __name__ == "__main__":
    unittest.main()
