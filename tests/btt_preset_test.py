#!/usr/bin/env python3
"""Guards the committed BetterTouchTool preset (macos/btt/Default.bttpreset): it's
normalized as btt-sync leaves it (sorted keys, no machine state) and keeps the pinned
settings (no Imgur uploads, no usage logging, BTT off the Stream Deck).
Standard library only:  python3 -I tests/btt_preset_test.py"""
import ast
import json
import os
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PRESET = os.path.join(ROOT, "macos", "btt", "Default.bttpreset")
SYNC = os.path.join(ROOT, "dot_local", "bin", "executable_btt-sync")


def sync_set(name):
    """The VOLATILE set or PINNED dict from btt-sync's embedded Python."""
    src = open(SYNC, encoding="utf-8").read()
    body = src[src.index("<<'PYEOF2'\n") + 11:src.index("\nPYEOF2")]
    for node in ast.parse(body).body:
        if isinstance(node, ast.Assign) and getattr(node.targets[0], "id", None) == name:
            return ast.literal_eval(node.value)
    raise KeyError(name)


class Preset(unittest.TestCase):
    def setUp(self):
        self.text = open(PRESET, encoding="utf-8").read()
        self.data = json.loads(self.text)
        self.general = self.data["BTTGeneralSettings"]

    def test_normalized(self):
        want = json.dumps(self.data, indent=2, separators=(",", " : "), ensure_ascii=False, sort_keys=True) + "\n"
        self.assertEqual(self.text, want, "run btt-sync normalize")

    def test_no_machine_state(self):
        self.assertFalse(sync_set("VOLATILE") & set(self.general))

    def test_no_update_times(self):
        self.assertNotIn('"BTTLastUpdatedAt"', self.text, "run btt-sync normalize")

    def test_pinned_settings(self):
        for k, v in sync_set("PINNED").items():
            self.assertEqual(self.general.get(k), v, k)


if __name__ == "__main__":
    unittest.main()
