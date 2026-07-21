# ProFixWorld ERP

Multi-legal-entity ERP evolving from ProFix CRM + profixworld.com. See [CLAUDE.md](./CLAUDE.md) for the architecture contract every module follows.

## Layout
| Path | What |
|------|------|
| `apps/erp` | React + TS + Vite ERP shell (Cloudflare Pages) |
| `apps/legacy` | Live single-file PWAs copied as-is (`profix-crm/`, `profixworld/`) — deployed unchanged until each domain migrates |
| `api/` | Cloudflare Workers + Hono API (service-role writes, JWT + privilege middleware) |
| `db/` | Supabase CLI project — all schema changes as migrations in `db/migrations` |
| `packages/shared` | Zod schemas + TS types shared by `api` and `erp` |

## Prerequisites
- Node ≥ 20, pnpm 11, Supabase CLI, Wrangler. (`gh` needed for CI setup.)

## Setup (dev)
```bash
cp .env.example .env        # fill in the keys (see below)
pnpm install
pnpm dev:api                # Hono worker on :8787
pnpm dev:erp                # Vite shell on :5173
```

## Environments
- **Prod Supabase**: project `toxwbjofyglbyjanxmzv` (shared with the live legacy apps).
- **Dev**: use a Supabase branch or a separate project; never test destructive migrations against prod.
- Secrets: local in `.env` (gitignored); prod via Wrangler secrets / Pages env vars. Never commit `sb_secret_*`.

## Database (migrations only)
Supabase project lives in `db/supabase/`; migrations in `db/supabase/migrations/`. Baseline already captured (`00000000000000_remote_baseline.sql`).

```bash
# one-time: authenticate + link (needs SUPABASE_ACCESS_TOKEN + DB password)
supabase login
supabase --workdir db link --project-ref toxwbjofyglbyjanxmzv

pnpm db:baseline   # Docker-free schema snapshot via Management API (needs SUPABASE_ACCESS_TOKEN)
pnpm db:pull       # authoritative pg_dump baseline — needs Docker Desktop
pnpm db:push       # apply local migrations to remote (no Docker)
```
**Never** change the DB outside a migration file.

## Deploy
- API → `pnpm --filter @erp/api deploy` (Wrangler).
- ERP → Cloudflare Pages (build `apps/erp`).
- Legacy → unchanged existing deploys (`profix-crm`, `profixworld` Pages projects).
CI wires these on push to `main` (see `.github/workflows/`) once the GitHub repo exists.
