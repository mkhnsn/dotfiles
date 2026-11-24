#!/usr/bin/env python3
"""Tools that load a sibling tool as a module must not leave __pycache__ next to
it: Python would cache the sibling there, and the folder would land in ~/.local/bin.
Standard library only:  python3 -I tests/no_pycache_test.py"""
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

BIN = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "dot_local", "bin")
# tool -> the expression, over the tool's globals `ns`, that is the sibling module it loaded.
LOADERS = {"triggers": "ns['trigger_check']()", "hints": "ns['TC']", "layout": "ns['hints_module']()"}
# Loads the tool without running its main (and without caching the tool itself),
# then fails unless the sibling module really was loaded.
RUN = "import runpy, sys, types; ns = runpy.run_path(sys.argv[1]); assert isinstance(eval(sys.argv[2]), types.ModuleType)"


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

    def test_loading_a_sibling_leaves_no_pycache(self):
        for tool, sibling in LOADERS.items():
            with self.subTest(tool=tool), tempfile.TemporaryDirectory() as tmp:
                for name in os.listdir(BIN):
                    src = os.path.join(BIN, name)
                    if name.startswith("executable_") and os.path.isfile(src):
                        shutil.copy(src, os.path.join(tmp, name[len("executable_"):].removesuffix(".tmpl")))
                # Nothing from the real environment: state and config stay out of the real home.
                env = {"PATH": os.environ.get("PATH", ""), "HOME": tmp, "XDG_STATE_HOME": tmp}
                run = subprocess.run([sys.executable, "-I", "-c", RUN, os.path.join(tmp, tool), sibling], env=env,
                                     capture_output=True, text=True, timeout=60)
                self.assertEqual(run.returncode, 0, run.stderr)
                self.assertNotIn("__pycache__", os.listdir(tmp))


if __name__ == "__main__":
    unittest.main()
