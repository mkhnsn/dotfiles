# Delete my account

Apple requires an app that lets people create an account to let them
delete it in the app:
https://developer.apple.com/support/offering-account-deletion-in-your-app/
Read it; cite it in the PR.

The server does the deleting, in one endpoint. The app's job is to confirm,
stop syncing, and handle every outcome correctly, including the ones it
can't see.

## Before building

- **Never run it with a real login against any server, a local one
  included.** Where the server deletes the Auth0 login, the login it
  deletes is real either way, and it may be shared with other apps. Use
  `-sampleData`, whose pretend server fails halfway the first time and
  finishes the second.
- Mike decides whether deleting the account deletes the shared login.
- If the project bills, deletion must end the subscription too.

## The server

See the first app's web project for a working one (SKILL.md, "Where to
look"). What the app relies on:

- One endpoint, taking an Auth0 login only.
- Distinct answers: done; nothing was deleted (safe to carry on); data
  deleted but the login was not (retry within a limited time).
- Credentials issued before the deletion are refused afterward, so old
  tokens can't refill a deleted account.
- A test that fails when a table holding user data is missing from the
  deletion.

## The flow in the app

1. A menu item, then a sheet with an explicit button. The sheet can't be
   swiped away while a request is out. Double submission is guarded.
2. The confirmation uses the web's wording: what goes, that the login goes
   for every app that uses it, and that it can't be undone. Name the
   account. Put it in a scroll view so large text can't cut off the last
   line.
3. Stop syncing before the request.
4. Send the request and act on the outcome.

## Outcomes

| Outcome | What the app does |
| --- | --- |
| Done | Remove the session and everything kept for the account. The login screen says the account was deleted. |
| Nothing was deleted, and no earlier request is in doubt | Say so. Cancel returns to the data, which syncs as before. |
| Data deleted, login not | Remove the data and queued changes from the device. Offer to try again. The only other way on is to log out. |
| No answer, a timeout, a server error | The server may have deleted the data. Say it may have, keep syncing stopped, offer to try again or log out. |
| A refused token after a request that may have deleted the account | Treat it as deleted: remove everything, say the account was deleted. |
| A refused token on the first attempt | The login screen says the session ended, not that the account was deleted. Nothing unsent is kept: a delete was out. |

## What goes wrong

Mistakes to design against, each with a test:

- Treating an unknown outcome as "nothing was deleted", then resuming
  sync. The old token gets a 401, the person logs in again, and work that
  never uploaded goes into the account they asked to delete.
- Handling a 401 on a retry as an expired session: "Your session ended.
  Log in again." for a login that no longer exists, with unsent work kept.
- Unsent work surviving the deletion and uploading at the next login.
  While any delete is out, a session that ends keeps nothing.
- The erase on the device failing while the app says the data was
  deleted. Check the result.
- A half-finished deletion forgotten when the app is quit.
- A second window that keeps syncing.

## Tests

- Each row of the table.
- A 401 after an indeterminate failure, and after "login not deleted".
- A second delete while the first is suspended.
- Forgetting everything with a sync mid-flight.
- The store's remove-everything, including when the write fails.
