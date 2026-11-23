"""claude-memory across two fake machines sharing a local bare repo."""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "dot_local/bin/executable_claude-memory"


def enc(p):
    import re
    return re.sub(r"[^A-Za-z0-9]", "-", str(p))


class Machine:
    def __init__(self, root, name, url):
        self.home = root / name
        self.name = name
        self.env = {**os.environ, "HOME": str(self.home), "CLAUDE_MEMORY_URL": url,
                    "CLAUDE_MEMORY_HOST": name, "GIT_CONFIG_GLOBAL": str(root / "gitconfig"),
                    "GIT_CONFIG_NOSYSTEM": "1"}
        for k in ("XDG_STATE_HOME", "CLAUDE_CONFIG_DIR", "CLAUDE_MEMORY_DIR", "CLAUDE_MEMORY_SRC"):
            self.env.pop(k, None)
        self.repo = self.home / "src/r"
        self.repo.mkdir(parents=True)
        subprocess.run(["git", "init", "-q", str(self.repo)], check=True, env=self.env)
        self.clone = self.home / ".local/share/claude-memory"
        self.mem = self.clone / "projects/src-r"

    def default_memory(self):
        return self.home / ".claude/projects" / enc(self.repo) / "memory"

    def write_default(self, name, text):
        d = self.default_memory()
        d.mkdir(parents=True, exist_ok=True)
        (d / name).write_text(text)

    def run(self, *args):
        r = subprocess.run([sys.executable, "-I", str(SCRIPT), *args], env=self.env,
                           capture_output=True, text=True, timeout=60)
        if r.returncode != 0:
            raise AssertionError(f"{self.name} {args}: {r.stdout}{r.stderr}")
        return r.stdout


class TwoMachines(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        (root / "gitconfig").write_text("[user]\n\tname = t\n\temail = t@example.com\n"
                                        "[init]\n\tdefaultBranch = main\n")
        remote = root / "remote.git"
        subprocess.run(["git", "init", "-q", "--bare", str(remote)], check=True)
        self.a = Machine(root, "mac", str(remote))
        self.b = Machine(root, "turbine", str(remote))

    def tearDown(self):
        self.tmp.cleanup()

    def init_both(self):
        self.a.write_default("MEMORY.md", "# Index\n- [One](one.md) — a\n")
        self.a.write_default("one.md", "one from mac\n")
        self.a.write_default("same.md", "mac\n")
        self.a.run("init")
        self.b.write_default("MEMORY.md", "# Index\n- [Two](two.md) — b\n")
        self.b.write_default("two.md", "two\n")
        self.b.write_default("same.md", "turbine\n")
        self.b.run("init")
        self.a.run("sync")

    def test_init_moves_memories_and_points_the_checkout(self):
        self.a.write_default("one.md", "one\n")
        self.a.run("init")
        self.assertEqual((self.a.mem / "one.md").read_text(), "one\n")
        self.assertFalse(self.a.default_memory().exists())
        s = json.loads((self.a.repo / ".claude/settings.local.json").read_text())
        self.assertEqual(s["autoMemoryDirectory"], "~/.local/share/claude-memory/projects/src-r")
        r = subprocess.run(["git", "-C", str(self.a.repo), "check-ignore", "-q",
                            ".claude/settings.local.json"], env=self.a.env)
        self.assertEqual(r.returncode, 0, "settings.local.json is ignored")

    def test_symlinked_claude_folder_is_not_written_through(self):
        outside = self.a.home / "outside"
        outside.mkdir()
        (self.a.repo / ".claude").symlink_to(outside)
        self.a.run("init")
        self.assertFalse((outside / "settings.local.json").exists())

    def test_keeps_other_settings(self):
        (self.a.repo / ".claude").mkdir()
        (self.a.repo / ".claude/settings.local.json").write_text('{"model": "x"}')
        self.a.run("init")
        s = json.loads((self.a.repo / ".claude/settings.local.json").read_text())
        self.assertEqual(s["model"], "x")

    def test_first_sync_on_the_second_machine_merges_both_sets(self):
        self.init_both()
        for m in (self.a, self.b):
            m.run("sync")
        for m in (self.a, self.b):
            self.assertEqual((m.mem / "two.md").read_text(), "two\n")
            self.assertEqual((m.mem / "one.md").read_text(), "one from mac\n")
            idx = (m.mem / "MEMORY.md").read_text()
            self.assertIn("- [One]", idx)
            self.assertIn("- [Two]", idx)
            self.assertEqual((m.mem / "same.md").read_text(), "mac\n")
        # The conflict copy stays on the machine that found it.
        self.assertEqual((self.b.mem / "same.conflict-turbine.md").read_text(), "turbine\n")
        self.assertFalse((self.a.mem / "same.conflict-turbine.md").exists())

    def test_edit_on_both_keeps_ours_and_saves_theirs(self):
        self.init_both()
        self.b.run("sync")
        (self.a.mem / "one.md").write_text("mac edit\n")
        (self.b.mem / "one.md").write_text("turbine edit\n")
        self.b.run("sync")
        self.a.run("sync")
        self.assertEqual((self.a.mem / "one.md").read_text(), "mac edit\n")
        self.assertEqual((self.a.mem / "one.conflict-turbine.md").read_text(), "turbine edit\n")
        out = self.a.run("hook-start")
        self.assertIn("one.conflict-turbine.md", out)

    def test_index_merge_is_three_way(self):
        self.init_both()
        self.b.run("sync")
        idx = (self.a.mem / "MEMORY.md").read_text()
        (self.a.mem / "MEMORY.md").write_text(idx.replace("- [Two](two.md) — b\n", ""))
        (self.b.mem / "MEMORY.md").write_text(idx + "- [Three](three.md) — c\n")
        self.b.run("sync")
        self.a.run("sync")
        merged = (self.a.mem / "MEMORY.md").read_text()
        self.assertNotIn("- [Two]", merged, "a removal on this machine sticks")
        self.assertIn("- [Three]", merged, "an addition on the other machine arrives")
        self.assertIn("- [One]", merged)

    def test_delete_on_one_side_edit_on_other_keeps_file(self):
        self.init_both()
        self.b.run("sync")
        (self.a.mem / "two.md").unlink()
        (self.b.mem / "two.md").write_text("two, edited\n")
        self.b.run("sync")
        self.a.run("sync")
        self.assertEqual((self.a.mem / "two.md").read_text(), "two, edited\n")

    def test_index_prose_from_the_default_folder_is_kept(self):
        self.a.write_default("MEMORY.md", "# Index\n- [One](one.md) — a\n")
        self.a.run("init")
        self.a.write_default("MEMORY.md", "# Index\n## Hosts\n- [Two](two.md) — b\nSee notes.\n")
        self.a.run("sync")
        idx = (self.a.mem / "MEMORY.md").read_text()
        self.assertIn("- [Two]", idx)
        copy = (self.a.mem / "MEMORY.conflict-mac.md").read_text()
        self.assertIn("See notes.", copy)

    def test_unpointed_project_memories_stay(self):
        other = self.a.home / ".claude/projects" / enc(self.a.home / "Documents/notes") / "memory"
        other.mkdir(parents=True)
        (other / "n.md").write_text("n\n")
        self.a.run("init")
        self.assertTrue((other / "n.md").exists())
        self.assertIn("not synced", self.a.run("status"))

    def test_two_first_commits_merge(self):
        # Both machines commit to the empty repo before either pushes.
        self.a.write_default("one.md", "one\n")
        self.b.write_default("two.md", "two\n")
        for m in (self.a, self.b):
            subprocess.run(["git", "clone", "-q", m.env["CLAUDE_MEMORY_URL"], str(m.clone)],
                           check=True, env=m.env, capture_output=True)
        self.a.run("sync")
        self.b.run("sync")  # unrelated histories
        self.a.run("sync")
        for m in (self.a, self.b):
            self.assertEqual((m.mem / "one.md").read_text(), "one\n")
            self.assertEqual((m.mem / "two.md").read_text(), "two\n")

    def test_broken_driver_still_keeps_theirs(self):
        self.init_both()
        self.b.run("sync")
        (self.a.mem / "one.md").write_text("mac edit\n")
        (self.b.mem / "one.md").write_text("turbine edit\n")
        self.b.run("sync")
        subprocess.run(["git", "-C", str(self.a.clone), "config", "merge.claude-memory-file.driver",
                        "/nonexistent %O %A %B"], check=True, env=self.a.env)
        env = {**self.a.env}
        subprocess.run(["git", "-C", str(self.a.clone), "commit", "-qam", "mac: 1 memories"],
                       env=env, capture_output=True)
        subprocess.run(["git", "-C", str(self.a.clone), "fetch", "-q"], check=True, env=env)
        import importlib.machinery
        import importlib.util
        from unittest import mock
        keep = ("HOME", "CLAUDE_MEMORY_HOST", "GIT_CONFIG_GLOBAL", "GIT_CONFIG_NOSYSTEM")
        with mock.patch.dict(os.environ, {k: self.a.env[k] for k in keep}):
            loader = importlib.machinery.SourceFileLoader("cm", str(SCRIPT))
            cm = importlib.util.module_from_spec(importlib.util.spec_from_loader("cm", loader))
            loader.exec_module(cm)
            cm.merge_upstream()  # the driver fails: the fallback must still save theirs
        self.assertEqual((self.a.mem / "one.md").read_text(), "mac edit\n")
        self.assertEqual((self.a.mem / "one.conflict-turbine.md").read_text(), "turbine edit\n")

    def test_held_lock_skips_and_a_dead_holder_does_not_block(self):
        import fcntl
        self.a.run("init")
        lock = self.a.home / ".local/state/claude-memory.lock"
        with open(lock, "a") as fh:
            fcntl.flock(fh, fcntl.LOCK_EX)
            self.assertIn("another sync is running", self.a.run("sync"))
        # The holder is gone (file left behind): the next sync runs.
        self.assertNotIn("another sync is running", self.a.run("sync"))

    def test_hooks_do_nothing_without_a_clone(self):
        self.assertEqual(self.a.run("hook-start"), "")
        self.assertEqual(self.a.run("hook-end"), "")

    def test_memory_written_after_init_in_default_folder_moves_on_sync(self):
        self.a.run("init")
        self.a.write_default("late.md", "late\n")
        self.a.run("sync")
        self.assertEqual((self.a.mem / "late.md").read_text(), "late\n")


if __name__ == "__main__":
    unittest.main()
