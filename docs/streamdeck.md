# Stream Deck from the dotfiles (#122)

Status: the library builder is in (`streamdeck-library`); `streamdeck-apply` is designed here
(decisions made 2026-11-22) and gets built with the first custom profile.

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

## How Stream Deck profile files work

Checked on this Mac (Stream Deck 8):

- A `.streamDeckProfile` is a zip of one `<uuid>.sdProfile` folder: a `manifest.json` with the
  profile's `Name` and `Device.Model`, and one folder per page with its own `manifest.json` and
  key images. `Device.Model` is the device type (`20GAT9902` is the XL) and `Device.UUID` is
  empty, so **one file is for one device type**, and fits any device of that type. Packs ship one
  file per device type for that reason.
- Stream Deck registers itself as the viewer for `.streamDeckProfile`, `.streamDeckPlugin` and
  `.streamDeckIconPack` files. Opening one (`open <file>` or a double-click) hands it to the app,
  which shows its import dialog; you confirm there. That step can't be scripted, so applying is
  one click per profile.

## `streamdeck-apply` (proposed)

Decided 2026-11-22:

- **Packs are a jumpstart, not installed state.** They're where the custom profiles start:
  layouts, icons, the shortcuts and scripts people have worked out. `streamdeck-apply` doesn't
  install them. `streamdeck-library extract <pack> [--app A] [--device xl]` pulls a variant out
  of the library for you to import and take apart while building your own.
- **Our own profiles live in this repo**, unpacked, so diffs are readable:
  `macos/streamdeck/profiles/<name>.sdProfile/` (the manifests and key images). It's a public
  repo, so the same rule as the BTT preset applies: no hostnames, addresses, tokens or client
  names in actions. A key that touches a host calls a BTT named trigger or a script in
  `~/.local/bin`. A test scans the committed manifests for hostnames, IP addresses, email
  addresses and token-like strings.

Commands:

```
streamdeck-apply              import the repo's profiles this Mac doesn't have, and the plugins they need
streamdeck-apply --check      exit 0 if every profile and plugin is installed
streamdeck-apply export NAME  copy a profile from Stream Deck into the repo, after building or changing it
```

`macos/streamdeck/profiles.toml` lists what to install:

```toml
[[profile]]
name = "Ghostty"                 # macos/streamdeck/profiles/Ghostty.sdProfile
app = "com.mitchellh.ghostty"    # switch to it when this app is in front

[[plugin]]                       # plugins the profiles need, from the library
file = "plugins/pathfinder/com.pathfinder.kicad-macos-studio-deck-1.0.0.1-mac.streamDeckPlugin"
```

How it works:

- **Import**: zip the profile folder into a temp `.streamDeckProfile`, `open` it, and wait (up to
  two minutes) for a new `ProfilesV3/<uuid>.sdProfile` folder to appear: that's the sign you
  confirmed the import. Then the next one. The folder each import created is recorded in
  `~/.local/state/streamdeck-apply.json`; a profile is installed while its folder exists, so
  re-runs skip it and renames in the app don't matter.
- **Device type**: a profile's `Device.Model` says which device it's for; on a Mac without that
  device, it's skipped and listed. A second device type gets its own profile.
- **Export**: finds the profile in `ProfilesV3` by name, copies its folder into the repo, drops
  machine state (the current page), and runs the scan.
- **App links**: set after the import with the StreamDeck MCP server's `profile_set_app` (from
  `app` in the spec), so they don't depend on what the file had.
- **Plugins** (`.streamDeckPlugin`) and **icon packs**: opened the same way; installed when
  `Plugins/<uuid>.sdPlugin` or `IconPacks/<id>` exists.

What it doesn't do: delete profiles that aren't listed (it reports them), or change a profile that
already exists (delete it in the app and re-run to get the repo's version). The pack profiles on
the XL today stay as they are until custom ones replace them.

Next: build the first custom profile (Ghostty), export it, then write `streamdeck-apply` against
it, so the import and export are tested on a real file.

## Not chosen

- **Installing pack profiles as they are**: they're a starting point; the custom profiles
  replace them.
- **Own profiles in the private library**: safer by default, but no history or review; the scan
  and the BTT-trigger rule keep private details out of the repo instead.
- **Restoring the app's backup** (today's way): a snapshot, not a spec; it carries whatever the
  old Mac had, including leftovers.
- **Writing `ProfilesV3` directly**: undocumented format, and Stream Deck rewrites it while
  running.
- **Building every profile through the MCP server on each Mac**: one call per key and page, and
  the result depends on the plugins installed at that moment; it's for building a profile once.
