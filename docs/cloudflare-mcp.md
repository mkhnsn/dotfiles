# Cloudflare API MCP server, read-only (#119)

Status: design. Waiting on one read-only API token (below). Nothing with write access is added.

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
   (Unstable Studios vault, item `Cloudflare MCP read-only`, field `credential`).
2. **Header helper** in the dotfiles: `~/.local/bin/cf-mcp-headers` reads the token with
   `op read` (as `ha-mcp` does) and prints `{"Authorization": "Bearer <token>"}`. Claude Code's
   `headersHelper` runs it on each connection and again on a 401/403, and only after the project's
   trust dialog is accepted ([code.claude.com/docs/en/mcp](https://code.claude.com/docs/en/mcp)).
   The token never lands in a file or the shell environment.
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

- Whether `headersHelper` resolves a bare command on `PATH` or needs an absolute path. The docs'
  example uses an absolute path; if a bare name fails, the repo can't hard-code
  `/Users/mkhnsn`, so the fallback is a user-scope entry written by `claude-setup`.
- The token's zone list: all zones, or only the ones the Workers repos use.

## Not chosen

- **OAuth grant**: works with no token, but the grant isn't visible or pinned (see above).
- **Per-product servers** (docs, Browser Run, Containers, DEX, CASB): the API server's `docs` tool
  covers documentation, and the others aren't needed for Workers work.
