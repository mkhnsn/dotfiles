# Claude Code memories in sync across machines (#117)

Status: design. Waiting on the decisions at the end.

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
   `projects/<rel>/` where `<rel>` is the project folder name with the literal prefix
   `-Users-mkhnsn-` or `-home-mkhnsn-` removed (`src-github-com-unstable-studios-mister-handy`;
   `-Users-mkhnsn--local-share-chezmoi` becomes `-local-share-chezmoi`, so every git and file
   command gets `--` before paths). `~/` itself is `projects/_home/`. The encoding can't be
   reversed, so only the prefix is rewritten. Projects outside the home folder (`/private/tmp`,
   scratch dirs) aren't synced, and Mac-only ones (`Library-CloudStorage-…`) just never appear on
   echo-turbine.
2. **Point Claude Code at the clone**: `autoMemoryDirectory` (a setting, any scope, absolute or
   `~/` path; [code.claude.com/docs/en/memory](https://code.claude.com/docs/en/memory)).
   `claude-memory sync` writes it into each synced repo's `.claude/settings.local.json` (merging,
   other keys kept; the file is git-ignored), set to `~/.local/share/claude-memory/projects/<rel>`.
   It finds the repos from `ghq list -p`, the chezmoi source and `~`, and moves any memories
   still in `~/.claude/projects/<project>/memory` into the clone first. Not symlinks: Claude Code
   refuses to write into a folder that is a symbolic link ("Refusing to write into symlinked
   directory", [code.claude.com/docs/en/errors](https://code.claude.com/docs/en/errors)).
3. **When**:
   - `SessionStart` (matcher `startup|resume`) runs `claude-memory pull`: 5 s timeout, offline
     is fine. Check during the build whether `MEMORY.md` is loaded before or after the hook; if
     before, a pulled change shows up from the next session.
   - `SessionEnd` starts `nohup claude-memory push >/dev/null 2>&1 &` and returns at once:
     SessionEnd hooks share a 1.5 s budget
     ([code.claude.com/docs/en/hooks](https://code.claude.com/docs/en/hooks)), too short for a
     push.
   - A launchd/systemd timer every 30 minutes covers long sessions, crashed ones and machines
     left on.
   - `push` is: commit local changes (`<host>: <n> memories`), `git pull --no-rebase`, push.
     Committing first means a crash never leaves changes that block the next pull. A lock
     (`mkdir ~/.local/state/claude-memory.lock`; macOS has no `flock`) keeps two sessions and the
     timer from running git at once; a stale lock older than 10 minutes is removed.
   - The hooks and timer are in the dotfiles (`dot_claude/modify_settings.json`, a launchd agent,
     a systemd user timer) and do nothing until the clone exists.
4. **Conflicts**: merges, not rebases, so "ours" is always this machine.
   - `MEMORY.md` gets a small merge driver: keep every list line (`- [`) from both sides, once
     each, in the order they appear; headings and other text come from this machine. A line one
     side deleted while the other edited it comes back; that's the safe side to err on.
   - A memory file changed on both machines keeps this machine's version and saves the other as
     `<name>.conflict-<host>.md` (another merge driver, set in `.gitattributes`).
   - The `SessionStart` hook prints the conflict files, so the session sees them and asks to
     merge; the end-of-apply summary lists them too. Nothing is dropped silently.
5. **Setup**: `claude-memory init` (clone, write the settings, first sync) as a `mac-setup` step
   and in echo-turbine's bootstrap. The first sync on each machine merges the two sets: different
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
- **Symlinking each memory folder into the clone**: Claude Code refuses to write into a
  symlinked folder (see step 2).
- **`autoMemoryDirectory` at user scope**: one folder for every project's memories.
- **A `claude` wrapper passing `--settings`**: the desktop app's Code tab doesn't go through it.
- **Copying in hooks**: two copies to keep in step, and a memory written mid-session isn't in the
  repo until the copy runs.
