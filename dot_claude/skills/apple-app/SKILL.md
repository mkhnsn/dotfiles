---
name: apple-app
description: How to add a native iOS (and Mac) app to an Unstable Studios project, existing or new - design first, a SwiftUI app in its own repo, Auth0 login, offline store and sync, account deletion, internal TestFlight. Use when asked to design, plan, scaffold or build an iOS, iPad or Mac app for a project, to get one onto TestFlight, or when working on an existing Unstable Studios Apple app (session, sync, account deletion, extensions).
---

# Apple app for an Unstable Studios project

The shape that worked for the first Unstable Studios iPhone app, built
November 2026 (see "Where to look"). Use it unless the project gives a
reason not to, and say so when you depart from it.

What that app has proved: scaffold, login, the main screen, offline sync,
icon, licenses, account deletion, a share extension and an internal
TestFlight upload, on iPhone. Built and uploaded but not yet checked on a
phone: a widget and an "Add a note" App Intent. Not yet built there: the
Mac beyond a build that compiles. Those parts of this skill are a plan,
not a record.

The web project is the server. The app is a second client of the same API,
in its own repo, and nothing in it is secret.

## Order of work

1. **Design, for Mike to approve.** No code first. See `references/design.md`.
2. **Plan** as GitHub issues under an "iOS app" milestone in the web
   project's repo, one issue per step.
3. **Server changes** the design needs, in the web repo, released before
   the app depends on them.
4. **Build**, one PR per step, in this order unless the design moves one:
   1. Scaffold the app, config and CI (`references/scaffold.md`)
   2. Log in with Auth0 (`references/auth0.md`)
   3. The main screen: whatever the app is for on a phone
   4. Offline store and sync (`references/offline-sync.md`)
   5. App icon and the acknowledgments screen
   6. Delete my account (`references/account-deletion.md`)
   7. Share extension (`references/share-extension.md`), then widgets and
      App Intents (not yet built in the first app; no reference file)
   8. Internal TestFlight (`references/testflight.md`)
5. **App Store submission** is separate and later: screenshots, privacy
   answers, payment rules, review.

If the app's main way in is the share sheet (a link saver, a clipper), move
the share extension up to step 3 or 4.

## Decisions that are Mike's

Put each to him as a question with a recommendation. Don't assume.

- Which iOS versions. The first app: iOS 26 and 27, macOS 26.
- iPhone only, or iPad and the Mac from the same target.
- What the first version includes.
- Bundle ID and App Group. Default `com.unstablestudios.<name>` and
  `group.com.unstablestudios.<name>`.
- The App Store name when the plain one is taken. "<Name> by Unstable
  Studios" is a fallback that fits (30 characters is the limit).
- Whether deleting an account in the app deletes the shared Auth0 login.
- Payments, if the project has billing. Fetch the current App Store Review
  Guidelines on payments and state what the app may show or link to.
- The app icon.

## Needs his go-ahead each time

- Creating the repo.
- Applying Terraform (the Auth0 native application lives in the web repo).
  A plan only reads, and is the one exception.
- Deploying or releasing the web project, and changing Doppler or DNS.
- Any change on the shared Auth0 tenant.
- Anything in his Apple account. He does those by hand: give exact values.
- Merging a release PR, uploading a build, submitting for review.
- Merging a PR.

## Rules that held throughout

- Views in the app target. Everything else in a Swift package with tests,
  so extensions link it.
- Identity and service settings in xcconfig files, not the project file.
- A change is stored on the device first and uploaded after. Text a person
  typed is never dropped.
- One type owns the session. Nothing else touches Auth0 or the Keychain.
- Every screen that shows data works with `-sampleData`, so it can be
  checked in the simulator with no login and no server.
- `scripts/test` is what CI runs, with every supported Xcode.
- Tests use Swift Testing.
- UI text follows the `ui-copy` skill. When a screen has a web counterpart
  (a confirmation, an error), use the web's wording.
- Fetch Apple's and Auth0's current docs for anything you depend on, and
  cite the URL in the PR. SDKs and Xcode change every year.
- Never test account deletion with a real login, against any server, a
  local one included.
- Never read, print or ask for a signing key or secret. Names only.
- The app repo's CLAUDE.md records the rules as they are learned. Update it
  in the same PR as the code.

## References

Load the one the step needs:

- `references/design.md`: what the design document answers, and what the
  server usually lacks.
- `references/scaffold.md`: repo layout, xcconfig, the Swift package,
  `scripts/test`, CI, sample data, licenses.
- `references/auth0.md`: the native application in Terraform, callback
  URLs, session rules.
- `references/offline-sync.md`: the store, the outbox, conflicts, and what
  the API must offer.
- `references/account-deletion.md`: Apple's requirement, the flow, and the
  failures to handle.
- `references/share-extension.md`: the target, what an extension may and
  may not do with the store and the session.
- `references/testflight.md`: release-please and the shared upload
  workflow, where the key lives, and what Mike sets up by hand, in order.
- `references/review-findings.md`: what code review caught on the first app.
  Read before opening a PR.

## Where to look

The first app is the repo under `~/src/github.com/unstable-studios` whose
name ends in `-apple`; its web project is the repo of the same name without
the suffix. If there is none or more than one, ask Mike.

- The app repo's README and CLAUDE.md are the fullest statement of how it
  works. Read them before copying anything.
- The web repo's `infra/` has the native Auth0 application, and its README
  and CLAUDE.md describe the sync and account-deletion rules the app
  relies on.

