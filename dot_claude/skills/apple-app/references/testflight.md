# Internal TestFlight

The goal is the app on Mike's phone. Internal testers only: no beta
review, no screenshots, no store description. The App Store submission is
separate and later.

**Status of this file:** a record. `rabbithole-apple` uploaded 0.1.0 and
0.1.1 in November 2026 with the archive and export commands below, from a
workflow a tag started. Both installed from TestFlight, the second as an
automatic update. It then moved to release-please and the org's shared
workflows, described here, and 0.2.0 went out that way on the first try:
a `feat` merged, release-please opened the release PR, and merging it
tagged the version and uploaded the build. Whether that build installed
was not confirmed when this was written. Copy its
`.github/workflows/release.yml`, `release-please-config.json`,
`.release-please-manifest.json` and `Config/TestFlight-ExportOptions.plist`,
and read its README's "TestFlight" section first.

## How a release goes out

Like every other Unstable Studios repo: release-please, through the org's
shared workflows in `unstable-studios/.github`. Don't write a
tag-triggered workflow or an upload script in the app repo.

- `release.yml` runs on each push to `main`. Its first job calls the
  shared `release-please.yml` with the org secret `GH_PAT_RELEASEPLEASE`,
  which opens or updates a release PR. Use that token, not
  `GITHUB_TOKEN`: CI then runs on the release PR, and the repository
  needs no "Allow GitHub Actions to create pull requests" setting.
- Merging the release PR tags `vX.Y.Z` and cuts a GitHub Release. A
  second job, chained off `release_created`, calls the shared
  `publish-testflight.yml` with the project, the scheme, the version and
  the tag as `ref`, so the build is the tagged commit even if `main` has
  moved on.
- `workflow_dispatch` uploads what is on `main` under the last released
  version, as a new build.
- release-please config: `release-type` `simple`,
  `include-component-in-tag` false, `bump-minor-pre-major` true, and an
  extra file with the generic updater on the xcconfig line
  `MARKETING_VERSION = 0.1.1 // x-release-please-version`. Start the
  manifest at the last tag's version. An existing `vX.Y.Z` tag is enough
  for it to pick up from.
- A `feat`, `fix`, `perf` or `revert` commit makes a release. `ci`,
  `docs`, `test` and `chore` alone open no release PR. Below 1.0 a `feat`
  bumps the minor version (0.1.1 to 0.2.0) and a `fix` the patch.

## What the shared upload does

- `xcodebuild archive` with automatic signing, then
  `xcodebuild -exportArchive` with the repo's options plist: `method`
  `app-store-connect`, `destination` `upload`, `signingStyle` `automatic`,
  `manageAppVersionAndBuildNumber` false, `testFlightInternalTestingOnly`
  true. `xcodebuild -help` lists every key for the installed Xcode. Check
  it there, not from memory.
- Signing is cloud signing: no certificate or profile in CI. Both commands
  take `-allowProvisioningUpdates` and the three `-authenticationKey…`
  flags with an App Store Connect **team** key whose role is **Admin**.
- The build number is the upload time in UTC to the minute
  (`202611251630`), so it only goes up. Don't use the run number: it
  restarts when a workflow file is renamed or replaced, and App Store
  Connect refuses a build number it has seen for that version. Version
  and build are set on the command line so the app and every extension
  match, which App Store Connect requires.
- The app's Info.plist sets `ITSAppUsesNonExemptEncryption` to `NO` when it
  only uses HTTPS and the system's cryptography. Without it every build
  waits on a question.
- The job runs in a GitHub environment named `testflight`, limited to the
  branch `main`. The upload runs for the push to `main`, not for the tag,
  so a tag rule refuses it. The environment is what limits who can use
  the key. Required reviewers aren't available for a private repo on the
  Team plan.
- An extension with no capabilities needs no visit to the developer site
  when the key is Admin: the first upload with the widget extension
  succeeded with its App ID never registered by hand. One with a
  capability, such as an App Group, is still step 3 below.
- The shared workflow defaults to the runner label `xcode-27` and
  `/Applications/Xcode_27.2.app`. Pass `runs-on` and `xcode-path` when an
  app needs another Xcode.

## Where the key lives

In Doppler, synced to GitHub, like every other Unstable Studios repo.
**Never read Doppler at run time with a token.** Mike turned that down.

- A config of its own in the web project's Doppler project (Rabbithole:
  project `rabbithole`, config `tf`), holding only these three. Never in
  `base`: that config syncs to the web repo and is copied to the Worker.
- `ASC_KEY_ID` and `ASC_ISSUER_ID` unmasked, `ASC_KEY_P8` masked.
- A GitHub sync on that config, targeting the app repo's `testflight`
  **environment**, with "Sync unmasked secrets as variables" on.
- So the workflow reads `vars.ASC_KEY_ID`, `vars.ASC_ISSUER_ID` and
  `secrets.ASC_KEY_P8`. The two IDs show in the log. They are no use
  without the file.
- Doppler will list the other config's secrets as "missing" in each. Tell
  him to dismiss them, both ways.

Afterward, check the names landed. Names only: a plain
`gh variable list` prints values.

```bash
gh secret list --env testflight --json name -q '.[].name'
gh variable list --env testflight --json name -q '.[].name'
```

Check too that nothing with an `ASC_` name is at repository level or in
the web repo.

## What Mike does by hand

Give him exact values, in this order, and wait. Don't do these for him,
and don't ask for any value back. He may send screenshots: tell him to
crop out terminals and anything with a key in it.

1. **App ID.** developer.apple.com > Certificates, Identifiers & Profiles >
   Identifiers > +. Explicit bundle ID, description is the app's name
   (Continue stays disabled until it has text). Enable only the
   capabilities the entitlements file declares (Rabbithole: App Groups
   alone).
2. **App Group.** Identifiers, filter App Groups, add `group.<bundle id>`.
   Then the App ID > Configure next to App Groups > select the group.
3. **Each extension that has a capability** gets its own App ID
   (`<bundle id>.share`) with the same group assigned.
4. **A device** registered to the team. The archive is signed for
   development first, which needs one.
5. **App record.** App Store Connect > Apps > + > New App: iOS, English
   (U.S.), the bundle ID from the dropdown, a private SKU, Full Access.
   The name must be unique on the App Store, 30 characters at most
   ("Rabbithole by Unstable Studios"). The name under the icon is
   unchanged.
6. **Team API key.** Users and Access > Integrations > App Store Connect
   API > Team Keys > Generate. Role **Admin**: cloud signing for
   distribution needs it
   (https://developer.apple.com/videos/play/wwdc2021/10204/). Only an
   Admin key was tried. The `.p8` downloads once.
7. **GitHub environment** `testflight`, with a deployment rule for the
   branch `main`. Before the sync, so the sync has a target.
8. **Doppler** config, three values and the sync, as above.
9. **Internal testing group** in the app record's TestFlight tab, with
   himself in it and automatic distribution on. Then the TestFlight app on
   the phone, signed in with the same Apple ID.

## Limits

- Never read, print or ask for the key or any secret's value. Names only.
- Merging a release PR uploads a build. It needs Mike's go-ahead each
  time, like any merge. So does running the workflow by hand.
- Never push a tag or edit `CHANGELOG.md`, the manifest or the
  `x-release-please-version` line by hand.
- Look for an org shared workflow before writing one, and for the org's
  secrets (`gh api orgs/unstable-studios/actions/secrets`, names only).
  The first version of this used `GITHUB_TOKEN` because one repo did.
- Confirm a PR reports merged before deleting its branch. Deleting the
  branch of a PR whose merge failed closes it.
- Wait for CI on the head you are merging. A rebased head has no checks
  for the first seconds, and `gh pr checks --watch` returns at once.
- You can't see App Store Connect. After "Upload succeeded", say that
  processing and delivery to the phone are his to watch, and what each
  state on the TestFlight tab means.

## Later, for the App Store

- Remove `testFlightInternalTestingOnly`.
- Screenshots, description, privacy policy URL, the App Privacy answers.
- A privacy manifest, if first-party code uses a required-reason API.
- In-app account deletion must already work.
- Payment rules, if the project bills (`design.md`).
- External testers need beta review.
