"""Tests for hints (dot_local/bin/executable_hints). Standard library only:
python3 -I tests/hints_test.py

osascript and lsappinfo are stubbed on PATH: notifications are recorded, not shown."""
import datetime, json, os, shutil, subprocess, sys, tempfile, unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HINTS = os.path.join(REPO, "dot_local/bin/executable_hints")

TRIGGERS = '''
[[trigger]]
name = "mic-mute"
action = "Mic"
hint = "Hyper+M mutes the mic"
keys = ["⌃⌥⇧⌘M"]
fires = ["streamdeck"]

[[trigger]]
name = "keep-awake"
action = "Keep Awake"
hint = "Hyper+K keeps the Mac awake"
keys = ["⌃⌥⇧⌘K"]

[[trigger]]
name = "zoom-video"
action = "Camera"
hint = "Hyper+V turns the Zoom camera on or off"
keys = ["⌃⌥⇧⌘V"]
apps = ["us.zoom.xos"]
'''


class Hints(unittest.TestCase):
    def setUp(self):
        self.d = tempfile.mkdtemp()
        self.src, self.state, self.bin = (os.path.join(self.d, x) for x in ("src", "state", "bin"))
        os.makedirs(os.path.join(self.src, "macos/btt"))
        os.makedirs(self.state)
        os.makedirs(self.bin)
        with open(os.path.join(self.src, "macos/btt/triggers.toml"), "w") as f:
            f.write(TRIGGERS)
        self.notes = os.path.join(self.d, "notes")
        # osascript: record the notification's title and body (the last two args); ignore the
        # delayed hints-close call.
        self.stub("osascript", f'case "$*" in *display_notification*) '
                               f'eval "t=\\${{$(($#-1))}}"; eval "b=\\${{$#}}"; '
                               f'printf "%s | %s\\n" "$t" "$b" >> {self.notes} ;; '
                               f'*update_menu_item*) eval "i=\\${{$(($#-1))}}"; eval "j=\\${{$#}}"; '
                               f'printf "MENU | %s | %s\\n" "$i" "$j" >> {self.notes} ;; esac')
        self.front("com.apple.Terminal", "Terminal")
        self.stub("sleep", "exit 0")
        self.stub("pgrep", "echo 100")  # BTT's pid
        self.setup = "laptop"

    def tearDown(self):
        shutil.rmtree(self.d)

    def stub(self, name, body):
        p = os.path.join(self.bin, name)
        with open(p, "w") as f:
            f.write("#!/bin/sh\n" + body + "\n")
        os.chmod(p, 0o755)

    def front(self, bundle, name):
        self.stub("lsappinfo", f'case "$*" in front) echo ASN:0x0-0x1: ;; '
                               f'*bundleid*) echo \'"x" ASN:0x0-0x1: (in front)\'; echo \'    bundleID="{bundle}"\' ;; '
                               f'*name*) echo \'"{name}" ASN:0x0-0x1: (in front)\' ;; esac')

    def run_hints(self, *args):
        env = dict(os.environ, PATH=self.bin + ":/usr/bin:/bin", XDG_STATE_HOME=self.state,
                   CHEZMOI_SOURCE_DIR=self.src, HINTS_SETUP=self.setup)
        return subprocess.run([sys.executable, "-I", HINTS, *args], env=env, capture_output=True, text=True)

    def lines(self):
        try:
            with open(self.notes) as f:
                return f.read().splitlines()
        except OSError:
            return []

    def shown(self):
        """Notifications shown (not cheat-sheet updates)."""
        return [l for l in self.lines() if not l.startswith("MENU ")]

    def state_json(self):
        with open(os.path.join(self.state, "hints.json")) as f:
            return json.load(f)

    def fired(self, name, times):
        with open(os.path.join(self.state, "triggers.log"), "a") as f:
            f.write(f"2026-11-23T00:00:00-0800 {name} key\n" * times)

    def test_first_switch_of_the_day_shows_one_general_hint(self):
        self.run_hints("app")
        self.assertEqual(self.shown(), ["Hint | Hyper+M mutes the mic · Hyper+H for all"])
        self.run_hints("app")  # same day: nothing more
        self.assertEqual(len(self.shown()), 1)
        self.assertEqual(self.state_json()["shown_on"]["general"], datetime.date.today().isoformat())

    def test_app_with_hints_gets_its_own_once_a_day(self):
        self.front("us.zoom.xos", "zoom.us")
        self.run_hints("app")
        self.run_hints("app")
        self.assertEqual(self.shown(), ["Hint | Hyper+M mutes the mic · Hyper+H for all",
                                        "Hint: zoom.us | Hyper+V turns the Zoom camera on or off · Hyper+H for all"])

    def test_rotates_unseen_first_and_skips_known(self):
        self.fired("mic-mute", 3)  # known
        self.run_hints("next")
        self.run_hints("next")
        self.run_hints("next")
        self.assertEqual([s.split(" | ")[1].split(" ·")[0] for s in self.shown()],
                         ["Hyper+K keeps the Mac awake"] * 3)  # the only general hint left
        self.fired("keep-awake", 3)
        r = self.run_hints("next")  # all known: still answers, least shown first
        self.assertEqual(r.returncode, 0)
        self.assertEqual(len(self.shown()), 4)

    def test_next_alternates_between_unseen_hints(self):
        self.run_hints("next")
        self.run_hints("next")
        self.assertEqual([s.split(" | ")[1][:7] for s in self.shown()], ["Hyper+M", "Hyper+K"])

    def test_mute_takes_todays_last_hint_and_unmute_restores(self):
        self.run_hints("app")
        r = self.run_hints("mute")
        self.assertIn("muted general", r.stdout)
        self.assertEqual(self.state_json()["muted"], ["general"])
        self.run_hints("app")
        self.assertEqual(len(self.shown()), 2)  # the hint, then "Hints muted"; no new hint
        self.run_hints("unmute", "general")
        self.assertEqual(self.state_json()["muted"], [])

    def test_mute_without_a_hint_today_takes_the_app_in_front(self):
        st = os.path.join(self.state, "hints.json")
        with open(st, "w") as f:
            json.dump({"last": {"scope": "us.zoom.xos", "on": "2020-01-01"}}, f)
        self.front("com.apple.Safari", "Safari")  # no hints of its own: general
        self.assertIn("muted general", self.run_hints("mute").stdout)
        self.run_hints("unmute", "general")
        self.front("us.zoom.xos", "zoom.us")
        self.assertIn("muted us.zoom.xos", self.run_hints("mute").stdout)

    def test_next_prefers_the_app_in_front(self):
        self.front("us.zoom.xos", "zoom.us")
        self.run_hints("next")
        self.assertTrue(self.shown()[0].startswith("Hint: zoom.us | Hyper+V"))

    def test_parallel_runs_show_the_daily_hint_once(self):
        env = dict(os.environ, PATH=self.bin + ":/usr/bin:/bin", XDG_STATE_HOME=self.state,
                   CHEZMOI_SOURCE_DIR=self.src, HINTS_SETUP=self.setup)
        procs = [subprocess.Popen([sys.executable, "-I", HINTS, "app"], env=env,
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE) for _ in range(12)]
        errs = [p.communicate()[1] for p in procs]
        self.assertEqual([p.returncode for p in procs], [0] * 12, errs)
        self.assertEqual(len(self.shown()), 1)
        self.assertTrue(self.state_json()["enabled"])

    def test_off_silences_daily_hints_but_not_next(self):
        self.run_hints("off")
        self.run_hints("app")
        self.assertEqual(self.shown(), [])
        self.run_hints("next")
        self.assertEqual(len(self.shown()), 1)
        self.run_hints("on")
        self.assertTrue(self.state_json()["enabled"])

    def test_status_lists_known_triggers(self):
        self.fired("mic-mute", 3)
        out = self.run_hints("status").stdout
        self.assertIn("hints: on", out)
        self.assertIn("mic-mute         shown 0, fired 3 (known)", out)

    @unittest.skipUnless(os.path.exists("/opt/homebrew/bin/python3") and subprocess.run(
        ["/usr/bin/python3", "-c", "import tomllib"], capture_output=True).returncode != 0,
        "needs macOS's Python 3.9 and Homebrew's Python")
    def test_runs_from_btts_bare_path(self):
        """BTT's PATH finds /usr/bin/python3 (3.9, no tomllib): hints re-runs under Homebrew's."""
        env = {"HOME": self.d, "PATH": self.bin + ":/usr/bin:/bin", "XDG_STATE_HOME": self.state,
               "CHEZMOI_SOURCE_DIR": self.src, "HINTS_SETUP": self.setup}
        r = subprocess.run(["/usr/bin/python3", HINTS, "next"], env=env, capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(len(self.shown()), 1)

    # ---- setups (#152) ----
    def menu_updates(self):
        return [l for l in self.lines() if l.startswith("MENU ")]

    def test_first_run_notes_the_setup_quietly(self):
        self.setup = "docked-closed"
        self.run_hints("setup")
        self.assertEqual(self.state_json()["setup"], "docked-closed")
        self.assertFalse([l for l in self.shown() if l.startswith("Hint")])
        # the cheat sheet still gets this setup's rows
        rows = {l.split(" | ")[1]: l for l in self.menu_updates()}
        self.assertEqual(set(rows), {"mic-mute", "keep-awake", "zoom-video"})
        self.assertIn("Stream Deck", rows["mic-mute"])

    def test_setup_change_says_what_works_three_times(self):
        self.run_hints("setup")  # laptop, first run: quiet
        for i in range(5):
            self.setup = "docked-closed" if i % 2 == 0 else "laptop"
            self.run_hints("setup")
        hints = [l for l in self.shown() if l.startswith("Hint")]
        self.assertEqual(hints[0], "Hint: Docked, lid closed | Here: Stream Deck and the Hyper keys work. Hyper+H for all.")
        self.assertEqual(hints[1], "Hint: Laptop | Here: the Hyper keys work. Hyper+H for all.")
        self.assertEqual(len(hints), 5)
        self.setup = "docked-closed"
        self.run_hints("setup")  # same setup again: nothing
        self.setup = "laptop"
        self.run_hints("setup")  # a 3rd laptop hint
        self.setup = "docked-closed"
        self.run_hints("setup")  # the docked hints are used up (3)
        hints = [l for l in self.shown() if l.startswith("Hint")]
        self.assertEqual(len(hints), 6)
        self.assertEqual(self.state_json()["setup_shown"], {"docked-closed": 3, "laptop": 3})

    def test_laptop_rows_and_hints_leave_out_desk_surfaces(self):
        self.run_hints("setup")
        rows = {l.split(" | ")[1]: l for l in self.menu_updates()}
        self.assertNotIn("Stream Deck", rows["mic-mute"])
        self.run_hints("next")
        self.assertEqual(self.shown()[-1], "Hint | Hyper+M mutes the mic · Hyper+H for all")
        self.setup = "docked-open"
        self.run_hints("next", "us.zoom.xos")
        self.run_hints("next")
        self.assertIn("Hyper+K", self.shown()[-1])
        os.remove(self.notes)
        self.run_hints("unmute", "x")
        with open(os.path.join(self.state, "hints.json"), "w") as f:
            json.dump({"seen": {"keep-awake": 5, "zoom-video": 5}}, f)
        self.run_hints("next")
        self.assertEqual([l for l in self.shown() if l.startswith("Hint")][-1],
                         "Hint | Hyper+M mutes the mic (or the Stream Deck) · Hyper+H for all")

    def test_app_switch_refreshes_rows_but_leaves_the_setup_hint_to_hints_setup(self):
        self.run_hints("setup")  # notes laptop
        self.setup = "docked-closed"
        self.run_hints("app")
        self.assertEqual(self.state_json()["setup"], "laptop")  # only hints setup moves it
        self.assertEqual(self.state_json()["rows"]["setup"], "docked-closed")
        self.assertFalse([l for l in self.shown() if l.startswith("Hint: Docked")])
        self.run_hints("mute", "setup")
        self.run_hints("setup")
        self.assertEqual(self.state_json()["setup"], "docked-closed")
        self.assertFalse([l for l in self.shown() if l.startswith("Hint: Docked")])

    def test_rows_are_pushed_again_after_btt_restarts(self):
        self.run_hints("setup")
        n = len(self.menu_updates())
        self.run_hints("setup")  # same setup, same BTT: nothing to do
        self.assertEqual(len(self.menu_updates()), n)
        self.stub("pgrep", "echo 200")  # BTT relaunched: it reloaded the preset's rows
        self.run_hints("app")
        self.assertEqual(len(self.menu_updates()), 2 * n)

    # ---- per-app rows (#154) ----
    def row_updates(self, name):
        return [json.loads(l.split(" | ", 2)[2]) for l in self.menu_updates() if l.split(" | ")[1] == name]

    def test_app_rows_show_only_in_their_app(self):
        self.run_hints("setup")  # laptop rows; the zoom row starts hidden
        self.assertEqual(self.row_updates("zoom-video")[-1].get("BTTMenuItemVisibleWhileActive"), 0)
        self.front("us.zoom.xos", "zoom.us")
        self.run_hints("app")
        last = self.row_updates("zoom-video")[-1]
        self.assertEqual((last["BTTMenuItemVisibleWhileActive"], last["BTTMenuItemVisibleWhileInactive"]), (1, 1))
        self.assertNotIn("BTTMenuAttributedText", last)  # same setup: only visibility is sent
        n = len(self.menu_updates())
        self.run_hints("app")  # still Zoom: nothing to send
        self.assertEqual(len(self.menu_updates()), n)
        self.front("com.apple.Safari", "Safari")
        self.run_hints("app")
        self.assertEqual(self.row_updates("zoom-video")[-1]["BTTMenuItemVisibleWhileActive"], 0)
        self.assertEqual([r for r in self.row_updates("mic-mute")][1:], [])  # global rows untouched
        self.front("com.apple.Terminal", "Terminal")
        n = len(self.menu_updates())
        self.run_hints("app")  # another app without rows: nothing changes
        self.assertEqual(len(self.menu_updates()), n)

    def test_refresh_pushes_every_row_again(self):
        self.run_hints("setup")
        n = len(self.menu_updates())
        self.run_hints("refresh")  # after btt-sync import reset them
        self.assertEqual(len(self.menu_updates()), 2 * n)

    def test_a_failed_row_update_is_tried_again(self):
        self.run_hints("setup")
        self.stub("osascript", "exit 1")  # BTT still reloading
        self.front("us.zoom.xos", "zoom.us")
        self.run_hints("app")
        self.assertIsNone(self.state_json()["rows"].get("app"))  # not recorded as done
        self.stub("osascript", f'case "$*" in *update_menu_item*) eval "i=\\${{$(($#-1))}}"; eval "j=\\${{$#}}"; '
                               f'printf "MENU | %s | %s\\n" "$i" "$j" >> {self.notes} ;; esac')
        self.run_hints("app")
        self.assertEqual(self.state_json()["rows"]["app"], "us.zoom.xos")
        self.assertEqual(self.row_updates("zoom-video")[-1]["BTTMenuItemVisibleWhileActive"], 1)

    def test_rows_follow_the_app_with_hints_off(self):
        self.run_hints("off")
        self.front("us.zoom.xos", "zoom.us")
        self.run_hints("app")
        self.assertEqual(self.row_updates("zoom-video")[-1]["BTTMenuItemVisibleWhileActive"], 1)
        self.assertEqual(self.shown(), [])

    def test_unknown_command_prints_the_commands(self):
        r = self.run_hints("bogus")
        self.assertEqual(r.returncode, 2)
        self.assertIn("hints unmute <bundle-id|general|setup>", r.stdout)

    def test_state_of_the_wrong_shape_is_replaced(self):
        for bad in ("[]", '{"muted": null, "seen": 3, "last": "general"}'):
            with open(os.path.join(self.state, "hints.json"), "w") as f:
                f.write(bad)
            self.assertEqual(self.run_hints("mute").returncode, 0, bad)

    def test_corrupt_state_is_replaced(self):
        with open(os.path.join(self.state, "hints.json"), "w") as f:
            f.write("{not json")
        self.assertEqual(self.run_hints("app").returncode, 0)
        self.assertTrue(self.state_json()["enabled"])


class DetectSetup(unittest.TestCase):
    """detect_setup against a fake CoreGraphics: (built-in?, asleep?) per online display."""

    @classmethod
    def setUpClass(cls):
        import importlib.machinery, importlib.util
        loader = importlib.machinery.SourceFileLoader("hints_mod", HINTS)
        cls.h = importlib.util.module_from_spec(importlib.util.spec_from_loader("hints_mod", loader))
        loader.exec_module(cls.h)

    def detect(self, displays, rc=0):
        class Fn:
            def __init__(self, f):
                self.f, self.restype = f, None

            def __call__(self, *a):
                return self.f(*a)

        def online(maximum, ids, n):
            for i in range(len(displays)):
                ids[i] = i + 1
            n._obj.value = len(displays)
            return rc

        cg = type("CG", (), {})()
        cg.CGGetOnlineDisplayList = Fn(online)
        cg.CGDisplayIsBuiltin = Fn(lambda d: displays[d - 1][0])
        cg.CGDisplayIsAsleep = Fn(lambda d: displays[d - 1][1])
        os.environ.pop("HINTS_SETUP", None)
        return self.h.detect_setup(cg)

    def test_setups(self):
        self.assertEqual(self.detect([(True, False)]), "laptop")
        self.assertEqual(self.detect([(False, False)]), "docked-closed")
        self.assertEqual(self.detect([(True, False), (False, False)]), "docked-open")

    def test_a_sleeping_external_is_still_docked(self):
        self.assertEqual(self.detect([(False, True)]), "docked-closed")
        self.assertEqual(self.detect([(True, False), (False, True)]), "docked-open")

    def test_no_displays_or_an_error_is_unknown(self):
        self.assertIsNone(self.detect([]))
        self.assertIsNone(self.detect([(False, False)], rc=1001))
        self.assertIsNone(self.detect([(True, True)]))  # built-in asleep, nothing else: can't tell


if __name__ == "__main__":
    unittest.main()
