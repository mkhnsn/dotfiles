"""Tests for layout (dot_local/bin/executable_layout). Standard library only:
python3 -I tests/layout_test.py

The pure parts are tested directly. The commands run with the live windows, the displays and the
setup given in the environment (LAYOUT_WINDOWS, LAYOUT_DISPLAYS, HINTS_SETUP), so nothing on the
Mac is read or moved."""
import importlib.machinery, importlib.util, json, os, subprocess, sys, tempfile, unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LAYOUT = os.path.join(REPO, "dot_local/bin/executable_layout")

sys.dont_write_bytecode = True
_loader = importlib.machinery.SourceFileLoader("layout_mod", LAYOUT)
L = importlib.util.module_from_spec(importlib.util.spec_from_loader("layout_mod", _loader))
_loader.exec_module(L)

WIDE = {"uuid": "WIDE", "bounds": [0, 0, 5120, 1440], "main": True}
SIDE = {"uuid": "SIDE", "bounds": [5120, 0, 1920, 1080], "main": False}
LAPTOP = {"uuid": "LAPTOP", "bounds": [0, 0, 1512, 982], "main": True}


def app(bundle, *windows):
    return {"bundle": bundle, "name": bundle.split(".")[-1],
            "windows": [{"title": t, "position": [x, y], "size": [w, h]} for t, x, y, w, h in windows]}


class Pure(unittest.TestCase):
    def test_capture_is_relative_to_the_display(self):
        layout = L.capture([app("com.a", ("doc", 5200, 100, 800, 600))], [WIDE, SIDE])
        self.assertEqual(layout[0]["windows"][0], {"title": "doc", "display": "SIDE", "frame": [80, 100, 800, 600]})

    def test_capture_uses_the_display_with_most_of_the_window(self):
        # Mostly on WIDE, its right edge spilling onto SIDE.
        layout = L.capture([app("com.a", ("x", 4800, 0, 400, 300))], [WIDE, SIDE])
        self.assertEqual(layout[0]["windows"][0]["display"], "WIDE")

    def test_capture_off_every_display_counts_as_main(self):
        layout = L.capture([app("com.a", ("x", -5000, -5000, 100, 100))], [SIDE, WIDE])
        self.assertEqual(layout[0]["windows"][0]["display"], "WIDE")

    def test_match_by_title_then_order(self):
        pairs, left = L.match(["b", "a", "c"], ["a", "z", "b"])
        self.assertEqual(pairs, [(0, 2), (1, 0), (2, 1)])
        self.assertEqual(left, [])

    def test_match_leaves_saved_windows_with_no_partner(self):
        pairs, left = L.match(["a", "b", "c"], ["a"])
        self.assertEqual(pairs, [(0, 0)])
        self.assertEqual(left, [1, 2])

    def test_capture_skips_a_window_it_couldnt_read(self):
        apps = [{"bundle": "com.a", "name": "a", "windows": [{"title": "x", "position": None, "size": None}]}]
        self.assertEqual(L.capture(apps, [WIDE]), [])

    def test_find_exact_any_case_then_unique_prefix(self):
        saved = {"focus": 1, "focus 2": 2, "deep work": 3}
        self.assertEqual(L.find(saved, "Focus"), "focus")
        self.assertEqual(L.find(saved, "deep"), "deep work")
        self.assertIsNone(L.find(saved, "f"))

    def test_place_on_its_display(self):
        self.assertEqual(L.place([80, 100, 800, 600], "SIDE", [WIDE, SIDE]), [5200, 100, 800, 600])

    def test_place_missing_display_goes_to_main_and_fits(self):
        self.assertEqual(L.place([1500, 0, 3000, 1400], "SIDE", [LAPTOP]), [0, 0, 1512, 982])

    def test_plan_skips_what_it_cant_find_and_ignores_extra_windows(self):
        layout = L.capture([app("com.a", ("one", 0, 0, 100, 100), ("two", 100, 0, 100, 100)),
                            app("com.gone", ("x", 0, 0, 10, 10))], [WIDE])
        live = [app("com.a", ("two", 9, 9, 9, 9)), app("com.extra", ("y", 1, 1, 1, 1))]
        moves, skipped = L.plan(layout, live, [WIDE])
        self.assertEqual(moves, [{"bundle": "com.a", "name": "a", "index": 0, "title": "two", "frame": [100, 0, 100, 100]}])
        self.assertEqual(sorted(skipped), ["a: one", "gone: x"])


class Commands(unittest.TestCase):
    def setUp(self):
        self.d = tempfile.mkdtemp()
        self.env = {**os.environ, "LAYOUT_STATE": os.path.join(self.d, "layouts.json"), "HINTS_SETUP": "docked-open",
                    "LAYOUT_DISPLAYS": json.dumps([WIDE, SIDE]),
                    "LAYOUT_WINDOWS": json.dumps([app("com.a", ("doc", 10, 20, 800, 600))])}

    def run_layout(self, *args, **env):
        return subprocess.run([sys.executable, LAYOUT, *args], capture_output=True, text=True, env={**self.env, **env})

    def state(self):
        with open(self.env["LAYOUT_STATE"]) as f:
            return json.load(f)

    def test_save_list_restore_rm(self):
        r = self.run_layout("save", "deep", "work")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("Saved deep work (docked-open): 1 window in 1 app", r.stdout)
        self.assertEqual(self.state()["setups"]["docked-open"]["deep work"]["apps"][0]["bundle"], "com.a")
        self.assertIn("deep work  1 windows: a", self.run_layout("list").stdout)
        r = self.run_layout("restore", "deep")  # a unique prefix is enough
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("Restored deep work: 1 window", r.stdout)
        self.assertEqual(self.run_layout("rm", "deep work").returncode, 0)
        self.assertEqual(self.state()["setups"]["docked-open"], {})

    def test_layouts_are_per_setup(self):
        self.run_layout("save", "focus")
        r = self.run_layout("restore", "focus", HINTS_SETUP="laptop")
        self.assertEqual(r.returncode, 1)
        self.assertIn("no layout 'focus' for laptop", r.stdout)
        self.assertIn("no layouts for laptop", self.run_layout("list", HINTS_SETUP="laptop").stdout)

    def test_restore_lists_what_it_skipped(self):
        self.run_layout("save", "focus")
        r = self.run_layout("restore", "focus", LAYOUT_WINDOWS="[]")
        self.assertIn("Restored focus: 0 windows; skipped 1", r.stdout)
        self.assertIn("skipped a: doc", r.stdout)

    def test_save_with_nothing_on_screen(self):
        r = self.run_layout("save", "empty", LAYOUT_WINDOWS="[]")
        self.assertEqual(r.returncode, 1)
        self.assertFalse(os.path.exists(self.env["LAYOUT_STATE"]))

    def test_rm_unknown_and_usage(self):
        self.assertEqual(self.run_layout("rm", "nope").returncode, 1)
        r = self.run_layout()
        self.assertEqual(r.returncode, 2)
        self.assertIn("layout save [name]", r.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=1)
