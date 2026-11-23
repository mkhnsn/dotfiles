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
                               f'printf "%s | %s\\n" "$t" "$b" >> {self.notes} ;; esac')
        self.front("com.apple.Terminal", "Terminal")
        self.stub("sleep", "exit 0")

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
                   CHEZMOI_SOURCE_DIR=self.src)
        return subprocess.run([sys.executable, "-I", HINTS, *args], env=env, capture_output=True, text=True)

    def shown(self):
        try:
            with open(self.notes) as f:
                return f.read().splitlines()
        except OSError:
            return []

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

    def test_mute_takes_the_last_hint_scope_and_unmute_restores(self):
        self.run_hints("app")
        r = self.run_hints("mute")
        self.assertIn("muted general", r.stdout)
        self.assertEqual(self.state_json()["muted"], ["general"])
        os.remove(os.path.join(self.state, "hints.json"))  # a new day, same mute
        self.run_hints("mute", "general")
        self.run_hints("app")
        self.assertFalse(any(s.startswith("Hint |") for s in self.shown()[1:]))
        self.run_hints("unmute", "general")
        self.assertEqual(self.state_json()["muted"], [])

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
               "CHEZMOI_SOURCE_DIR": self.src}
        r = subprocess.run(["/usr/bin/python3", HINTS, "next"], env=env, capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(len(self.shown()), 1)

    def test_unknown_command(self):
        self.assertEqual(self.run_hints("bogus").returncode, 2)

    def test_corrupt_state_is_replaced(self):
        with open(os.path.join(self.state, "hints.json"), "w") as f:
            f.write("{not json")
        self.assertEqual(self.run_hints("app").returncode, 0)
        self.assertTrue(self.state_json()["enabled"])


if __name__ == "__main__":
    unittest.main()
