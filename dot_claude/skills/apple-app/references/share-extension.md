# Share extension

What `rabbithole-apple` built (November 2026) and what review caught.
Mike tried it on his phone from Chrome, and it was tried from Safari in
the simulator. Read that repo's README "Share sheet" section and its
`RabbitholeShare/` folder before copying.

## Shape

- Its own target and top-level folder, iOS only, embedded in the app with
  `platformFilter = ios` on the dependency and the embed build file, so
  the Mac build has none. Its own Info.plist template with the same
  configuration keys as the app's, and the app's entitlements file.
- Bundle ID `<app bundle id>.share`, from the shared xcconfig.
- `APPLICATION_EXTENSION_API_ONLY = YES`.
- `NSExtensionActivationRule` as a dictionary: text, and one web URL.
  Never `TRUEPREDICATE`: Apple rejects it.
- No form. It saves at once, says "Saved to <App>" and closes. In the
  iOS 27 simulator the extension's view came up as a full sheet with an
  opaque background, though the view's own background was clear.

## What it may do

- Write one item into the account's store in the App Group, marked with
  where it came from, then try to upload that one item. Never the full
  sync: the app may be syncing the same file.
- Close when the upload is done (but not before the confirmation has
  been up about a second) or after 5 seconds, whichever is first, and
  only once. Whatever is unfinished, the app's next sync must
  be able to finish.
- Read the session. **Never renew the token.** Refresh tokens rotate, and
  an extension stopped mid-renewal uses one up without storing the next,
  which logs the app out. Upload only with a stored token that has a
  minute left, and otherwise leave the item for the app. With Auth0.swift
  that is two steps, and both are needed: check
  `hasValid(minTTL: 60)` first, then read with `credentials(minTTL: 0)`.
  The read alone renews an expired token, and with its default margin it
  renews one that is about to expire.
- Never log in, log out, erase local data or act on a refused token.
- With nobody logged in, say so and save nothing.

## What review caught

- A time limit that awaited a call that can't be cancelled.
- A text file is a file URL and text at once. Reading the URL first
  saved nothing.
- Checking whether the text already has the link by substring dropped a
  link that begins a longer one. By whole words repeated a link next to
  punctuation. Check what comes before and after the match.
- The same text handed over twice, spaced differently.
- The store opened on the main thread, behind the other process's lock.
- The board only showed the new item after a sync round trip. Read the
  store when the app comes to the front.

## Server

A new source value needs adding to the server's list. Check what the
server does with a source it doesn't know before the app sends one.
Rabbithole's stores it as `web`, so the app could ship first. A server
that refuses it must be released first. Keep the app's own model from
decoding the source into a closed enum.

## Check on a device

Selected text, a page from each browser, a text file, logged out, and no
connection. The simulator can share from Safari if someone is logged in.
