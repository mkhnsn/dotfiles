---
paths:
  - "**/wrangler*.{json,jsonc,toml}"
  - "**/migrations/*.sql"
---

# Cloudflare Workers and D1

- Config, env or target names with `prod`/`prd`/`production` as a segment are production.
- D1 `DROP TABLE` fires `ON DELETE CASCADE` into child tables (`defer_foreign_keys` doesn't stop it); rebuild tables without dropping parents. Deploys migrate D1 before the new Worker is live, so drop old tables a release later.
- `wrangler secret bulk` only adds or updates; a secret removed from Doppler stays on the Worker until deleted with `wrangler secret delete`.
