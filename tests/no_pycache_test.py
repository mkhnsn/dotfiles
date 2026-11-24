#!/usr/bin/env python3
"""Tools that load a sibling tool as a module must not leave __pycache__ next to
it: BTT, Raycast and launchd run them without the shell's PYTHONDONTWRITEBYTECODE,
and the folder would land in ~/.local/bin.
Standard library only:  python3 -I tests/no_pycache_test.py"""
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

BIN = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "dot_local", "bin")
# tool -> arguments that make it load its sibling and exit without touching the Mac.
LOADERS = {"triggers": ["no-such-trigger-zz"], "hints": ["status"], "mode": ["list"]}


class NoPycache(unittest.TestCase):
    def test_every_loader_is_covered(self):
        found = set()
        for name in os.listdir(BIN):
            path = os.path.join(BIN, name)
            if not name.startswith("executable_") or not os.path.isfile(path):
                continue
            with open(path, errors="replace") as f:
                if "SourceFileLoader(" in f.read():
                    found.add(name[len("executable_"):])
        self.assertEqual(found, set(LOADERS), "add new sibling-loading tools to LOADERS")

    def test_running_a_tool_leaves_no_pycache(self):
        for tool, args in LOADERS.items():
            with self.subTest(tool=tool), tempfile.TemporaryDirectory() as tmp:
                for name in os.listdir(BIN):
                    src = os.path.join(BIN, name)
                    if name.startswith("executable_") and os.path.isfile(src):
                        shutil.copy(src, os.path.join(tmp, name[len("executable_"):].removesuffix(".tmpl")))
                env = {k: v for k, v in os.environ.items() if not k.startswith("PYTHON")}
                env["HOME"] = tmp  # state and config stay out of the real home
                subprocess.run([sys.executable, os.path.join(tmp, tool), *args], env=env,
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=60)
                self.assertNotIn("__pycache__", os.listdir(tmp))


if __name__ == "__main__":
    unittest.main()
