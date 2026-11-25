# Auth0 login

Login is Auth0 Universal Login through
[Auth0.swift](https://github.com/auth0/Auth0.swift), so every method the web
offers works in the app. Read its README for the current API before writing.

## The native application

Defined in the web repo's `infra/`, next to the SPA client, with the
Terraform helper for a native client. Applying it needs
Mike's go-ahead. The first app's web project has a working one (SKILL.md,
"Where to look").

- A public client: authentication method `none`, no secret.
- Grants: `authorization_code` and `refresh_token`.
- Rotating refresh tokens, with a 30-day lifetime and a 30 s reuse
  leeway. The leeway matters: the app and an extension are separate
  processes and can renew at the same moment.
- If the helper has no option for the lifetime, the leeway or the
  `mobile` block, patch the generated resource. Check whether the helper
  has gained them before copying a patch.
- The `mobile.ios` block carries the team ID and bundle ID. That is what
  lets the `https` callbacks work as Universal Links.
- The API (resource server) needs `allow_offline_access`.
- Export the client ID as a Terraform output. It goes in
  `Shared.xcconfig`; it is not a secret.

Callback URLs, each also an allowed logout URL, for `ios` and `macos`:

```
https://<login domain>/<platform>/<bundle id>/callback
<bundle id>://<login domain>/<platform>/<bundle id>/callback
```

Confirm the format in
https://github.com/auth0/Auth0.swift#configure-the-callback-and-logout-urls.

The login domain is the tenant's custom domain. Changing the bundle ID
means changing it in `infra/config.ts` too.

Plan with the project's own script. A plan only reads, and is fine;
applying needs Mike's go-ahead. If the project's settings include an
`AUTH0_AUDIENCE` for its API, the Auth0 provider reads it and can't reach
the Management API: set the provider's `audience` explicitly in
`config.ts`.

## In the app

- Use the custom scheme callback to start. The `https` Universal Link
  callback needs the Associated Domains entitlement
  (`webcredentials:<login domain>`), `useHTTPS()`, and a build signed by
  the team, simulator included. On the Mac, use the custom scheme.
- Open the login page in a private browser session: no "wants
  to use ... to sign in" prompt and no cookie for logout to clear. The cost
  is that the page never remembers the person.
- The session, refresh token included, is in the Keychain, this device
  only and left out of backups. On iOS it is stored in the App Group so an
  extension reads it.

## Session rules

These came out of review. Keep them in the app's CLAUDE.md.

- One `SessionStore` is the only way to log in, log out or get an access
  token. Views and the API client never touch Auth0 or the Keychain.
- Only one source file imports Auth0, plus its own test. Other tests use
  a fake.
- One Auth0 client per process. Its credentials manager can't coordinate
  renewal across instances.
- The store does one thing at a time. A logout waits for a renewal under
  way, so the renewal can't store the session again afterward.
- Work that outlives a view asks for a token for the session it began
  under. That stops one login's leftover request going out as the next
  person.
- Each login gets its own API client.
- When the API answers 401 to a session token, tell the session store,
  with that token. No network, or Auth0 being down, never logs anyone out.
- Logging out revokes the refresh token, removes the session, and removes
  the account's data from the device. With no network the token can't be
  revoked, and the rest still happens.
- A session that ends by itself keeps only what was never uploaded, for
  the same account's next login.
- Never log a token or put one in an error message.
- The app uses Auth0 access tokens only. Tokens the project issues for
  scripts are never used in the app.
