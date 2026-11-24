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
        with open(os.path.join(self.d, "macos/btt/symbols.toml"), "w") as f:  # as --measure writes it
            f.write('[width]\n"cup.and.saucer.fill" = 25\n"video" = 23\n"arrow.up.and.down" = 14\n')

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
        self.assertEqual([x for x in p if x.startswith("unreachable: trigger keep-awake")],
                         ["unreachable: trigger keep-awake: no Hyper key (⌃⌥⇧⌘ + key); the keyboard is the one surface in every setup"]
                         + [f"unreachable: trigger keep-awake: nothing fires it {s}" for s in tc.SETUPS])

    def test_desk_only_surface_doesnt_cover_the_laptop(self):
        p = self.problems(GOOD.replace('keys = ["⌃⌥⇧⌘K"]', 'keys = []\nfires = ["streamdeck"]'))
        self.assertIn("unreachable: trigger keep-awake: nothing fires it laptop", p)
        self.assertNotIn("unreachable: trigger keep-awake: nothing fires it docked-closed", p)

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

    def test_ipad_only_still_needs_a_hyper_key(self):
        p = self.problems(GOOD.replace('keys = ["⌃⌥⇧⌘K"]', 'fires = ["ipad"]'))
        self.assertIn("unreachable: trigger keep-awake: no Hyper key (⌃⌥⇧⌘ + key); the keyboard is the one surface in every setup", p)
        r = self.run_check("--write")
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertNotIn("Traceback", r.stderr)

    def test_key_taken_in_the_shortcut_registry(self):
        with open(os.path.join(self.d, "macos/shortcuts.toml"), "w") as f:
            f.write('[[shortcut]]\nkeys = "⌃⌥⌘M"\nowner = "btt"\naction = "Window: maximize"\n'
                    '[[shortcut]]\nkeys = "⌃⌥⌘V"\nowner = "zoom"\nscope = "us.zoom.xos"\naction = "Video"\n')
        p = self.problems(GOOD)
        self.assertTrue(any(x.startswith("conflict: trigger mic-mute: ⌃⌥⌘M is btt's Window: maximize") for x in p), p)
        # an app key clashes in that app, and with a global trigger key; not in another app
        p = self.problems(GOOD.replace('"⌃⌥⇧⌘M", ', '"⌃⌥⇧⌘M", "⌃⌥⌘V", '))
        self.assertTrue(any("⌃⌥⌘V is zoom's Video" in x for x in p), p)
        app = GOOD.replace('keys = ["⌃⌥⇧⌘K"]', 'keys = ["⌃⌥⇧⌘K", "⌃⌥⌘V"]\napps = ["com.microsoft.teams2"]')
        self.assertFalse(any("⌃⌥⌘V" in x for x in self.problems(app)))
        self.assertTrue(any("⌃⌥⌘V" in x for x in self.problems(app.replace("com.microsoft.teams2", "us.zoom.xos"))))

    def test_app_keys_go_in_each_apps_section(self):
        self.toml(GOOD.replace('keys = ["⌃⌥⇧⌘K"]', 'keys = ["⌃⌥⇧⌘K"]\napps = ["us.zoom.xos", "com.microsoft.teams2"]')
                  .replace('btt = { action = 585, data = { BTTMicMuteApplyToAllInputDevices = true } }',
                           'btt = { action = 128, fields = { BTTShortcutToSend = "59,55,56,9", BTTShortcutApp = "active app" } }'))
        r = self.run_check("--write")
        self.assertEqual(r.returncode, 0, r.stdout)
        d = self.read_preset()
        sections = {a["BTTAppBundleIdentifier"]: a for a in d["BTTPresetContent"]}
        for app in ("us.zoom.xos", "com.microsoft.teams2"):
            keys = [t for t in sections[app]["BTTTriggers"] if t.get("BTTTriggerClass") == "BTTTriggerTypeKeyboardShortcut"]
            self.assertEqual([(t["BTTShortcutKeyCode"], t["BTTActionsToExecute"][1]["BTTNamedTriggerToTrigger"]) for t in keys],
                             [(40, "keep-awake")])
        g = sections["BT.G"]["BTTTriggers"]
        self.assertFalse(any(t.get("BTTShortcutKeyCode") == 40 for t in g))  # not global
        mic = next(t for t in g if t.get("BTTTriggerName") == "mic-mute")["BTTActionsToExecute"][0]
        self.assertEqual((mic["BTTPredefinedActionType"], mic["BTTShortcutToSend"]), (128, "59,55,56,9"))
        self.assertEqual(self.run_check().returncode, 0)
        # dropping an app takes its keys out of that app's section
        self.toml(GOOD.replace('keys = ["⌃⌥⇧⌘K"]', 'keys = ["⌃⌥⇧⌘K"]\napps = ["us.zoom.xos"]'))
        self.run_check("--write")
        sections = {a["BTTAppBundleIdentifier"]: a for a in self.read_preset()["BTTPresetContent"]}
        self.assertEqual(sections["com.microsoft.teams2"]["BTTTriggers"], [])

    def test_multi_app_keys_have_their_own_uuids(self):
        self.toml(GOOD.replace('keys = ["⌃⌥⇧⌘K"]', 'keys = ["⌃⌥⇧⌘K"]\napps = ["a.one", "b.two"]'))
        uuids = []
        def walk(o):
            if isinstance(o, dict):
                if "BTTUUID" in o:
                    uuids.append(o["BTTUUID"])
                for v in o.values():
                    walk(v)
            elif isinstance(o, list):
                for v in o:
                    walk(v)
        walk([w for _, w in tc.wanted(tc.load(self.d))])
        self.assertEqual(len(uuids), len(set(uuids)))

    def test_hand_made_trigger_on_a_generated_key_is_reported(self):
        d = self.read_preset()
        d["BTTPresetContent"].append({"BTTAppBundleIdentifier": "us.zoom.xos", "BTTTriggers": [
            {"BTTTriggerClass": "BTTTriggerTypeKeyboardShortcut", "BTTShortcutKeyCode": 40,
             "BTTShortcutModifierKeys": tc.HYPER, "BTTUUID": "HAND", "BTTGestureNotes": "old camera",
             "BTTActionsToExecute": [{"BTTPredefinedActionType": 128, "BTTUUID": "HAND-A"}]}]})
        self.preset(d)
        self.toml(GOOD.replace('keys = ["⌃⌥⇧⌘K"]', 'keys = ["⌃⌥⇧⌘K"]\napps = ["us.zoom.xos"]'))
        r = self.run_check("--write")
        self.assertEqual(r.returncode, 1)
        self.assertIn("conflict: old camera (us.zoom.xos) is a hand-made BTT trigger", r.stdout)

    def test_hand_made_arrow_trigger_clashes_with_or_without_fn(self):
        arrow = GOOD + '''
[[trigger]]
name = "window-left-half"
action = "Window: left half"
hint = "Hyper+← puts the window in the left half"
btt = { action = 19 }
keys = ["⌃⌥⇧⌘←", "⌃⌥←"]
'''
        for flags in (786432, 786432 | tc.FN):  # written as JSON, or recorded in BTT
            with self.subTest(flags=flags):
                d = self.read_preset()
                d["BTTPresetContent"][0]["BTTTriggers"] = [self.other, {
                    "BTTTriggerClass": "BTTTriggerTypeKeyboardShortcut", "BTTShortcutKeyCode": 123,
                    "BTTShortcutModifierKeys": flags, "BTTUUID": "HAND", "BTTGestureNotes": "old left half",
                    "BTTActionsToExecute": [{"BTTPredefinedActionType": 19, "BTTUUID": "HAND-A"}]}]
                self.preset(d)
                self.toml(arrow)
                r = self.run_check("--write")
                self.assertEqual(r.returncode, 1, r.stdout)
                self.assertIn("conflict: old left half", r.stdout)

    def test_arrow_key_taken_in_the_shortcut_registry(self):
        with open(os.path.join(self.d, "macos/shortcuts.toml"), "w") as f:
            f.write('[[shortcut]]\nkeys = "⌃←"\nowner = "macos-default"\naction = "Move left a space"\nsource = "manual"\n')
        p = self.problems(GOOD.replace('keys = ["⌃⌥⇧⌘K"]', 'keys = ["⌃⌥⇧⌘K", "⌃←"]'))
        self.assertTrue(any("⌃← is macos-default's Move left a space" in x for x in p), p)

    def test_hint_controls_stay_last_when_a_trigger_is_added(self):
        self.run_check("--write")
        self.toml(GOOD + '\n[[trigger]]\nname = "late"\naction = "Late"\nhint = "x"\nrun = "keep-awake on"\nkeys = ["⌃⌥⇧⌘L"]\n')
        self.run_check("--write")
        _, menu, _, _ = self.hints_parts()
        self.assertEqual([i["BTTMenuName"] for i in menu["BTTMenuItems"]][-3:], ["late", "hints-next", "hints-mute"])

    def test_btt_fields_are_checked(self):
        p = self.problems(GOOD.replace('data = { BTTMicMuteApplyToAllInputDevices = true }', 'fields = { BTTWhatever = 1 }'))
        self.assertTrue(any("fields are the action's own keys" in x for x in p), p)

    def test_malformed_entries_are_reported_not_crashed(self):
        for bad, want in (('btt = 5', "btt must be"), ('run = "keep-awake \'toggle"', "run must be a command line"),
                          ('run = 5', "run must be a command line"), ('keys = "⌃⌥⇧⌘J"', "keys must be a list"),
                          ('fires = "ipad"', "fires must be a list")):
            text = GOOD.replace('run = "keep-awake toggle"\nkeys = ["⌃⌥⇧⌘K"]',
                                bad + ('\nkeys = ["⌃⌥⇧⌘K"]' if not bad.startswith("keys") else ""))
            if bad.startswith("btt"):
                text = text.replace(bad, bad)  # replaces run: exactly one of run or btt still holds
            p = self.problems(text)
            self.assertTrue(any(want in x for x in p), (bad, p))
        self.toml(GOOD + '\n[[trigger]]\nname = "x"\nkeys = ["⌃⌥⇧⌘X"]\n')
        self.assertEqual(self.run_check().returncode, 1)  # no action/hint: reported

    # ---- generation ----
    def test_arrow_keys_carry_fn_and_window_actions_keep_their_fields(self):
        self.toml(GOOD + '''
[[trigger]]
name = "window-left-half"
action = "Window: left half"
hint = "Hyper+← puts the window in the left half"
btt = { action = 19 }
keys = ["⌃⌥⇧⌘←", "⌃⌥←"]

[[trigger]]
name = "window-full-height"
action = "Window: full height"
hint = "Hyper+↑ makes the window as tall as the screen"
btt = { action = 251, fields = { BTTActionMoveResizeName = "Full height", BTTActionMoveResizeConfig = '{"BTTMoveResizeVersion":3}' } }
keys = ["⌃⌥⇧⌘↑"]
''')
        r = self.run_check("--write")
        self.assertEqual(r.returncode, 0, r.stdout)
        ts = self.read_preset()["BTTPresetContent"][0]["BTTTriggers"]
        keys = {(t["BTTShortcutKeyCode"], t["BTTShortcutModifierKeys"]) for t in ts
                if t.get("BTTTriggerClass") == "BTTTriggerTypeKeyboardShortcut" and t.get("BTTGestureNotes", "").startswith("Window")}
        # macOS reports Fn with arrows, so BTT stores it; shortcut-check reads it back as implied.
        self.assertEqual(keys, {(123, tc.HYPER | tc.FN), (123, (1 << 18) | (1 << 19) | tc.FN), (126, tc.HYPER | tc.FN)})
        self.assertEqual(sc.keys_from_code(123, tc.HYPER | tc.FN), "⌃⌥⇧⌘←")
        act = next(t for t in ts if t.get("BTTTriggerName") == "window-full-height")["BTTActionsToExecute"][0]
        self.assertEqual((act["BTTPredefinedActionType"], act["BTTActionMoveResizeName"], act["BTTActionMoveResizeConfig"]),
                         (251, "Full height", '{"BTTMoveResizeVersion":3}'))
        self.assertEqual(self.run_check().returncode, 0)

    def test_generate_writes_named_and_key_triggers(self):
        r = self.run_check("--write")
        self.assertEqual(r.returncode, 0, r.stdout)
        ts = self.read_preset()["BTTPresetContent"][0]["BTTTriggers"]
        self.assertEqual(ts[0]["BTTUUID"], "OTHER")  # untouched, first
        self.assertEqual([t["BTTOrder"] for t in ts], list(range(len(ts))))  # new ones after the last
        named = {t["BTTTriggerName"]: t for t in ts if t.get("BTTTriggerType") == 643}
        self.assertEqual(set(named), {"keep-awake", "mic-mute", "hints-close"})
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

    def test_switching_btt_to_run_leaves_nothing_behind(self):
        self.run_check("--write")
        d = self.read_preset()
        for t in d["BTTPresetContent"][0]["BTTTriggers"]:
            for a in t.get("BTTActionsToExecute", []):
                a["BTTPredefinedActionName"] = "name BTT gave it"
        self.preset(d)
        self.toml(GOOD.replace('btt = { action = 585, data = { BTTMicMuteApplyToAllInputDevices = true } }',
                               'run = "keep-awake on"'))
        self.run_check("--write")
        mic = next(t for t in self.read_preset()["BTTPresetContent"][0]["BTTTriggers"] if t.get("BTTTriggerName") == "mic-mute")
        act = mic["BTTActionsToExecute"][0]
        self.assertEqual(act["BTTPredefinedActionType"], 206)
        self.assertNotIn("BTTAdditionalActionData", act)
        self.assertNotIn("BTTPredefinedActionName", act)  # it named the old action
        keep = next(t for t in self.read_preset()["BTTPresetContent"][0]["BTTTriggers"] if t.get("BTTTriggerName") == "keep-awake")
        self.assertEqual(keep["BTTActionsToExecute"][0]["BTTPredefinedActionName"], "name BTT gave it")

    def test_trigger_added_in_btt_after_generated_ones_stays_current(self):
        self.run_check("--write")
        d = self.read_preset()
        ts = d["BTTPresetContent"][0]["BTTTriggers"]
        ts.append({"BTTTriggerClass": "BTTTriggerTypeKeyboardShortcut", "BTTShortcutKeyCode": 4, "BTTOrder": len(ts),
                   "BTTShortcutModifierKeys": 786432, "BTTUUID": "NEW",
                   "BTTActionsToExecute": [{"BTTPredefinedActionType": 21, "BTTUUID": "NEW-A"}]})
        self.preset(d)
        r = self.run_check()
        self.assertEqual(r.returncode, 0, r.stdout)

    def test_btt_renumbering_on_import_is_kept(self):
        self.run_check("--write")
        d = self.read_preset()
        ts = d["BTTPresetContent"][0]["BTTTriggers"]
        for i, t in enumerate(reversed(ts)):  # BTT may hand back any numbering, exported in order
            t["BTTOrder"] = i
        ts.sort(key=lambda t: t["BTTOrder"])
        self.preset(d)
        self.assertEqual(self.run_check("--write").stdout.strip(), "ok: 2 triggers, preset up to date")

    def test_named_trigger_made_in_btt_is_reported_when_dropped(self):
        d = self.read_preset()
        d["BTTPresetContent"][0]["BTTTriggers"].append(
            {"BTTTriggerType": 643, "BTTTriggerClass": "BTTTriggerTypeOtherTriggers", "BTTTriggerName": "handmade",
             "BTTUUID": "HAND", "BTTActionsToExecute": []})
        self.preset(d)
        r = self.run_check()
        self.assertEqual(r.returncode, 1)
        self.assertIn("not in triggers.toml: handmade", r.stdout)
        r = self.run_check("--write")
        self.assertIn("dropping: handmade", r.stdout)

    def test_removed_trigger_is_dropped(self):
        self.run_check("--write")
        self.toml(GOOD.split("[[trigger]]\nname = \"mic-mute\"")[0])
        self.run_check("--write")
        ts = self.read_preset()["BTTPresetContent"][0]["BTTTriggers"]
        self.assertEqual(sorted(t.get("BTTTriggerName") or t["BTTUUID"] for t in ts if t.get("BTTTriggerType") == 643
                                or t["BTTUUID"] == "OTHER"), ["OTHER", "hints-close", "keep-awake"])
        self.assertFalse(any(t.get("BTTShortcutKeyCode") == 46 for t in ts))

    def test_invalid_file_isnt_written(self):
        self.toml(GOOD.replace('keys = ["⌃⌥⇧⌘K"]', "keys = []"))
        before = self.preset_text()
        self.assertEqual(self.run_check("--write").returncode, 1)
        self.assertEqual(self.preset_text(), before)

    # ---- hints pieces (#144) ----
    def hints_parts(self):
        ts = self.read_preset()["BTTPresetContent"][0]["BTTTriggers"]
        menu = next(t for t in ts if t.get("BTTTriggerType") == 767)
        close = next(t for t in ts if t.get("BTTTriggerName") == "hints-close")
        app = next(t for t in ts if t.get("BTTTriggerType") == 779)
        return ts, menu, close, app

    def test_generates_the_cheat_sheet_and_hint_triggers(self):
        self.toml(GOOD + '\n[[trigger]]\nname = "cheat-sheet"\naction = "Cheat sheet"\nhint = "Hyper+H"\n'
                         'btt = { action = 388, data = { BTTMenuActionMenuID = "Hints" } }\nkeys = ["⌃⌥⇧⌘H"]\n'
                         '\n[[trigger]]\nname = "zoom-cam"\naction = "Camera <video>"\nhint = "x"\n'
                         'run = "keep-awake on"\nkeys = ["⌃⌥⇧⌘V"]\napps = ["us.zoom.xos"]\n')
        r = self.run_check("--write")
        self.assertEqual(r.returncode, 0, r.stdout)
        ts, menu, close, app = self.hints_parts()
        self.assertEqual(menu["BTTMenuName"], "Hints")
        names = [i["BTTMenuName"] for i in menu["BTTMenuItems"]]
        # a row per trigger except the cheat sheet's own, then the hint controls
        self.assertEqual(names, ["Header", "keep-awake", "mic-mute", "zoom-cam", "hints-next", "hints-mute"])
        rows = {i["BTTMenuName"]: i for i in menu["BTTMenuItems"]}
        self.assertEqual(rows["keep-awake"]["BTTMenuItemActions"][0]["BTTShellTaskActionScript"],
                         '"$HOME/.local/bin/trigger" keep-awake menu')
        text = rows["zoom-cam"]["BTTMenuConfig"]["BTTMenuAttributedText"]
        self.assertIn("<b>Hyper+V</b>", text)
        self.assertIn("Hyper+H · what you can do", rows["Header"]["BTTMenuConfig"]["BTTMenuAttributedText"])
        self.assertIn("Camera &lt;video&gt;", text)  # escaped
        self.assertIn("Stream Deck", rows["mic-mute"]["BTTMenuConfig"]["BTTMenuAttributedText"])
        self.assertNotIn("BTTMenuItemActions", rows["Header"])
        h = menu["BTTMenuConfig"]["BTTMenuFrameHeight"]
        self.assertEqual(h, 2 * tc.PAD + 5 * tc.ROW_H + 4 * tc.GAP)  # the app row starts hidden
        self.assertEqual(rows["zoom-cam"]["BTTMenuConfig"]["BTTMenuItemVisibleWhileActive"], 0)
        self.assertEqual(rows["keep-awake"]["BTTMenuConfig"]["BTTMenuItemVisibleWhileActive"], 1)
        self.assertEqual(menu["BTTMenuConfig"]["BTTMenuSizingBehavior"], 3)
        a = close["BTTActionsToExecute"][0]
        self.assertEqual((a["BTTPredefinedActionType"], a["BTTAdditionalActionData"]["BTTCloseNotificationsTitleRegex"]),
                         (289, "^Hint"))
        self.assertIn('"$HOME/.local/bin/hints" app', app["BTTActionsToExecute"][0]["BTTShellTaskActionScript"])
        self.assertEqual(self.run_check().returncode, 0)  # current, and hints-close isn't reported as dropped
        self.assertNotIn("not in triggers.toml", self.run_check().stdout)

    def test_setup_events_run_hints_setup(self):
        self.run_check("--write")
        ts = self.read_preset()["BTTPresetContent"][0]["BTTTriggers"]
        events = {t["BTTTriggerType"]: t for t in ts if t.get("BTTTriggerType") in tc.SETUP_EVENTS}
        self.assertEqual(set(events), {792, 793, 683, 684})
        for t in events.values():
            self.assertIn('"$HOME/.local/bin/hints" setup', t["BTTActionsToExecute"][0]["BTTShellTaskActionScript"])
        self.assertEqual(self.run_check().returncode, 0)

    def test_row_text_names_only_the_surfaces_given(self):
        t = {"name": "x", "action": "Mic", "keys": ["⌃⌥⇧⌘M"], "fires": ["streamdeck", "touch"]}
        self.assertIn("Stream Deck, touch", tc.row_text(t))
        self.assertIn("· touch", tc.row_text(t, {"key", "touch"}))
        self.assertNotIn("·", tc.row_text(t, {"key"}))

    def test_btt_defaults_in_the_menu_survive_regenerating(self):
        self.run_check("--write")
        d = self.read_preset()
        menu = next(t for t in d["BTTPresetContent"][0]["BTTTriggers"] if t.get("BTTTriggerType") == 767)
        menu["BTTMenuConfig"]["BTTMenuElementIdentifier"] = "Hints"  # BTT fills these in on export
        menu["BTTMenuItems"][1]["BTTMenuConfig"]["BTTMenuTextMinimumScaleFactor"] = 0.3
        self.preset(d)
        self.assertEqual(self.run_check().returncode, 0)

    def test_hints_names_are_reserved(self):
        p = self.problems(GOOD.replace('name = "keep-awake"', 'name = "hints-next"'))
        self.assertTrue(any("hints-next is one of the hints' own pieces" in x for x in p), p)

    def test_removed_trigger_leaves_the_cheat_sheet(self):
        self.run_check("--write")
        self.toml(GOOD.split("[[trigger]]\nname = \"mic-mute\"")[0])
        self.run_check("--write")
        _, menu, _, _ = self.hints_parts()
        self.assertEqual([i["BTTMenuName"] for i in menu["BTTMenuItems"]],
                         ["Header", "keep-awake", "hints-next", "hints-mute"])

    def test_groups_get_a_header_and_rows_an_icon(self):
        grouped = (GOOD.replace('name = "keep-awake"', 'name = "keep-awake"\ngroup = "Mac"\nicon = "cup.and.saucer.fill"')
                   + '\n[[trigger]]\nname = "zoom-cam"\naction = "Camera"\nhint = "x"\ngroup = "Calls"\nicon = "video"\n'
                     'run = "keep-awake on"\nkeys = ["⌃⌥⇧⌘V"]\napps = ["us.zoom.xos"]\n')
        self.toml(grouped)
        self.assertEqual(self.run_check("--write").returncode, 0)
        _, menu, _, _ = self.hints_parts()
        rows = {i["BTTMenuName"]: i for i in menu["BTTMenuItems"]}
        self.assertEqual(list(rows), ["Header", "Group: Mac", "keep-awake", "mic-mute", "Group: Calls", "zoom-cam",
                                      "hints-next", "hints-mute"])
        cfg = rows["keep-awake"]["BTTMenuConfig"]
        self.assertEqual((cfg["BTTMenuItemIconType"], cfg["BTTMenuItemSFSymbolName"]), (2, "cup.and.saucer.fill"))
        self.assertNotIn("BTTMenuItemSFSymbolName", rows["mic-mute"]["BTTMenuConfig"])  # no icon given
        self.assertNotIn("BTTMenuItemActions", rows["Group: Mac"])  # a header does nothing
        self.assertIn("Mac</span>", rows["Group: Mac"]["BTTMenuConfig"]["BTTMenuAttributedText"])
        # a group of app rows only starts hidden with them (hints app shows both)
        self.assertEqual(rows["Group: Calls"]["BTTMenuConfig"]["BTTMenuItemVisibleWhileActive"], 0)
        self.assertEqual(rows["Group: Mac"]["BTTMenuConfig"]["BTTMenuItemVisibleWhileActive"], 1)
        self.assertEqual(menu["BTTMenuConfig"]["BTTMenuFrameHeight"], 2 * tc.PAD + 6 * tc.ROW_H + 5 * tc.GAP)
        self.assertEqual(self.run_check().returncode, 0)

    def test_a_row_added_in_the_middle_lands_in_its_group(self):
        first = GOOD.replace('name = "keep-awake"', 'name = "keep-awake"\ngroup = "Mac"').replace(
            'name = "mic-mute"', 'name = "mic-mute"\ngroup = "Calls"')
        self.toml(first)
        self.run_check("--write")
        # BTT keeps an existing row's place, so a new Mac trigger must not end up after Calls
        late = '\n[[trigger]]\nname = "late"\naction = "Late"\nhint = "x"\ngroup = "Mac"\nrun = "keep-awake on"\nkeys = ["⌃⌥⇧⌘L"]\n'
        self.toml(first.replace("\n[[trigger]]\nname = \"mic-mute\"", late + "\n[[trigger]]\nname = \"mic-mute\""))
        self.assertEqual(self.run_check("--write").returncode, 0)
        _, menu, _, _ = self.hints_parts()
        self.assertEqual([i["BTTMenuName"] for i in menu["BTTMenuItems"]],
                         ["Header", "Group: Mac", "keep-awake", "late", "Group: Calls", "mic-mute", "hints-next", "hints-mute"])
        self.assertEqual([i["BTTOrder"] for i in menu["BTTMenuItems"]], sorted(i["BTTOrder"] for i in menu["BTTMenuItems"]))

    def test_group_and_icon_are_checked(self):
        p = self.problems(GOOD.replace('name = "keep-awake"', 'name = "keep-awake"\ngroup = ""\nicon = "Not A Symbol"'))
        self.assertTrue(any("group must be text" in x for x in p), p)
        self.assertTrue(any("icon must be an SF Symbol name" in x for x in p), p)
        for bad in ('group = " Mac"', 'icon = ".."', 'icon = 5'):
            p = self.problems(GOOD.replace('name = "keep-awake"', 'name = "keep-awake"\n' + bad))
            self.assertTrue(any("invalid: trigger keep-awake" in x for x in p), (bad, p))

    def test_an_icon_needs_a_measured_width(self):
        os.remove(os.path.join(self.d, "macos/btt/symbols.toml"))
        p = self.problems(GOOD.replace('name = "keep-awake"', 'name = "keep-awake"\nicon = "cup.and.saucer.fill"'))
        self.assertTrue(any("unmeasured: trigger keep-awake" in x and "--measure" in x for x in p), p)

    def test_a_split_group_is_reported(self):
        extra = '\n[[trigger]]\nname = "late"\naction = "Late"\nhint = "x"\ngroup = "mac"\nrun = "keep-awake on"\nkeys = ["⌃⌥⇧⌘L"]\n'
        p = self.problems(GOOD.replace('name = "keep-awake"', 'name = "keep-awake"\ngroup = "Mac"').replace(
            'name = "mic-mute"', 'name = "mic-mute"\ngroup = "Calls"') + extra)
        self.assertTrue(any("group 'mac' is split (also at keep-awake)" in x for x in p), p)

    def test_rows_made_before_the_groups_scheme_dont_keep_their_place(self):
        # A preset from the old scheme: trigger rows keyed by name alone, the hint controls by all
        # the names before them (which is what the new scheme would key hints-next by, too).
        self.run_check("--write")
        d = self.read_preset()
        menu = next(t for t in d["BTTPresetContent"][0]["BTTTriggers"] if t.get("BTTTriggerType") == 767)
        names = [r["BTTMenuName"] for r in menu["BTTMenuItems"]]
        for i, r in enumerate(menu["BTTMenuItems"]):
            before = ",".join(names[:len(names) - 2])
            r["BTTUUID"] = (tc.uid("hints", "menu", r["BTTMenuName"], before) if r["BTTMenuName"].startswith("hints-")
                            else tc.uid("hints", "menu", r["BTTMenuName"]))
            r["BTTOrder"] = i
        self.preset(d)
        self.assertEqual(self.run_check("--write").returncode, 0)
        _, menu, _, _ = self.hints_parts()
        self.assertEqual([r["BTTMenuName"] for r in menu["BTTMenuItems"]], names)  # hints-next isn't second

    def test_row_names_are_unique_and_icons_share_a_box(self):
        self.toml(GOOD.replace('name = "keep-awake"', 'name = "keep-awake"\nicon = "cup.and.saucer.fill"')
                  + '\n[[trigger]]\nname = "tall"\naction = "Tall"\nhint = "x"\nicon = "arrow.up.and.down"\n'
                    'run = "keep-awake on"\nkeys = ["⌃⌥⇧⌘L"]\n')
        self.assertEqual(self.run_check("--write").returncode, 0)
        _, menu, _, _ = self.hints_parts()
        rows = {r["BTTMenuName"]: r for r in menu["BTTMenuItems"]}
        self.assertEqual(len(rows), len(menu["BTTMenuItems"]))
        wide, narrow, plain = (rows[n]["BTTMenuConfig"] for n in ("keep-awake", "tall", "mic-mute"))
        self.assertEqual(wide["BTTMenuItemSFSymbolStyle"], 1)
        # the box is the widest icon (25): the narrow one (14) sits in its middle, and every
        # row's text starts at the box's far edge, with or without an icon
        self.assertEqual((wide["BTTMenuItemImageOffsetX"], wide["BTTMenuTextOffsetX"]), (0, tc.TEXT_X))
        self.assertEqual((narrow["BTTMenuItemImageOffsetX"], narrow["BTTMenuTextOffsetX"]), (5.5, tc.TEXT_X + 11))
        self.assertEqual(plain["BTTMenuTextOffsetX"], tc.TEXT_X + 25 + tc.NO_ICON)
        self.assertEqual(rows["hints-next"]["BTTMenuConfig"]["BTTMenuTextOffsetX"], tc.TEXT_X + 25 + tc.NO_ICON)
        self.assertEqual(rows["Header"]["BTTMenuConfig"]["BTTMenuTextOffsetX"], tc.TEXT_X)
        # a re-created row has its own action, not the old row's
        acts = [a["BTTUUID"] for r in menu["BTTMenuItems"] for a in r.get("BTTMenuItemActions", [])]
        self.assertEqual(len(acts), len(set(acts)))

    def test_menu_rows_keep_btts_order(self):
        self.run_check("--write")
        d = self.read_preset()
        menu = next(t for t in d["BTTPresetContent"][0]["BTTTriggers"] if t.get("BTTTriggerType") == 767)
        for i, r in enumerate(reversed(menu["BTTMenuItems"])):  # BTT keeps a row's order on import
            r["BTTOrder"] = i
        menu["BTTMenuItems"].sort(key=lambda r: (r["BTTOrder"], r["BTTUUID"]))
        self.preset(d)
        self.assertEqual(self.run_check().returncode, 0)
        # a new trigger's row goes after the last
        self.toml(GOOD + '\n[[trigger]]\nname = "late"\naction = "Late"\nhint = "x"\nrun = "keep-awake on"\nkeys = ["⌃⌥⇧⌘L"]\n')
        self.run_check("--write")
        _, menu, _, _ = self.hints_parts()
        self.assertEqual([i["BTTMenuName"] for i in menu["BTTMenuItems"]][-3:], ["late", "hints-next", "hints-mute"])

    def test_apps_must_be_bundle_ids(self):
        p = self.problems(GOOD.replace('keys = ["⌃⌥⇧⌘K"]', 'keys = ["⌃⌥⇧⌘K"]\napps = "us.zoom.xos"'))
        self.assertTrue(any("apps must be a list of bundle IDs" in x for x in p), p)

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


class Search(unittest.TestCase):
    """triggers (the Raycast "Search Triggers" command) over the repo's triggers.toml."""

    def run_search(self, *words):
        return subprocess.run([sys.executable, "-I", os.path.join(REPO, "dot_local/bin/executable_triggers"), *words],
                              env=dict(os.environ, CHEZMOI_SOURCE_DIR=REPO), capture_output=True, text=True)

    def test_lists_every_trigger_with_its_key(self):
        out = self.run_search().stdout
        for t in tc.load(REPO):
            self.assertIn(f"{t['name']}: ", out)
            self.assertIn(tc.key_label(t), out)

    def test_all_words_must_match(self):
        out = self.run_search("mic", "MUTE").stdout
        self.assertIn("mic-mute: ", out)
        self.assertNotIn("keep-awake: ", out)
        self.assertIn("also Stream Deck", out)

    def test_no_match(self):
        r = self.run_search("zzz-nothing")
        self.assertEqual(r.returncode, 1)
        self.assertIn("No trigger matches", r.stdout)


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
