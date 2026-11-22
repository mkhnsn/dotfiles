# Claude Code memories in sync across machines (#117)

Status: design. Waiting on one decision: creating the private repo (below).

`claude-sync` moves memories and prompt history once, from an old Mac to a new one. Day to day,
a memory saved on this Mac (136 memory files) is missing on echo-turbine (15), and the other way
round.

## Constraints

- Memories are `~/.claude/projects/<project>/memory/*.md` plus each folder's `MEMORY.md` index.
  Claude Code keeps them per machine on purpose: "Auto memory is machine-local"
  ([code.claude.com/docs/en/memory](https://code.claude.com/docs/en/memory)). `<project>` comes
  from the git repo, so worktrees share one folder.
- The project folder is the absolute path with `/` and `.` turned into `-`, so the same repo is
  `-Users-mkhnsn-src-github-com-unstable-studios-mister-handy` here and
  `-home-mkhnsn-src-github-com-unstable-studios-mister-handy` on echo-turbine. Repos are under
  `~/src` (ghq) on both.
- Memories can hold private details (people, hosts, clients). They can't go in the public
  dotfiles, and they need history so a bad edit can be undone.
- echo-turbine is Fedora with no OneDrive client; it's reached over the tailnet.

## Design: a private git repo, synced by Claude Code hooks

1. **Repo**: a private GitHub repo, `mkhnsn/claude-memory`, cloned to
   `~/.local/share/claude-memory` on each machine. Layout is by path under the home folder:
   `home/src-github-com-unstable-studios-mister-handy/<memory files>`, and `home/` itself for
   `~/` (`-Users-mkhnsn` / `-home-mkhnsn`). Projects outside the home folder (`/private/tmp`,
   scratch dirs) aren't synced.
2. **Link, don't copy**: each `~/.claude/projects/<project>/memory` becomes a symlink to its
   folder in the clone, so Claude Code reads and writes the repo directly. `claude-memory sync`
   adopts any memory folder that's still a real folder (moves its files in, merges with what's
   there, replaces it with the link), so new projects join on the next sync. The docs don't say
   whether Claude Code keeps a symlinked memory folder; the first step of the build is to check
   that a memory saved in a session lands in the clone and the link survives.
3. **When**: a `SessionStart` hook runs `claude-memory pull` (quick, 5 s timeout, offline is
   fine) and a `SessionEnd` hook runs `claude-memory push` (commit as `<host>: <n> memories`,
   pull, push). A launchd/systemd timer every 30 minutes covers long sessions and machines left
   on. Both are in the dotfiles (`dot_claude/modify_settings.json`, a launchd agent, a systemd
   user timer) and do nothing until the clone exists.
4. **Conflicts**: `MEMORY.md` uses git's `merge=union` (`.gitattributes`): it's one line per
   memory, so both sides' lines are kept; `sync` then removes duplicate lines. A memory file
   edited on both machines keeps this machine's version and saves the other as
   `<name>.conflict-<host>.md`. The `SessionStart` hook prints those names, so the session sees
   them and asks to merge; the end-of-apply summary lists them too. Nothing is dropped silently.
5. **Setup**: `claude-memory init` (clone, link, first sync) as a `mac-setup` step and in
   echo-turbine's bootstrap. The first sync on each machine merges the two sets: different
   files just add up, same-named files that differ become `.conflict-<host>.md`.

## What happens to `claude-sync`

It stays for the new-Mac move only: prompt history (`history.jsonl`) and, with `--transcripts`,
session transcripts. Its memory part goes, since the repo carries memories. README and
CLAUDE.md say so in the same change.

Prompt history isn't synced continuously: it's per machine (paths and hosts differ), append-only
and large, and up-arrow history from another machine is rarely wanted.

## Decisions needed

1. **Create the private repo** `mkhnsn/claude-memory` (or another name), and give echo-turbine
   access to it (its GitHub SSH key, or a fine-grained token for that one repo).
2. **Hook timing**: `SessionStart` + `SessionEnd` + a 30-minute timer, as above, or the timer
   only (no hook latency at session start).

## Not chosen

- **OneDrive**: no client on echo-turbine (rclone would be a second sync engine to run), and
  OneDrive's conflict copies are named `<file>-<computer>.md` without notice.
- **Syncthing over the tailnet**: continuous and serverless, but no history, `.sync-conflict`
  files appear silently, and it needs a daemon on each machine plus folder mapping for the
  different project names (one share per project).
- **`autoMemoryDirectory`** (a setting, any scope, absolute or `~/` path): at user scope it would
  put every project's memories in one folder; per project it needs a local settings file in each
  repo on each machine, which is the same bookkeeping as the links with more files to keep.
  It's the fallback if Claude Code replaces symlinked folders.
- **Copying in hooks instead of symlinks**: two copies to keep in step, and a memory written
  mid-session isn't in the repo until the copy runs.
