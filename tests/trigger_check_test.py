"""Tests for trigger-check and the trigger wrapper (macos/btt/triggers.toml). Standard library only:
python3 -I tests/trigger_check_test.py"""
import importlib.machinery, importlib.util, json, os, shutil, subprocess, sys, tempfile, unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)


def load(name, mod):
    loader = importlib.machinery.SourceFileLoader(mod, os.path.join(REPO, "dot_local/bin", name))
    m = importlib.util.module_from_spec(importlib.util.spec_from_loader(mod, loader))
    loader.exec_module(m)
    return m


tc = load("executable_trigger-check", "trigger_check")
sc = load("executable_shortcut-check", "shortcut_check")

GOOD = '''
[[trigger]]
name = "keep-awake"
action = "Keep Awake: toggle"
hint = "Hyper+K keeps the Mac awake"
run = "keep-awake toggle"
keys = ["⌃⌥⇧⌘K"]

[[trigger]]
name = "mic-mute"
action = "Mic: toggle mute"
hint = "Hyper+M mutes the mic"
btt = { action = 585, data = { BTTMicMuteApplyToAllInputDevices = true } }
keys = ["⌃⌥⇧⌘M", "⌃⌥⌘M"]
fires = ["streamdeck"]
'''


class Fixture(unittest.TestCase):
    def setUp(self):
        self.d = tempfile.mkdtemp()
        os.makedirs(os.path.join(self.d, "macos/btt"))
        os.makedirs(os.path.join(self.d, "dot_local/bin"))
        open(os.path.join(self.d, "dot_local/bin/executable_keep-awake"), "w").close()
        self.other = {"BTTTriggerClass": "BTTTriggerTypeKeyboardShortcut", "BTTShortcutKeyCode": 36,
                      "BTTShortcutModifierKeys": 786432, "BTTOrder": 0, "BTTUUID": "OTHER",
                      "BTTActionsToExecute": [{"BTTPredefinedActionType": 21, "BTTUUID": "OTHER-A"}]}
        self.preset({"BTTPresetContent": [{"BTTAppBundleIdentifier": "BT.G", "BTTTriggers": [self.other]}]})
        self.toml(GOOD)

    def tearDown(self):
        shutil.rmtree(self.d)

    def toml(self, text):
        with open(os.path.join(self.d, "macos/btt/triggers.toml"), "w") as f:
            f.write(text)

    def preset(self, d):
        with open(os.path.join(self.d, "macos/btt/Default.bttpreset"), "w") as f:
            f.write(tc.dump(d))

    def preset_text(self):
        with open(os.path.join(self.d, "macos/btt/Default.bttpreset")) as f:
            return f.read()

    def read_preset(self):
        with open(os.path.join(self.d, "macos/btt/Default.bttpreset")) as f:
            return json.load(f)

    def problems(self, text):
        self.toml(text)
        return tc.validate(self.d, tc.load(self.d))

    def run_check(self, *args):
        return subprocess.run([sys.executable, "-I", os.path.join(REPO, "dot_local/bin/executable_trigger-check"),
                               "--source", self.d, *args], capture_output=True, text=True)

    # ---- validation ----
    def test_good_file_passes(self):
        self.assertEqual(self.problems(GOOD), [])

    def test_trigger_without_hyper_key_is_unreachable(self):
        p = self.problems(GOOD.replace('keys = ["⌃⌥⇧⌘K"]', 'keys = ["⌃⌥⌘K"]'))
        self.assertEqual(len([x for x in p if x.startswith("unreachable: trigger keep-awake")]), 3)

    def test_desk_only_surface_doesnt_cover_the_laptop(self):
        p = self.problems(GOOD.replace('keys = ["⌃⌥⇧⌘K"]', 'keys = []\nfires = ["streamdeck", "touch"]'))
        self.assertEqual(p, [])
        p = self.problems(GOOD.replace('keys = ["⌃⌥⇧⌘K"]', 'keys = []\nfires = ["streamdeck"]'))
        self.assertEqual([x for x in p if "keep-awake" in x],
                         ["unreachable: trigger keep-awake: nothing fires it laptop; add a Hyper key (⌃⌥⇧⌘ + key)"])

    def test_reserved_hyper_key(self):
        p = self.problems(GOOD.replace("⌃⌥⇧⌘K", "⌃⌥⇧⌘B"))
        self.assertTrue(any(x.startswith("reserved: trigger keep-awake: Hyper+B") for x in p))

    def test_duplicate_key_and_name(self):
        p = self.problems(GOOD.replace("⌃⌥⇧⌘M", "⌃⌥⇧⌘K").replace('name = "mic-mute"', 'name = "keep-awake"'))
        self.assertTrue(any("name used twice" in x for x in p))
        self.assertTrue(any("⌃⌥⇧⌘K is also keep-awake's" in x for x in p))

    def test_run_must_be_a_dotfiles_command(self):
        p = self.problems(GOOD.replace('run = "keep-awake toggle"', 'run = "caffeinate -d"'))
        self.assertTrue(any("run: 'caffeinate' isn't in dot_local/bin" in x for x in p))

    def test_exactly_one_of_run_or_btt(self):
        p = self.problems(GOOD.replace('run = "keep-awake toggle"', 'run = "keep-awake toggle"\nbtt = { action = 1 }'))
        self.assertTrue(any("exactly one of run or btt" in x for x in p))

    def test_unknown_surface_and_unreadable_keys(self):
        p = self.problems(GOOD.replace('fires = ["streamdeck"]', 'fires = ["pedal"]').replace("⌃⌥⌘M", "⌃⌥⌘Ö"))
        self.assertTrue(any("unknown surface 'pedal'" in x for x in p))
        self.assertTrue(any("can't read keys '⌃⌥⌘Ö'" in x for x in p))

    # ---- generation ----
    def test_generate_writes_named_and_key_triggers(self):
        r = self.run_check("--write")
        self.assertEqual(r.returncode, 0, r.stdout)
        ts = self.read_preset()["BTTPresetContent"][0]["BTTTriggers"]
        self.assertEqual(ts[0]["BTTUUID"], "OTHER")  # untouched, first
        named = {t["BTTTriggerName"]: t for t in ts if t.get("BTTTriggerType") == 643}
        self.assertEqual(set(named), {"keep-awake", "mic-mute"})
        self.assertEqual(named["keep-awake"]["BTTActionsToExecute"][0]["BTTShellTaskActionScript"],
                         'exec "$HOME/.local/bin/keep-awake" toggle')
        mic = named["mic-mute"]["BTTActionsToExecute"][0]
        self.assertEqual((mic["BTTPredefinedActionType"], mic["BTTAdditionalActionData"]),
                         (585, {"BTTMicMuteApplyToAllInputDevices": True}))
        keys = [t for t in ts if t.get("BTTTriggerClass") == "BTTTriggerTypeKeyboardShortcut" and t["BTTUUID"] != "OTHER"]
        self.assertEqual(sorted((t["BTTShortcutKeyCode"], t["BTTShortcutModifierKeys"]) for t in keys),
                         [(40, tc.HYPER), (46, 1835008), (46, tc.HYPER)])
        k = keys[0]["BTTActionsToExecute"]
        self.assertIn("--log-only", k[0]["BTTShellTaskActionScript"])
        self.assertEqual((k[1]["BTTPredefinedActionType"], k[1]["BTTNamedTriggerToTrigger"]), (248, "keep-awake"))

    def test_generate_is_idempotent_and_check_passes(self):
        self.run_check("--write")
        before = self.preset_text()
        self.assertIn("preset up to date", self.run_check("--write").stdout)
        self.assertEqual(self.preset_text(), before)
        self.assertEqual(self.run_check().returncode, 0)

    def test_stale_preset_fails(self):
        r = self.run_check()
        self.assertEqual(r.returncode, 1)
        self.assertIn("stale:", r.stdout)

    def test_keeps_what_btt_adds_on_export(self):
        self.run_check("--write")
        d = self.read_preset()
        for t in d["BTTPresetContent"][0]["BTTTriggers"]:
            t["BTTTriggerTypeDescriptionReadOnly"] = "added by BTT"
            for a in t.get("BTTActionsToExecute", []):
                a["BTTPredefinedActionName"] = "added by BTT"
        self.preset(d)
        self.assertEqual(self.run_check().returncode, 0)

    def test_removed_trigger_is_dropped(self):
        self.run_check("--write")
        self.toml(GOOD.split("[[trigger]]\nname = \"mic-mute\"")[0])
        self.run_check("--write")
        ts = self.read_preset()["BTTPresetContent"][0]["BTTTriggers"]
        self.assertEqual(sorted(t.get("BTTTriggerName") or t["BTTUUID"] for t in ts if t.get("BTTTriggerType") == 643
                                or t["BTTUUID"] == "OTHER"), ["OTHER", "keep-awake"])
        self.assertFalse(any(t.get("BTTShortcutKeyCode") == 46 for t in ts))

    def test_invalid_file_isnt_written(self):
        self.toml(GOOD.replace('keys = ["⌃⌥⇧⌘K"]', "keys = []"))
        before = self.preset_text()
        self.assertEqual(self.run_check("--write").returncode, 1)
        self.assertEqual(self.preset_text(), before)

    # ---- shortcut-check reads the trigger keys ----
    def test_trigger_keys_join_the_shortcut_registry(self):
        self.run_check("--write")
        os.makedirs(os.path.join(self.d, "macos/prefs"))
        import plistlib
        with open(os.path.join(self.d, "macos/symbolichotkeys.plist"), "wb") as f:
            plistlib.dump({"AppleSymbolicHotKeys": {}}, f)
        reg_path = os.path.join(self.d, "macos/shortcuts.toml")
        with open(reg_path, "w") as f:
            f.write('[[shortcut]]\nkeys = "⌃⌥↩"\nowner = "btt"\naction = "maximize"\n'
                    '[[shortcut]]\nkeys = "⌥⇥"\nowner = "alttab"\naction = "switcher"\n'
                    '[[shortcut]]\nkeys = "⌥`"\nowner = "alttab"\naction = "switcher 2"\n')
        _, problems, _ = sc.check(self.d, reg_path)
        self.assertEqual(problems, [])
        with open(reg_path, "a") as f:
            f.write('[[shortcut]]\nkeys = "⌃⌥⇧⌘K"\nowner = "raycast"\naction = "something"\n')
        _, problems, _ = sc.check(self.d, reg_path)
        self.assertTrue(any(p.startswith("conflict: ⌃⌥⇧⌘K") for p in problems))


class Committed(unittest.TestCase):
    def test_repo_triggers_pass_and_preset_is_current(self):
        r = subprocess.run([sys.executable, "-I", os.path.join(REPO, "dot_local/bin/executable_trigger-check"),
                            "--source", REPO], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stdout)


class Wrapper(unittest.TestCase):
    def setUp(self):
        self.d = tempfile.mkdtemp()
        self.env = dict(os.environ, XDG_STATE_HOME=self.d)

    def tearDown(self):
        shutil.rmtree(self.d)

    def run_trigger(self, *args):
        return subprocess.run(["/bin/bash", os.path.join(REPO, "dot_local/bin/executable_trigger"), *args],
                              env=self.env, capture_output=True, text=True)

    def test_log_only_appends_name_and_source(self):
        self.assertEqual(self.run_trigger("--log-only", "keep-awake", "key").returncode, 0)
        with open(os.path.join(self.d, "triggers.log")) as f:
            self.assertRegex(f.read(), r"^\d{4}-\d\d-\d\dT[\d:]+[+-]\d{4} keep-awake key\n$")

    def test_bad_names_are_refused(self):
        for args in (["--log-only", "Bad Name", "key"], ["--log-only", "ok", "two words"], []):
            self.assertEqual(self.run_trigger(*args).returncode, 2, args)
        self.assertFalse(os.path.exists(os.path.join(self.d, "triggers.log")))

    def test_log_is_trimmed(self):
        log = os.path.join(self.d, "triggers.log")
        with open(log, "w") as f:
            f.write("".join(f"2026-01-01T00:00:00+0000 old-{i:05d} key\n" for i in range(9000)))
        self.run_trigger("--log-only", "keep-awake", "key")
        with open(log) as f:
            lines = f.read().splitlines()
        self.assertEqual(len(lines), 1000)
        self.assertTrue(lines[-1].endswith("keep-awake key"))


if __name__ == "__main__":
    unittest.main()
