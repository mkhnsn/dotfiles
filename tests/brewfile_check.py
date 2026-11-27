#!/usr/bin/env python3
"""Check every Homebrew core entry in the Brewfiles exists as the type it's listed as.

A `brew "x"` that Homebrew only has as a cask (or the other way round), a renamed formula,
or a disabled one makes `brew bundle` fail on a new Mac; this catches it in the repo first.
Entries from third-party taps (`owner/tap/name`) and `mas` apps are skipped: the public API
only covers homebrew/core and homebrew/cask.

Asks formulae.brew.sh (no Homebrew needed, so it runs on Linux CI). Network trouble is a
warning, not a failure. Standard library only:  python3 -I tests/brewfile_check.py
"""
import concurrent.futures
import json
import os
import re
import sys
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BREWFILES = ["Brewfile", "Brewfile.workstation", "Brewfile.server"]
API = "https://formulae.brew.sh/api/{kind}/{name}.json"
OTHER = {"formula": "cask", "cask": "formula"}


def entries():
    for bf in BREWFILES:
        with open(os.path.join(ROOT, bf), encoding="utf-8") as f:
            for n, line in enumerate(f, 1):
                m = re.match(r'\s*(brew|cask)\s+"([^"]+)"', line)
                if m and "/" not in m.group(2):
                    kind = "formula" if m.group(1) == "brew" else "cask"
                    yield f"{bf}:{n}", m.group(1), kind, m.group(2)


def fetch(kind, name):
    """The API's JSON for kind/name, None if Homebrew has no such entry."""
    req = urllib.request.Request(API.format(kind=kind, name=name), headers={"User-Agent": "dotfiles-brewfile-check"})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise


def check(entry):
    where, word, kind, name = entry
    info = fetch(kind, name)
    if info is None:
        other = OTHER[kind]
        if fetch(other, name) is not None:
            fix = "cask" if other == "cask" else "brew"
            return f'{where}: {word} "{name}" is a {other} in Homebrew; use {fix} "{name}"'
        return f'{where}: {word} "{name}" isn\'t in Homebrew (renamed or removed?)'
    if info.get("disabled"):
        return f'{where}: {word} "{name}" is disabled in Homebrew ({info.get("disable_reason") or "no reason given"})'
    return None


def main():
    todo = list(entries())
    try:
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            problems = [p for p in pool.map(check, todo) if p]
    except (urllib.error.URLError, OSError, TimeoutError) as e:
        print(f"brewfile-check: couldn't reach formulae.brew.sh ({e}); skipped", file=sys.stderr)
        return 0
    for p in problems:
        print(p)
    print(f"brewfile-check: {len(todo)} entries, {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
