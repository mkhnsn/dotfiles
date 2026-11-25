# Offline store and sync

The app works with no connection. What a person does is stored on the
device first and uploaded after, so nothing waits for the network and no
view shows a spinner for a save.

The first app's README and CLAUDE.md (SKILL.md, "Where to look") say
exactly how that app behaves. This is the general shape.

## Layers

```
Views -> the screen's model -> the store (SQLite) <- the syncer -> API client
```

- Views call the model. The model reads and writes the store and runs the
  syncer. Only the syncer calls the API, and only one type makes requests.
- The store is one SQLite file per account, on iOS in the App Group so
  extensions reach it, named from a hash of the account's id, left out of backups.
- A change to the table is a new `user_version` step, never an edit to an
  old one.

## What the API must offer

See `design.md`. In short: client-chosen ids, a changes feed with a
per-user cursor and tombstones, conditional edits and deletes that answer
409 with the current row, and stable error codes.

## Behavior to design for

- **Offline capture.** Save stores and returns at once. Upload happens when
  the app comes to the front, when a connection appears, and after each
  change. Until then the row says it hasn't uploaded.
- **No duplicates.** The id is made on the device. A request whose answer
  was lost is sent again under the same id.
- **Changes from elsewhere.** After uploading, read the feed from the last
  cursor. If the server can't continue from there, read everything again,
  keeping what is on screen and what hasn't uploaded.
- **A refused upload** says why on the row, in the server's words, and
  waits for an edit or "Try again". A failure with no reason is skipped
  until next time and doesn't hold up the rest.
- **A conflict.** If something edited here changed elsewhere, upload
  nothing. Say so on the row, show both versions, and ask which to keep.
  That includes a change arriving while the edit sheet is open.
- **Edits and deletes act on what the person was shown.** If the row is no
  longer that, do nothing and say so.
- **Deletes** go up after the feed is read and name the version deleted
  here. If it changed elsewhere, it comes back instead of vanishing
  unseen. Deleting a row that is in conflict deletes it: the person saw
  the change. (Mike's decision.)
- **Deleted elsewhere** stays deleted. Text here that never uploaded comes
  back as a new item.
- **A store write can fail** (a full disk). Say so and keep the text in
  the field.
- **Text typed but not saved** survives a session that ends, per account.
- **Search and derived fields** (tags) are worked out on the device by the
  server's rules. If the server's rules change, change these.

## Rules

- Text a person typed is never dropped: not by a failed upload, a
  conflict, a delete elsewhere, or a session that ends. Any change to the
  store or the syncer needs a test that says what happens to the text.
- Keep two cases apart in the store: the server's answer to an upload from
  here, and what the server has for any other reason. Never decide which
  applies by comparing texts. Remember what was sent, so the device's own
  lost answers aren't mistaken for someone else's change.
- When it can't be told whose text the server has, keep both and ask.
- Each row says where it stands with the server. A new state gets a line
  on the row and a way out for the person.
- The fake server in the tests follows the real one. When the real one
  changes, change the fake. Give it a way to run code while a request is
  out, to test races.
- A second window, or an extension, is another process using the same
  store and session. Decide what each may do.

## Limits to state in the README

For example: an item written offline takes its upload time as its date;
search on the device and on the web can differ on part of a word.
