#!/usr/bin/env python3
"""Guards the committed BetterTouchTool preset (macos/btt/Default.bttpreset): it's
normalized as btt-sync leaves it (sorted keys, no machine state) and keeps the pinned
settings (no Imgur uploads, no usage logging, BTT off the Stream Deck).
Standard library only:  python3 -I tests/btt_preset_test.py"""
import ast
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PRESET = os.path.join(ROOT, "macos", "btt", "Default.bttpreset")
SYNC = os.path.join(ROOT, "dot_local", "bin", "executable_btt-sync")


def sync_python():
    """btt-sync's embedded normalize script."""
    with open(SYNC, encoding="utf-8") as f:
        src = f.read()
    return src[src.index("<<'PYEOF2'\n") + 11:src.index("\nPYEOF2")]


def sync_set(name):
    """The VOLATILE set or PINNED dict from btt-sync's embedded Python."""
    for node in ast.parse(sync_python()).body:
        if isinstance(node, ast.Assign) and getattr(node.targets[0], "id", None) == name:
            return ast.literal_eval(node.value)
    raise KeyError(name)


class Preset(unittest.TestCase):
    def setUp(self):
        with open(PRESET, encoding="utf-8") as f:
            self.text = f.read()
        self.data = json.loads(self.text)
        self.general = self.data["BTTGeneralSettings"]

    def test_normalized(self):
        want = json.dumps(self.data, indent=2, separators=(",", " : "), ensure_ascii=False, sort_keys=True) + "\n"
        self.assertEqual(self.text, want, "run btt-sync normalize")

    def test_no_machine_state(self):
        self.assertFalse(sync_set("VOLATILE") & set(self.general))

    def test_no_update_times(self):
        self.assertNotIn('"BTTLastUpdatedAt"', self.text, "run btt-sync normalize")

    def test_normalize_strips_update_times_at_every_depth(self):
        d = tempfile.mkdtemp()
        try:
            p = os.path.join(d, "Default.bttpreset")
            with open(p, "w", encoding="utf-8") as f:
                json.dump({"BTTGeneralSettings": {"BTTNumberOfStarts": 3, "keep": 1},
                           "BTTPresetContent": [{"BTTLastUpdatedAt": 1, "BTTTriggers": [
                               {"BTTLastUpdatedAt": 2, "BTTUUID": "T",
                                "BTTActionsToExecute": [{"BTTLastUpdatedAt": 3, "BTTUUID": "A"}]}]}]}, f)
            subprocess.run([sys.executable, "-I", "-", p], input=sync_python(), text=True, check=True)
            with open(p, encoding="utf-8") as f:
                text = f.read()
            out = json.loads(text)
        finally:
            shutil.rmtree(d)
        self.assertNotIn("BTTLastUpdatedAt", text)
        self.assertNotIn("BTTNumberOfStarts", out["BTTGeneralSettings"])
        self.assertEqual(out["BTTGeneralSettings"]["keep"], 1)
        self.assertEqual(out["BTTPresetContent"][0]["BTTTriggers"][0]["BTTActionsToExecute"][0]["BTTUUID"], "A")

    def test_pinned_settings(self):
        for k, v in sync_set("PINNED").items():
            self.assertEqual(self.general.get(k), v, k)


if __name__ == "__main__":
    unittest.main()
