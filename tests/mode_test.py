"""Tests for mode (dot_local/bin/executable_mode) and macos/modes.toml. Standard library only:
python3 -I tests/mode_test.py

The Mac is stubbed in-process: desktops, the apps on them and BTT's actions are a small fake."""
import importlib.machinery, importlib.util, os, shutil, tempfile, unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
loader = importlib.machinery.SourceFileLoader("mode_mod", os.path.join(REPO, "dot_local/bin/executable_mode"))
mode = importlib.util.module_from_spec(importlib.util.spec_from_loader("mode_mod", loader))
loader.exec_module(mode)

CFG = {
    "apps": {"code": {"name": "Code", "new_window": ["open", "-na", "Code"]},
             "chrome": {"name": "Chrome", "new_window": ["open", "-na", "Chrome"]},
             "slack": {"name": "Slack"}, "mail": {"name": "Mail"}},
    "mode": [{"name": "dev", "title": "Dev", "key": "1", "layout": [["code", "1-2/3"], ["chrome", "3/3"]]},
             {"name": "comms", "title": "Comms", "key": "4", "layout": [["mail", "1/2"], ["slack", "2/2"]],
              "scene": "scene.x"}],
}


class FakeMac:
    """Desktops (ids in order, the current one) and which desktop each app's windows are on."""

    def __init__(self, desktops, current, windows, other_display=(), fails=(), jumps=()):
        self.desktops, self.current, self.windows = desktops, current, windows  # windows: {app: [space ids]}
        self.other = list(other_display)  # desktops on a second display
        self.fails = set(fails)  # apps that never open a window
        self.jumps = dict(jumps)  # app -> a desktop activating it takes you to, even with a window here
        self.setup = "docked-closed"
        self.log = []

    def install(self, test):
        test.addCleanup(setattr, mode, "desktops", mode.desktops)
        for name in ("desktops", "app_state", "btt", "activate", "notify", "turn_on_scene", "detect_setup",
                     "main_display_width"):
            test.addCleanup(setattr, mode, name, getattr(mode, name))
        mode.desktops = lambda every_display=False: ((self.desktops + self.other, None) if every_display
                                                     else (list(self.desktops), self.current))
        mode.app_state = lambda names: {n: {"running": n in self.windows, "here": self.windows.get(n, []).count(self.current)}
                                        for n in names}
        mode.btt = self.btt
        mode.activate = self.activate
        mode.notify = lambda text: self.log.append(("notify", text))
        mode.turn_on_scene = lambda scene: self.log.append(("scene", scene))
        mode.detect_setup = lambda: self.setup
        mode.main_display_width = lambda: 5120
        test.addCleanup(setattr, mode.subprocess, "run", mode.subprocess.run)
        real_run = mode.subprocess.run
        def run(cmd, **kw):
            if cmd[:2] == ["open", "-na"]:
                return self.run(cmd)
            if cmd[0] == "lsappinfo":  # macOS only; the front app, restored after apply
                return mode.subprocess.CompletedProcess(cmd, 0, "ASN:0x0-0x1:\n" if cmd[1] == "front" else "", "")
            return real_run(cmd, **kw)
        mode.subprocess.run = run
        test.addCleanup(setattr, mode.time, "sleep", mode.time.sleep)
        mode.time.sleep = lambda s: None
        test.addCleanup(setattr, mode, "wait", mode.wait)
        mode.wait = lambda check, timeout=4.0, step=0.15: check()

    def btt(self, action):
        t = action["BTTPredefinedActionType"]
        self.log.append(("btt", t))
        if t == 550:
            self.current = action["BTTAdditionalActionData"]["BTTActionGoToSpaceByID"]
        elif t in mode.MOVE_TO_DESKTOP.values():  # the front app's window to desktop N
            n = next(k for k, v in mode.MOVE_TO_DESKTOP.items() if v == t)
            self.windows[self.front] = [self.desktops[n - 1]]
        elif t == 251:
            self.log.append(("place", self.front, action["BTTActionMoveResizeName"]))

    def activate(self, name):
        self.front = name
        if name in self.jumps:
            self.current = self.jumps[name]
            return
        if name in self.fails:
            return
        spaces = self.windows.setdefault(name, [])
        if not spaces:
            spaces.append(self.current)  # launched here
        elif self.current not in spaces:
            self.current = spaces[0]  # macOS takes you to its desktop

    def run(self, cmd):
        if cmd[2] in self.fails:
            return
        self.windows.setdefault(cmd[2], []).append(self.current)  # a new window here
        self.log.append(("new window", cmd[2]))


class Config(unittest.TestCase):
    def test_repo_modes_are_valid(self):
        cfg = mode.load_config(REPO)
        self.assertEqual(mode.validate(cfg), [])
        self.assertEqual([m["key"] for m in cfg["mode"]], ["1", "2", "3", "4", "5"])

    def test_problems_are_reported(self):
        bad = {"apps": {"a": {"name": "A", "new_window": "open"}},
               "mode": [{"name": "x", "title": "X", "key": "1", "layout": [["a", "9/3"], ["nope", "1/2"]],
                         "scene": "lights"},
                        {"name": "x", "key": "1", "layout": []}]}
        p = mode.validate(bad)
        for want in ("new_window must be a command", "can't read cell '9/3'", "no app 'nope'", "name used twice",
                     "needs title", "key 1 used twice", "needs a layout", "scene must be a Home Assistant scene"):
            self.assertTrue(any(want in x for x in p), (want, p))

    def test_cells(self):
        self.assertEqual(mode.parse_cell("1-2/3"), (1, 2, 3))
        self.assertEqual(mode.parse_cell("3/3"), (3, 1, 3))
        for bad in ("0/3", "2-1/3", "4/3", "a/b", None):
            self.assertIsNone(mode.parse_cell(bad))

    def test_move_to_desktop_actions(self):
        self.assertEqual([mode.MOVE_TO_DESKTOP[n] for n in (1, 5, 6, 9, 10, 19)], [216, 220, 222, 225, 236, 245])


class Switch(unittest.TestCase):
    def setUp(self):
        self.state = {"spaces": {}}

    def test_a_mode_without_a_desktop_takes_this_one_and_lays_out(self):
        mac = FakeMac([1, 2], 2, {"Chrome": [1]})
        mac.install(self)
        self.assertTrue(mode.switch(CFG["mode"][0], CFG, self.state))
        self.assertEqual(self.state, {"spaces": {"dev": 2}, "current": "dev"})
        self.assertIn(("new window", "Chrome"), mac.log)  # Chrome gets a window here; its other one stays
        self.assertEqual(mac.windows["Chrome"], [1, 2])
        self.assertEqual([e for e in mac.log if e[0] == "place"], [("place", "Code", "mode: 1-2/3"), ("place", "Chrome", "mode: 3/3")])

    def test_another_modes_desktop_is_refused(self):
        mac = FakeMac([1, 2], 2, {})
        mac.install(self)
        self.state["spaces"]["dev"] = 2
        self.assertFalse(mode.switch(CFG["mode"][1], CFG, self.state))
        self.assertTrue(any(e[0] == "notify" and "This desktop is Dev's" in e[1] for e in mac.log))
        self.assertNotIn("comms", self.state["spaces"])

    def test_switching_goes_to_the_modes_desktop(self):
        mac = FakeMac([1, 2, 3], 1, {"Code": [3], "Chrome": [3]})
        mac.install(self)
        self.state["spaces"] = {"dev": 3}
        mode.switch(CFG["mode"][0], CFG, self.state)
        self.assertEqual(mac.current, 3)
        self.assertNotIn(("new window", "Chrome"), mac.log)

    def test_single_window_apps_are_brought_to_the_modes_desktop(self):
        mac = FakeMac([1, 2, 3], 3, {"Mail": [1], "Slack": [2]})
        mac.install(self)
        mode.switch(CFG["mode"][1], CFG, self.state)
        self.assertEqual((mac.windows["Mail"], mac.windows["Slack"], mac.current), ([3], [3], 3))
        self.assertIn(("btt", 218), mac.log)  # Move Window To Desktop 3
        self.assertIn(("scene", "scene.x"), mac.log)

    def test_a_closed_desktop_is_forgotten(self):
        mac = FakeMac([1, 5], 5, {})
        mac.install(self)
        self.state["spaces"] = {"dev": 9, "comms": 1}
        mode.switch(CFG["mode"][0], CFG, self.state)
        self.assertEqual(self.state["spaces"], {"comms": 1, "dev": 5})

    def test_travel_puts_each_app_full_screen(self):
        mac = FakeMac([1], 1, {"Chrome": [1]})
        mac.install(self)
        mode.detect_setup = lambda: "laptop"
        mode.switch(CFG["mode"][0], CFG, self.state)
        self.assertEqual([e for e in mac.log if e == ("btt", 112)], [("btt", 112)] * 2)
        self.assertEqual(mac.front, "Code")  # the main app last, in front
        self.assertEqual(self.state["spaces"], {})


class Failures(unittest.TestCase):
    """What the review found: nothing may be placed unless the app's window is here."""

    def setUp(self):
        self.state = {"spaces": {}}

    def places(self, mac):
        return [e for e in mac.log if e[0] == "place"]

    def test_an_app_that_never_opens_isnt_placed(self):
        mac = FakeMac([1, 2], 2, {"Chrome": [2]}, fails={"Code"})
        mac.install(self)
        mode.switch(CFG["mode"][0], CFG, self.state)
        self.assertEqual(self.places(mac), [("place", "Chrome", "mode: 3/3")])
        self.assertTrue(any(e[0] == "notify" and "no window from Code" in e[1] for e in mac.log))

    def test_a_full_screen_window_isnt_placed_and_we_stay_on_the_desktop(self):
        mac = FakeMac([1, 2], 2, {"Mail": [9], "Slack": [2]})  # Mail is full screen on space 9
        mac.install(self)
        orig = mac.btt
        def btt(action):  # Move Window To Desktop can't move a full-screen window
            if action["BTTPredefinedActionType"] in mode.MOVE_TO_DESKTOP.values() and mac.front == "Mail":
                mac.log.append(("btt", action["BTTPredefinedActionType"]))
                return
            orig(action)
        mode.btt = btt
        mode.switch(CFG["mode"][1], CFG, self.state)
        self.assertEqual(mac.current, 2)
        self.assertEqual(self.places(mac), [("place", "Slack", "mode: 2/2")])

    def test_a_jump_to_another_desktop_isnt_placed(self):
        mac = FakeMac([1, 2, 3], 2, {"Code": [2], "Chrome": [2, 3]}, jumps={"Chrome": 3})
        mac.install(self)
        self.state["spaces"] = {"dev": 2}
        mode.switch(CFG["mode"][0], CFG, self.state)
        self.assertEqual((mac.current, self.places(mac)), (2, [("place", "Code", "mode: 1-2/3")]))

    def test_a_full_screen_space_isnt_adopted(self):
        mac = FakeMac([1, 2], 9, {})
        mac.install(self)
        self.assertFalse(mode.switch(CFG["mode"][0], CFG, self.state))
        self.assertEqual(self.state["spaces"], {})
        self.assertTrue(any("full-screen app's space" in e[1] for e in mac.log if e[0] == "notify"))

    def test_no_desktops_or_no_setup_changes_nothing(self):
        mac = FakeMac([], None, {})
        mac.install(self)
        self.assertFalse(mode.switch(CFG["mode"][0], CFG, self.state))
        mac.setup = None
        self.assertFalse(mode.switch(CFG["mode"][0], CFG, self.state))
        self.assertEqual(self.state["spaces"], {})
        self.assertNotIn("current", self.state)

    def test_a_desktop_on_another_display_isnt_forgotten(self):
        mac = FakeMac([1, 2], 2, {}, other_display=[7])
        mac.install(self)
        self.state["spaces"] = {"dev": 7}
        mode.switch(CFG["mode"][1], CFG, self.state)
        self.assertEqual(self.state["spaces"]["dev"], 7)

    def test_lid_open_beside_the_ultrawide_is_docked(self):
        mac = FakeMac([1, 2], 2, {"Chrome": [2]})
        mac.install(self)
        mac.setup = "docked-open"
        mode.switch(CFG["mode"][0], CFG, self.state)
        self.assertNotIn(("btt", 112), mac.log)
        self.assertEqual(self.state["spaces"], {"dev": 2})


class Apply(unittest.TestCase):
    def test_lays_out_again_only_on_the_modes_desktop(self):
        mac = FakeMac([1, 2], 2, {"Code": [2], "Chrome": [2]})
        mac.install(self)
        state = {"spaces": {"dev": 2}, "current": "dev"}
        mode.apply(CFG, state)
        self.assertEqual(len([e for e in mac.log if e[0] == "place"]), 2)
        mac.log.clear()
        mac.current = 1
        mode.apply(CFG, state)
        self.assertEqual([e for e in mac.log if e[0] == "place"], [])

    def test_one_layout_per_dock(self):
        mac = FakeMac([1, 2], 2, {"Code": [2], "Chrome": [2]})
        mac.install(self)
        state = {"spaces": {"dev": 2}, "current": "dev"}
        mode.apply(CFG, state)
        mode.apply(CFG, state)  # the next display event of the same dock
        self.assertEqual(len([e for e in mac.log if e[0] == "place"]), 2)

    def test_leaves_the_kvm_placeholder_alone(self):
        mac = FakeMac([1], 1, {"Code": [1]})
        mac.install(self)
        mode.main_display_width = lambda: 1920
        mode.apply(CFG, {"spaces": {"dev": 1}, "current": "dev"})
        self.assertEqual(mac.log, [])


class State(unittest.TestCase):
    def test_bad_state_is_replaced(self):
        d = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, d)
        old = mode.STATE
        mode.STATE = os.path.join(d, "mode.json")
        self.addCleanup(setattr, mode, "STATE", old)
        for bad in ("[]", "{not json", '{"spaces": 3}'):
            with open(mode.STATE, "w") as f:
                f.write(bad)
            self.assertEqual(mode.load_state()["spaces"], {})

    def test_desktops_reads_the_first_display_with_desktops(self):
        import plistlib
        d = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, d)
        p = os.path.join(d, "spaces.plist")
        with open(p, "wb") as f:
            plistlib.dump([{"Display Identifier": "x", "Spaces": []},
                           {"Display Identifier": "Main", "Current Space": {"ManagedSpaceID": 7},
                            "Spaces": [{"ManagedSpaceID": 1, "type": 0}, {"ManagedSpaceID": 9, "type": 4},
                                       {"ManagedSpaceID": 7, "type": 0}]}], f)
        os.environ["MODE_SPACES"] = p
        self.addCleanup(os.environ.pop, "MODE_SPACES")
        self.assertEqual(mode.desktops(), ([1, 7], 7))  # full-screen spaces (type 4) aren't desktops


if __name__ == "__main__":
    unittest.main()
