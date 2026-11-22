# Cloudflare API MCP server, read-only (#119)

Status: trial. The read-only token exists and `cf-mcp-headers` serves it; `unstable-studios/dashboard`
has the server in its `.mcp.json`. Nothing with write access is added.

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

   The token made on 2026-11-22 has every account-level Read permission (checked with
   `GET /accounts/{id}/tokens/{id}`: 150-odd groups, all named `… Read` or `… Read-Only`) and
   no zone permissions, so DNS records and zone settings aren't visible. That includes Billing,
   Audit Logs and the Zero Trust PII reads; narrow it in the dashboard if that's more than
   Claude should see. Adding zone Read for DNS is a dashboard change, not a code one.
2. **Header helper** in the dotfiles, built like `ha-mcp`: `cf-mcp-headers --store-token` copies
   the token from 1Password into the macOS Keychain once (`mac-setup` step `cf_mcp`; Keychain
   service `cf-mcp`, account `cloudflare-readonly`), and at runtime
   `~/.local/bin/cf-mcp-headers` reads it with `security find-generic-password` and prints
   `{"Authorization": "Bearer <token>"}`. Not `op read` at runtime: Claude Code gives a
   `headersHelper` 10 seconds, runs it on every connect and reconnect (and again when a tool call
   gets a 401/403), and strips variables named like `*TOKEN*` from a project-scope helper's
   environment, so a locked 1Password or a service-account token would fail it. It runs only after
   the project's own folder is trusted
   ([code.claude.com/docs/en/mcp](https://code.claude.com/docs/en/mcp)). The token never lands in
   a repo file or the shell environment.
3. **One Workers repo first**: `unstable-studios/dashboard` (a Worker with D1, KV and R2), in its
   `.mcp.json`:

   ```json
   {
     "mcpServers": {
       "cloudflare": {
         "type": "http",
         "url": "https://mcp.cloudflare.com/mcp",
         "headersHelper": "cf-mcp-headers"
       }
     }
   }
   ```

   Project scope, so it's approved per repo and only that repo's sessions see it.
4. **Try it** for a week of normal work: list Workers and their bindings, D1 tables, R2 buckets,
   recent deploys, Access apps. Check that a write fails: ask it to add a DNS TXT record and
   expect a 403.
5. **Then decide**: move it to user scope in `run_onchange_after_claude-setup.sh.tmpl` (the token
   stays read-only), keep it per repo, or drop it. Record the reason on #119.

Write access (a second token with Edit permissions) is a separate decision for Mike, not part
of this.

## Open questions

- `headersHelper` takes an absolute path or a command on `PATH`, so the bare `cf-mcp-headers`
  works when Claude Code inherits `~/.local/bin` on its `PATH` (the shell and the desktop app do);
  if a launch doesn't, the fallback is a user-scope entry with the absolute path, written by
  `claude-setup`.
- Zone Read (DNS, zone settings): none today; all zones, or only the ones the Workers repos use.

## Not chosen

- **OAuth grant**: works with no token, but the grant isn't visible or pinned (see above).
- **Per-product servers** (docs, Browser Run, Containers, DEX, CASB): the API server's `docs` tool
  covers documentation, and the others aren't needed for Workers work.
