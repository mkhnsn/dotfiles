# Internal TestFlight

The goal is the app on Mike's phone. Internal testers only: no beta
review, no screenshots, no store description. The App Store submission is
separate and later.

**Status of this file:** a record. `rabbithole-apple` uploaded 0.1.0 (101)
this way in November 2026, on the first tag, and it installed from
TestFlight. Copy its `scripts/testflight`,
`.github/workflows/testflight.yml` and `Config/TestFlight-ExportOptions.plist`,
and read its README's "TestFlight" section first.

## How it works

- A tag `vX.Y.Z` runs the workflow, which runs
  `scripts/testflight X.Y.Z <build>`.
- `xcodebuild archive` with automatic signing, then
  `xcodebuild -exportArchive` with an options plist: `method`
  `app-store-connect`, `destination` `upload`, `signingStyle` `automatic`,
  `manageAppVersionAndBuildNumber` false, `testFlightInternalTestingOnly`
  true. `xcodebuild -help` lists every key for the installed Xcode. Check
  it there, not from memory.
- Signing is cloud signing: no certificate or profile in CI. Both commands
  take `-allowProvisioningUpdates` and the three `-authenticationKey…`
  flags with an App Store Connect **team** key whose role is **Admin**.
- The version comes from the tag. The build number is
  `run number × 100 + run attempt`, so a re-run never reuses one. Both are
  set on the command line so the app and every extension match, which
  App Store Connect requires. Renaming the workflow file restarts the run
  number at 1, which is refused for a version already uploaded.
- The app's Info.plist sets `ITSAppUsesNonExemptEncryption` to `NO` when it
  only uses HTTPS and the system's cryptography. Without it every build
  waits on a question.
- The job runs in a GitHub environment named `testflight`, limited to `v*`
  tags. A tag runs the workflow as it is at the tagged commit, so the
  environment is what limits who can use the key. Required reviewers
  aren't available for a private repo on the Team plan.

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
3. **Each extension** gets its own App ID (`<bundle id>.share`) with the
   same group assigned.
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
7. **GitHub environment** `testflight`, with a tag rule `v*`. Before the
   sync, so the sync has a target.
8. **Doppler** config, three values and the sync, as above.
9. **Internal testing group** in the app record's TestFlight tab, with
   himself in it and automatic distribution on. Then the TestFlight app on
   the phone, signed in with the same Apple ID.

## Limits

- Never read, print or ask for the key or any secret's value. Names only.
- Pushing a tag needs Mike's go-ahead each time. So do merging and
  running `scripts/testflight` with a key.
- Merge the workflow before tagging: the tag runs what is at that commit.
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
