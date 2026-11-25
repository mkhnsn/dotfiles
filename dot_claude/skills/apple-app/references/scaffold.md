# Scaffold

## Repo

`unstable-studios/<name>-apple`, created with Mike's go-ahead. The web repo
keeps the server, the Auth0 and Cloudflare infrastructure, and the issues.

```
<Name>.xcodeproj/   # One app target for iOS and macOS. Hand-maintained.
<Name>/             # App target: SwiftUI views and the entry point
<Name>Kit/          # Swift package: everything that isn't a view
Config/             # Shared.xcconfig, Local.example.xcconfig,
                    # <Name>-Info.plist, <Name>.entitlements
Design/AppIcon/     # Icon sources and their license. Not built.
scripts/test        # What CI runs
.github/workflows/ci.yml
README.md  CLAUDE.md  .gitignore
```

- The app folder is a synchronized folder: a file added on disk is in the
  target. Don't add file references to `project.pbxproj`.
- A new target (share extension, widget) gets its own top-level folder and
  its own `Config/<Target>-Info.plist`, and takes its identifiers from
  `Shared.xcconfig`.
- `.gitignore`: `xcuserdata/`, `*.xcuserstate`, `DerivedData/`, `build/`,
  `*.xcresult`, `.build/`, `.swiftpm/`, `Config/Local.xcconfig`,
  `.claude/settings.local.json`.

## The package

`<Name>Kit` holds configuration, the session, the API client, the local
store and sync. The app and every extension link it.

- `platforms` matches the minimum OS versions. `swift-tools-version` is
  the Swift of the oldest supported Xcode.
- Swift 6 language mode.
- Tests use Swift Testing, with fakes for the server and for Auth0.
- Only one source file imports Auth0, plus its own test.

A layout that worked: `Session/`, a folder for the API client and the
screen's model, and `Store/` (SQLite, the stored row, the syncer).

## Configuration

Build settings in `Config/Shared.xcconfig` become Info.plist keys through
`Config/<Name>-Info.plist`, and an `AppConfiguration` type in the package
reads them at launch.

| Setting | What it is |
| --- | --- |
| `APP_BUNDLE_IDENTIFIER` | `com.unstablestudios.<name>` |
| `APP_GROUP_IDENTIFIER` | `group.$(APP_BUNDLE_IDENTIFIER)` |
| `DEVELOPMENT_TEAM` | The Unstable Studios team ID |
| `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION` | Version and build |
| `IPHONEOS_DEPLOYMENT_TARGET`, `MACOSX_DEPLOYMENT_TARGET` | Minimums |
| `API_BASE_URL` | The project's API root |
| `AUTH0_DOMAIN` | The tenant's login domain, no scheme |
| `AUTH0_CLIENT_ID` | The native application's client ID |
| `AUTH0_AUDIENCE` | The API identifier |

- `//` starts a comment in an xcconfig, so write URLs as
  `https:/$()/host/path`.
- `Shared.xcconfig` ends with `#include? "Local.xcconfig"`. That file is
  gitignored; `Local.example.xcconfig` shows how to override.
- None of this is secret. A native app is a public Auth0 client.
- A build with an empty Auth0 domain and client ID runs with no login
  configured. Setting only one of the two stops the app at launch.
- A new setting is added in four places: the xcconfig, the Info.plist
  template, `AppConfiguration`, and the README table.

Take the team ID from an existing Unstable Studios app's `Shared.xcconfig`.

## Sample data

A `-sampleData` launch argument, debug builds only: made-up data and a
pretend server in memory, no login. Give it inputs that force each failure,
for example: text containing one marker is refused, another can't be
uploaded, editing a marked item meets a change from elsewhere, and
account deletion fails halfway the first time.

Every screen that shows data must work there. It is how UI changes are
checked, and how destructive flows are tried safely.

## scripts/test

One script, run by CI and by hand:

1. Pick an iPhone simulator by runtime, not by device name: names change
   with each Xcode. An optional argument picks the iOS major version.
2. `xcodebuild test` on the package's scheme.
3. `xcodebuild build` of the app for that simulator.
4. `xcodebuild build` for `platform=macOS` with `CODE_SIGNING_ALLOWED=NO`.

`DEVELOPER_DIR` chooses the Xcode. The package compiles with
`swift build` on the Command Line Tools alone; its tests need full Xcode.

## CI

`.github/workflows/ci.yml` on pull requests and `main`: a matrix with one
job per supported iOS, each setting `DEVELOPER_DIR` to an installed Xcode
and running `scripts/test <ios major>`. `permissions: contents: read`,
a concurrency group that cancels superseded PR runs, a timeout.

Runner labels and installed Xcode paths change. Read them from
https://github.com/actions/runner-images#available-images when you write
the matrix; don't copy another repo's.

## Icon and licenses

- The icon is an Icon Composer file in the app target, with its sources
  and the artwork's license in `Design/AppIcon/`. Use open-source artwork
  and keep its license.
- Anything the app ships that someone else made gets its license in
  `<Name>/Licenses/License-<name>.txt`, copied from its source. An
  Acknowledgments screen lists whatever is in that folder. Have
  `scripts/test` check the files reach the built app: an empty list shows
  no error.
- US spelling: "Acknowledgments".

## Docs

README: status, layout, requirements, run, test, configuration table, and a
section per feature saying what it does for the person. CLAUDE.md: layout,
the rules, commands, and what needs Mike's go-ahead.
