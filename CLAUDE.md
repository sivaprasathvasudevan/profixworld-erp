# ProFixWorld ERP

Multi-legal-entity ERP evolving from ProFix CRM + profixworld.com.

## Stack (three-tier)
- Client: React + TypeScript + Vite PWA on Cloudflare Pages (apps/erp is the main shell; legacy single-file PWAs live in apps/legacy)
- API: Cloudflare Workers + Hono (api/) — ALL writes for ERP documents go through the API using the Supabase service-role key; validates Supabase Auth JWTs
- DB: Supabase Postgres, project toxwbjofyglbyjanxmzv. All schema changes via supabase CLI migrations in db/migrations. Never change the DB outside a migration file.

## Backbone rules (apply to every module)
1. Entity scoping: every transactional table has entity_id → legal_entities.id. Every list/query filters by the selected entity. Branches (old "shops") belong to an entity.
2. Number sequences: never display UUIDs or Date.now() ids. Allocate human ids via the sequence engine (number_sequences table + allocate_number(entity_id, code) atomic function).
3. Documents use the header/lines pattern: header table (id, doc_no, entity_id, status, totals) + lines table (line_no, item_id, qty, unit_price, discount, tax, line_amount). Header totals recomputed from lines on every line change.
4. Posting engine: posting a document is ONE Postgres transaction via the API: validate → allocate number → write voucher (balanced GL lines from posting profiles) → write inventory transactions → set posted=true. Posted documents are immutable.
5. Security: API middleware checks role privileges (module.function.action) per entity on every route. RLS remains enabled as backstop.
6. Every feature = migration + API endpoint(s) + UI + at least one test. Reports get their own screen with CSV/XLSX download.

## Conventions
- snake_case in DB, camelCase in TS. Zod schemas shared between API and client (packages/shared).
- Money: numeric(14,2), currency INR default, GST-inclusive pricing preserved from legacy (CGST+SGST split at display).
- Do not break the legacy apps: they read the same tables until each domain is migrated.

## Repo layout
- `apps/erp` — React+TS+Vite ERP shell (Cloudflare Pages)
- `apps/legacy` — the current live single-file PWAs, copied as-is (profix-crm/, profixworld/). Deployed unchanged until each domain migrates.
- `api/` — Cloudflare Workers + Hono. Service-role writes, JWT validation, privilege middleware.
- `db/` — supabase CLI project; all migrations in `db/migrations`, docs in `db/SCHEMA.md`.
- `packages/shared` — Zod schemas + TS types shared by api and erp.

## Environments
- Prod Supabase project ref: `toxwbjofyglbyjanxmzv`. Never mutate the DB outside a migration.
- Secrets live in env / Wrangler secrets, never committed. See `.env.example`.
