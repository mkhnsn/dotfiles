# Design

Write the design as Markdown in the web project's repo (`docs/`), on a
branch, as a PR for Mike to read. Then file the issues.

For a new project with no web app yet, design the API and the app together,
and build the server first.

## Read first

- The web repo's README, CLAUDE.md, `docs/` and OpenAPI document.
- Its multi-user rules. They apply to every server change you make.
- Which Auth0 tenant it uses and where its clients are defined (`infra/`).
  The project's template answers say which.
- What already exists for non-browser clients: a shared API client, an
  extension, idempotency keys, a change log, client-chosen ids.
- Whether it has billing.

## What the document answers

1. **What the app is for on a phone.** One sentence. A notes app: open on a
   text field, capture in one tap, sort later. A link saver: save from the
   share sheet. This decides the first screen and the build order.
2. **The first version.** What is in, what waits, and why.
3. **Screens and navigation**, with the copy for each, following `ui-copy`.
   Include the states: empty, loading, offline, refused, conflict, session
   ended.
4. **Offline.** What is kept on the device, what a person can do with no
   connection, and what happens when two devices change the same thing.
5. **Extensions.** Share sheet, widgets, App Intents: which, and what each
   needs from the shared package and the App Group.
6. **What the server needs.** See below.
7. **Account deletion.** Required by Apple for any app with sign-up.
8. **Payments**, if the project bills.
9. **Open questions for Mike**, each with a recommendation.

## What the server usually lacks

The first app needed all of these before or during its build:

- **A native Auth0 application**, and `allow_offline_access` on the API so
  refresh tokens work.
- **Client-chosen ids** on create, so an upload whose answer was lost can
  be sent again without making a duplicate. The id is unique only together
  with the user id.
- **A changes feed** with a per-user revision, so the app reads what
  changed since it last asked. Deletes leave a tombstone. The feed says
  when it can no longer continue from a cursor.
- **Conditional edits and deletes.** The request names the version it was
  made against. A stale one answers 409 with the current
  row, so the app can show both.
- **One error shape** with stable codes the app can act on.
- **An OpenAPI document** the app's client is written against, with a test
  that fails when a route changes without it.
- **Account deletion** as one endpoint, with answers that tell apart
  "nothing was deleted" from "data deleted, login not".

Check each against the project. Some may exist under another name.

## Payments

If the project sells a subscription on the web, the app is constrained in
what it may show and link to, and the rules change. Before designing any
screen that mentions a plan or a price:

- Fetch the current App Store Review Guidelines section on payments and
  quote the parts that apply, with the URL.
- Lay out the options for Mike: the app says nothing about paying, the
  app links out where that is allowed, or the app sells through Apple's
  in-app purchase as well.
- Whatever is chosen, the app must handle the server refusing a request
  because the subscription lapsed: say why, keep unsent work, stop retrying.

This does not block internal TestFlight. It blocks the App Store submission.
