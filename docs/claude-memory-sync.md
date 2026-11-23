# Claude Code memories in sync across machines (#117)

Status: built. `claude-memory` (`~/.local/bin`) syncs memories through the private repo
`mkhnsn/claude-memory`, cloned to `~/.local/share/claude-memory` on this Mac and echo-turbine.
Timing: SessionStart, SessionEnd and a 30-minute timer.

`claude-sync` moves memories and prompt history once, from an old Mac to a new one. Day to day,
a memory saved on this Mac (136 memory files) was missing on echo-turbine (15), and the other way
round.

## Using it

```
claude-memory init     clone the repo, move this machine's memories in, push (mac-setup step)
claude-memory sync     move new memories in, point checkouts at the repo, commit, pull, push
claude-memory status   what's synced, what isn't, and memories waiting to be merged
```

A memory changed on two machines keeps this machine's copy and saves the other as
`<name>.conflict-<host>.md`, on this machine only (the repo ignores them, so the same conflict
isn't merged on both). The next session start lists those files, so the session asks to merge
them. `~/.local/state/claude-memory.log` has the background syncs' output.

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
   `~/.local/share/claude-memory`. Layout: `projects/<rel>/`, where `<rel>` is Claude Code's
   project folder name with this machine's home prefix (`-Users-mkhnsn-`, `-home-mkhnsn-`)
   removed: `src-github-com-unstable-studios-mister-handy`, and `-local-share-chezmoi` for the
   chezmoi source. The encoding can't be reversed, so only the prefix is rewritten. The repo
   carries every synced project, cloned on this machine or not. Not synced: projects without a
   checkout that reads the repo (below), projects outside the home folder (`/private/tmp`,
   scratch dirs), and `~` itself, whose project settings file would be
   `~/.claude/settings.local.json`, the user settings folder. Their memories stay in
   `~/.claude/projects`, and `claude-memory status` lists them.
2. **Point Claude Code at the clone**: `autoMemoryDirectory`, which Claude Code reads from any
   settings scope, project and local included, under the same workspace trust rule as hooks
   ([code.claude.com/docs/en/memory](https://code.claude.com/docs/en/memory)). `claude-memory
   sync` writes it into `.claude/settings.local.json` of `~/src`, every git repo up to three
   levels under it (flat `~/src/<repo>` and ghq's `~/src/github.com/<owner>/<repo>`) and the
   chezmoi source, set to `~/.local/share/claude-memory/projects/<rel>`. Other keys in the file
   are kept, a different `autoMemoryDirectory` someone set is left alone, a file that's committed
   to the repo or a symlinked `.claude` is skipped, and the file is added to the repo's
   `.git/info/exclude` if it isn't ignored already. If Claude Code wrote the file while the
   sync was writing it (a permission rule), the sync leaves it for next time. Only the checkouts
   that read the repo have their memories moved in from the default
   `~/.claude/projects/<project>/memory`, on each sync; a session anywhere else keeps its
   memories where Claude Code looks for them. The setting is only honored in a folder you've
   trusted, the same as hooks. Not symlinks: Claude
   Code refuses to write into a folder that is a symbolic link ("Refusing to write into
   symlinked directory", [code.claude.com/docs/en/errors](https://code.claude.com/docs/en/errors)).
   - A session in a git worktree of a checkout uses the main checkout's `settings.local.json`
     ([code.claude.com/docs/en/settings](https://code.claude.com/docs/en/settings)), so it reads
     the repo too.
3. **When**:
   - `SessionStart` (matcher `startup|resume`, 6 s timeout) runs `claude-memory hook-start`:
     commit local changes, fetch (3 s limit; offline is fine), merge, and print the files
     waiting to be merged.
   - `SessionEnd` runs `claude-memory hook-end`, which starts `sync` in the background and returns
     at once: SessionEnd hooks share a 1.5 s budget
     ([code.claude.com/docs/en/hooks](https://code.claude.com/docs/en/hooks)).
   - Every 30 minutes, for long sessions, crashed ones and machines left on: a launchd agent
     (`com.unstablestudios.claude-memory`, loaded by `run_onchange_after_claude-memory-timer.sh`)
     on macOS, and a cron job on echo-turbine, set up by echo-core's
     `ansible/playbooks/echo-turbine-claude-memory.yml`. Cron there, not a systemd user timer:
     crond runs whether or not you're logged in, where a user timer needs lingering. launchd
     on the Mac, not cron: cron skips runs missed while the Mac sleeps, launchd runs them on
     wake.
   - `sync` is: commit local changes (`<host>: <n> memories`), fetch, merge, point checkouts at
     the repo, move their new memories in, commit, push. Committing first means a crash never leaves
     changes that block the next merge. An `flock` on `~/.local/state/claude-memory.lock` keeps
     two sessions and the timer from running git at once; the kernel releases it when the
     process ends, however it ends (a hook timeout included). While holding it, git's own lock
     files older than a minute are removed, since only a killed git leaves them.
   - Hooks, agent and timer are in the dotfiles and do nothing until the clone exists.
4. **Conflicts**: merges, not rebases, so "ours" is always this machine. Two merge drivers
   (`.gitattributes` in the repo, set up in `.git/config` by `claude-memory` on every run):
   - `MEMORY.md`: three-way on index lines (`- [`, `* [`, `1. [`): this machine's text, minus
     entries the other machine removed, plus entries it added. An entry both machines changed is
     kept twice. If the other side also added headings or prose, its whole file is saved as
     `MEMORY.conflict-<host>.md` too.
   - Other memory files changed on both machines keep this machine's version and save the other
     as `<name>.conflict-<host>.md`, `<host>` from the other machine's newest commit message.
   - Anything the drivers don't settle (a driver that fails, one side deleting what the other
     changed, the repo's own files): this machine's version is kept, or whichever exists, and
     the other machine's memory is saved as a conflict copy.
   - Two machines that each made the first commit in the empty repo merge as unrelated
     histories.
5. **Access**: on a Mac the clone uses HTTPS with `gh auth git-credential`, so a background sync
   never waits on a 1Password SSH approval. echo-turbine uses a deploy key for this repo only
   (`~/.ssh/claude-memory`, read-write), set as the clone's `core.sshCommand`. Commits in the
   clone aren't signed (`commit.gpgsign=false` there), for the same reason.
6. **Setup**: `claude-memory init` is a `mac-setup` step (Accounts, after `gh`); on echo-turbine
   the echo-core playbook runs it, after making the deploy key if it's missing. The first sync on each machine merges the two sets: different files
   add up, same-named files that differ become `.conflict-<host>.md`.

## What happens to `claude-sync`

It stays for the new-Mac move: prompt history (`history.jsonl`), session transcripts with
`--transcripts`, and memories of projects that aren't synced (outside the home folder, or `~`).
Synced memories come from the repo once `claude-memory init` runs.

Prompt history isn't synced continuously: it's per machine (paths and hosts differ), append-only
and large, and up-arrow history from another machine is rarely wanted.

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
