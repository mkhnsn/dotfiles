# Cloudflare API MCP server, read-only (#119)

Status: in use, at user scope on this Mac and echo-turbine (decided 2026-11-22: the planned
per-repo trial was in `unstable-studios/dashboard`, which isn't launched yet, and the token is
what keeps it read-only, so a repo boundary added little). Nothing with write access is added.

## What it is

Cloudflare's API server, `https://mcp.cloudflare.com/mcp` (Streamable HTTP), covers the whole
Cloudflare API in a few tools: `search` (finds endpoints in the OpenAPI spec), `execute` (runs
JavaScript that calls `cloudflare.request()`), `docs` and `whoami`. Source:
[developers.cloudflare.com › MCP servers for Cloudflare](https://developers.cloudflare.com/agents/model-context-protocol/mcp-servers-for-cloudflare/),
[github.com/cloudflare/mcp](https://github.com/cloudflare/mcp).

`execute` can send any request the credential allows: DNS edits, Access policy changes, Worker
deletes. The server has no read-only switch, so the credential is the only limit.

## Why a token, not OAuth

OAuth is the default: Claude Code opens Cloudflare's consent page and you pick what to grant. The
grant lives in Claude Code's credential store, nothing in the repo says what it allows, and the
server asks to widen it when a call needs a missing scope. That's easy to click through.

A Cloudflare API token can be read-only by construction and is visible in the dashboard. The
server takes one as `Authorization: Bearer <token>`. Account tokens need **Account Resources:
Read** so the server can find the account; tokens with client IP filtering aren't supported.

## Design

1. **Token** (by hand, Cloudflare dashboard › Manage account › API tokens, an account token):
   name `claude-mcp-readonly`; only **Read** permissions: Account Resources (required), then
   Workers scripts, KV, R2, D1, analytics, Access apps and policies, and Zone and DNS for the
   Unstable Studios zones, picked from the dashboard's permission list. No Edit permission. Stored in 1Password
   at `op://Automation/Cloudflare MCP read-only Token/credential`.

   The token made on 2026-11-22 has two policies, both only Read (checked with
   `GET /accounts/{id}/tokens/{id}`: every group is named `… Read` or `… Read-Only`): every
   account-level Read permission (141 groups), and zone Read (47 groups) for all 28 zones in
   the account. That includes Billing, Audit Logs and the Zero Trust PII reads; narrow it in
   the dashboard if that's more than Claude should see.
2. **Header helper** in the dotfiles, built like `ha-mcp`: `cf-mcp-headers` prints
   `{"Authorization": "Bearer <token>"}` from a token stored once by `cf-mcp-headers --store-token`:
   - macOS: the login Keychain (service `cf-mcp`, account `cloudflare-readonly`), copied from
     1Password by the `mac-setup` step `cf_mcp`.
   - Linux: `~/.config/cf-mcp/token`, mode 0600, since there's no Keychain. On echo-turbine
     1Password is only reachable from its desktop session, not over SSH, so the token is piped
     from a Mac's Keychain instead (`--store-token -` reads stdin; the token is never shown or
     in an argument):

     ```bash
     security find-generic-password -s cf-mcp -a cloudflare-readonly -w |
       ssh echo-turbine '~/.local/bin/cf-mcp-headers --store-token -'
     ```

   Not `op read` at runtime: Claude Code gives a `headersHelper` 10 seconds and runs it on every
   connect and reconnect (and again when a tool call gets a 401/403), so a locked 1Password would
   fail it ([code.claude.com/docs/en/mcp](https://code.claude.com/docs/en/mcp)). The token never
   lands in a repo file or the shell environment.
3. **User scope**: `run_onchange_after_claude-setup.sh.tmpl` registers `cloudflare` with
   `claude mcp add-json --scope user` on every machine where `cf-mcp-headers` finds a token, and
   removes it where it doesn't (so sessions there don't carry a server that can't connect):

   ```json
   {
     "type": "http",
     "url": "https://mcp.cloudflare.com/mcp",
     "headers": { "Authorization": "Bearer missing" },
     "headersHelper": "~/.local/bin/cf-mcp-headers"
   }
   ```

   The script re-runs on the next `chezmoi apply` after the token is stored.
4. **Check that a write fails** before relying on it: ask it to add a DNS TXT record and expect
   a 403.

Write access (a second token with Edit permissions) is a separate decision for Mike, not part
of this.

## Open questions

- The helper is named as `~/.local/bin/cf-mcp-headers`: Claude Code runs it in a shell, so `~`
  expands, and it doesn't depend on whether an app launched from the Dock has `~/.local/bin` on
  its `PATH`.
- Without a token (or if the helper fails), Claude Code connects with the static `headers`
  alone, and a server that gets no `Authorization` offers an OAuth sign-in from `/mcp`, which can
  grant write access. So the definition also sets a static `Authorization: Bearer missing`: the
  server rejects it and nothing offers OAuth. Don't sign in to it with OAuth.
- If the Keychain item ever stops trusting `/usr/bin/security`, reading it shows a prompt, which
  can run past the helper's 10 s; `cf-mcp-headers --store-token` rewrites the item.
- Zone Read covers all zones today; narrow it to the ones the Workers repos use if that's
  more than needed.

## Not chosen

- **OAuth grant**: works with no token, but the grant isn't visible or pinned (see above).
- **Per-product servers** (docs, Browser Run, Containers, DEX, CASB): the API server's `docs` tool
  covers documentation, and the others aren't needed for Workers work.
