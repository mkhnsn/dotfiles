# Internal TestFlight

The goal is the app on Mike's phone. Internal testers only: no beta
review, no screenshots, no store description. The App Store submission is
separate and later.

**Status of this file:** the Apple account steps below were done once,
in November 2026. The upload workflow had not been built when this was
written. Look in the first app's repo (SKILL.md, "Where to look") for a
merged workflow before writing one, and correct this file once one works.

## What Mike does by hand

Give him exact values and wait. Don't do these for him, and don't ask for
any value back.

1. **App ID.** developer.apple.com > Certificates, Identifiers & Profiles >
   Identifiers > +. Explicit bundle ID, description is the app's name.
   Enable only the capabilities the entitlements file declares. With
   an App Group and Auth0 login that is App Groups alone: login goes
   through Auth0 in a web sheet and needs neither Sign in with Apple nor
   Associated Domains.
   Continue stays disabled until the description has text.
2. **App Group.** Identifiers, filter set to App Groups, add
   `group.<bundle id>`. Then back to the App ID > Configure next to App
   Groups > select the group > save. Without the assignment the capability
   points at no group and signing fails with a provisioning profile error.
3. **Each extension** needs its own App ID with the same group assigned.
4. **App record.** App Store Connect > My Apps > + > New App: iOS, English
   (U.S.), the bundle ID from the dropdown, a private SKU, Full Access.
   The name must be unique across the App Store, 30 characters at most. It
   is the store name only; the name under the icon is unchanged, and it
   can change with a later version. Short names are often taken; have
   "<Name> by Unstable Studios" ready.
5. **API key.** Users and Access > Integrations > App Store Connect API >
   Team Keys > Generate. The private key downloads once.
   https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api
   Tell him which role the key needs before he makes it.
6. **Repo secrets.** He sets the key ID, the issuer ID and the key file as
   GitHub Actions secrets on the app's repo. Name them for him.

A first build for a device from an Xcode signed in to the team can
register the bundle ID and group by itself. Don't run one yourself: that
acts in his Apple account. Doing it by hand first avoids finding out in CI.

## What you build

- A workflow that, on a version tag, archives the iOS app, signs it and
  uploads it to App Store Connect.
- A build number that is unique per upload.
- Whatever the Info.plist needs for a build to finish processing without
  a question, such as the export compliance key. Check Apple's docs.
- README and CLAUDE.md: how to cut a build, the secret names, and what
  was set up by hand.

Fetch Apple's current docs, and cite them in the PR, for:

- `xcodebuild`'s authentication-key flags
- automatic or cloud-managed signing in CI
- the role the API key needs for that
- how a build is uploaded today

None of these had been confirmed when this was written.

## Limits

- Never read, print or ask for the key or a secret's value. Names only.
- Don't push a tag or upload a build without Mike's go-ahead.
- If a one-off upload from Xcode on his Mac would reach his phone sooner
  than CI, say so.

## Later, for the App Store

- Screenshots, description, privacy policy URL, the App Privacy answers.
- In-app account deletion must already work.
- Payment rules, if the project bills (`design.md`).
- External testers need beta review.
