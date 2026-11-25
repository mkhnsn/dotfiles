# What review caught on the first app

Every PR gets a `reviewer` subagent pass over its diff. These are the kinds
of thing it found. Check your own change against them before
asking for review.

## Tests

- **A test that doesn't produce the case it names.** One was named for a
  delete being refused, but its sequence never sent a delete that was
  refused, and it would have passed without the change. For each new test,
  check it fails when the change is taken out.
- **A fake that can't do what the real server does.** The fake compared a
  version as text and couldn't answer a conflict with an unchanged row.
  Keep the fake in step with the server.
- **Non-view logic in the app target with no tests.** Move it to the
  package.
- Races need a test that suspends a request and acts while it is out.

## Outcomes the app can't see

- A timeout or lost answer is not "it didn't happen". Design for "it may
  have".
- A 401 means different things depending on what was just attempted.
- State that matters across launches (a half-finished deletion) kept only
  in a view.
- An erase or write whose result is dropped, followed by a message saying
  it worked.

## Behavior changes hidden in a fix

A change to make deletes conditional also changed what happens when a
person deletes an item that is in conflict: it used to be deleted, and now
it came back. Nobody had decided that. When a fix changes what a person sees in a
case nearby, say so in the PR and ask.

## More than one process or window

- A second window keeps its own model and may keep syncing after the
  first has stopped.
- The app and an extension renew tokens independently.
- A request started under one login finishing under the next.

## Layout and accessibility

- A confirmation in a stack with a spacer and no scroll view truncates at
  large text sizes, and the last line ("This can't be undone.") goes first.
- A button read by VoiceOver as "Try again" when it deletes a login.
- A Mac sheet with no frame.
- Initial focus with Full Keyboard Access: check by hand.

## Copy

- A confirmation that doesn't name the account.
- Wording that drifts from the web's for the same action.
- British spelling in a US English product.

## Docs

- README sentences true only in the happy case ("If nothing was deleted,
  the app says so"). Say which case.
- A rule in CLAUDE.md the code doesn't yet guarantee.

## Process

- Commits added after a review need their own review before merging.
- Squash-merging the bottom of a stack leaves the PR above it in conflict.
  Rebase it onto `main` before asking for the merge.
- "Merge all" covers the PRs as they were when it was said.
