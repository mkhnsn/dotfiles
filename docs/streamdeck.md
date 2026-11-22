# Stream Deck from the dotfiles (#122)

Status: the library builder is in (`streamdeck-library`); `streamdeck-apply` is designed here and
waits on the decisions at the end.

Goal: a fresh Mac gets its Stream Deck profiles from `chezmoi apply` plus one command, instead of
restoring an app backup (`Preferences > Profiles > Restore`).

## What there is today

- **The XL** (model `20GAT9902`) has 20 profiles: pack profiles installed by hand (Mac Plain XL
  variants of ADX's Apple, Adobe photo (Lightroom, Lightroom Classic, Photoshop), Microsoft and
  tmux packs, Chrome, Blender, Fusion 360, Shapr3D, Slack, KiCad from its plugin), Terminal (ADX's
  iTerm2 profile linked to Ghostty), and Default.
- **The library**, OneDrive (Unstable Studios) > Apps > Stream Deck library: purchased and
  sideloaded originals (13 packs, 2 plugins, 1 icon pack) and `library.json`, the index with each
  file's SHA-256 and the 678 profile variants inside the packs. It's private, so the files stay
  out of this public repo.
- **Stream Deck 8's MCP server** (Claude Code's `StreamDeck`): profiles, pages, actions, plugins,
  the Marketplace. It can build a profile key by key but can't import or export one.

## The library builder: `streamdeck-library`

`dot_local/bin/executable_streamdeck-library` replaces the builder that lived in
`~/.local/state/streamdeck-library/build_library.py` on echo-macaroni (it wasn't carried over; this
is a rewrite that reproduces its `library.json`).

- `streamdeck-library build` re-indexes the library: SHA-256 and size for every file, and for
  every pack the `.streamDeckProfile` variants inside it with their app, style
  (brand/dark/plain, labelled-dark/light), device (standard, xl, mini, neo, plus, plus-xl, studio,
  galleon) and platform. Hand-written fields (title, requires, installed, note, original name)
  are kept. A new file is added with its id, vendor and version from its name
  (`packs/<vendor>/<id>-<version>.zip`); a file that's gone is dropped. Both are printed.
- `streamdeck-library check` verifies every listed file against its checksum.
- Checked against the real library: rebuilding nine of the packs gives a byte-identical index
  (apart from the date), and its variant parser gives the stored app, style, device and platform
  for all 678 variants. A rebuild keeps the index's order, so its diff shows only real changes.

## `streamdeck-apply` (proposed)

One command, run by `mac-setup` after Stream Deck 8 is installed:

```
streamdeck-apply           install what macos/streamdeck/profiles.toml lists that isn't there
streamdeck-apply --check   exit 0 if every listed profile and plugin is installed
```

`macos/streamdeck/profiles.toml`, in the repo (names only, nothing purchased):

```toml
device = "xl"            # which variant to pick from each pack

[[pack]]                 # from the library, by library.json fields
id = "mac-essentials"
style = "plain"
apps = ["macOS", "Mail", "Safari", "Finder", "Preview", "Photos"]

[[pack]]
id = "iterm2"
style = "plain"
rename = "Terminal"      # then linked to Ghostty

[[plugin]]
file = "plugins/pathfinder/com.pathfinder.kicad-macos-studio-deck-1.0.0.1-mac.streamDeckPlugin"

[[profile]]              # our own, exported from the app into the repo
file = "macos/streamdeck/profiles/Ghostty.streamDeckProfile"
```

How it installs:

- **Packs**: find the variant in `library.json` (pack id, app, style, device, platform mac),
  verify the zip's checksum, extract that one `.streamDeckProfile` to a temp folder, and `open` it:
  Stream Deck imports a profile file it's handed. Profile names on disk don't follow the variant
  data ("Google Chrome - XL Mac", "Blender Pro SD XL V5") and change on rename, so matching by name
  won't work. Instead `streamdeck-apply` notes which `ProfilesV3/<uuid>.sdProfile` folder each
  import created (the new folder after the import) in `~/.local/state/streamdeck-apply.json`; a
  spec entry is installed while its folder exists. Re-runs skip it, renames don't matter, and a
  profile deleted in the app is imported again.
- **Plugins** (`.streamDeckPlugin`): `open` them too; installed when `Plugins/<uuid>.sdPlugin`
  exists. **Icon packs** (`.streamDeckIconPack`): installed when `IconPacks/<id>` exists.
- **Our own profiles**: the design from 2026-11-19 builds them from scratch (global top row, Find /
  Command / Close slots, gold power keys; Ghostty, VS Code, Chrome, Fusion first). They're built
  once, with the StreamDeck MCP server or by hand, then exported from the app
  (right-click > Export) into `macos/streamdeck/profiles/` and opened like pack variants.
- Renames and app links (Terminal → Ghostty) go through the MCP server's `profile_rename` and
  `profile_set_app` after the import, so they're in the spec, not in the imported file.

What it doesn't do: delete profiles that aren't listed (it reports them), or change a profile that
already exists (delete it in the app and re-run to get the spec's version). On a Mac whose
profiles came from the old backup, the state file is empty, so the first run would import
duplicates: `streamdeck-apply --adopt` records the existing profiles for spec entries instead,
matched once by hand.

## Decisions needed

1. **Own profiles as exported files in the public repo.** A `.streamDeckProfile` holds key images
   and actions (URLs, hotkeys, BTT named-trigger names); anything private would have to stay out
   of it, like the BTT preset. The alternative is the library (private), which makes the repo
   depend on OneDrive for our own work too. Recommended: the repo.
2. **Does `open` import silently?** Stream Deck may ask which device to import a profile to, or
   show its profile window. Test once on the Mac with one pack variant; if it prompts, the
   command says so and waits.
3. **Pack variants vs from scratch.** The 2026-11-19 design says packs are reference only. If
   that holds, the `[[pack]]` part matters only for the apps the own profiles don't cover yet
   (Apple apps, Microsoft, Slack, CAD) and shrinks as they're replaced.

## Not chosen

- **Restoring the app's backup** (today's way): a snapshot, not a spec; it carries whatever the
  old Mac had, including leftovers.
- **Writing `ProfilesV3` directly**: undocumented format, and Stream Deck rewrites it while
  running.
- **Building every profile through the MCP server on each Mac**: one call per key and page, and
  the result depends on the plugins installed at that moment; it's for building a profile once.
