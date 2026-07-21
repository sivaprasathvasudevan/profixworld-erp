# ProFixWorld — existing DB schema (project `toxwbjofyglbyjanxmzv`)

> Inventory of the **current live** tables, grouped by domain.
>
> **Baseline captured** → `supabase/migrations/00000000000000_remote_baseline.sql`
> (94 tables · 236 constraints · 45 indexes · 134 functions/RPCs · 10 triggers · 168 policies · 285 grants).
> Generated Docker-free via the Supabase Management API (`db/extract-baseline.mjs`, run with `pnpm db:baseline`).
> Regenerate the pg_dump-authoritative version with `pnpm db:pull` once Docker Desktop is installed.
> **Never change the DB outside a migration.**

## CRM / Repair desk
| Table | Notes |
|-------|-------|
| `shops` | the branches/stores (→ becomes `branches` under a legal entity in Phase 1) |
| `memberships` | user ↔ shop with `role` (`owner` \| `staff`); the app has no `admin` tier |
| `crm_invites` | pending email invites; `crm_accept_invites()` RPC links invite → membership on first sign-in |
| `customers` | `id, shop_id, name, phone, created_at` |
| `repair_tickets` | jobs/board; device fields, status, customer_id, handled_by, returns/warranty |
| `ticket_parts`, `ticket_part_prices`, `ticket_services`, `ticket_money` | per-ticket detail (mostly header/line-ish) |
| `parts` | `id, shop_id, name, stock_qty, category` (legacy accessory stock) |
| `parts_pricing` | part price rules |
| `inventory` | `id, shop_id, item, brand, spec, qty, unit, cost, sell, reorder_at` (CRM stock) |
| `sales`, `sales_private` | counter/accessory sales (`sales.inventory_id` FK) |
| `bills`, `bill_items` | invoices |
| `cash_movements` | cash in/out |
| `activity_log` | `id, shop_id, ticket_id, actor, actor_email, action, at` (audit) |
| `shop_settings` | per-shop settings |
| `shop_services` | **service catalog / price list** (keep — this is the price setup) |

## Storefront (profixworld.com/inventory & store)
| Table | Notes |
|-------|-------|
| `store_products` | storefront catalog (`id, category_id, name, brand, spec, stock, price, owner_id, published, cost_price, partner_id, images, …`) |
| `stock_moves` | storefront stock movements |

## HR (staff/me PWAs depend on these — do not break)
`staff_members`, `staff_attendance`, `staff_roster`, `staff_leave`, `staff_advances`, `staff_incentives`

## Driver / logistics
`profix_drivers` (register via `driver_register` SECURITY DEFINER RPC — anon insert fails RLS), driver portal tables

## Partner / trade
`partner_*`, `trade_*` (partner submissions, trade docs) → migrate to vendors/purchase docs in Phase 5

## Auth
`auth.users` (Supabase Auth). Owners: Venky (all 3 shops), Sabin, Vasu; solution architect Vigu (owner on all shops).

---
### To produce the authoritative baseline
```bash
supabase login                                   # needs SUPABASE_ACCESS_TOKEN
supabase link --project-ref toxwbjofyglbyjanxmzv # needs DB password
supabase db pull --schema public,auth            # writes db/migrations/<ts>_baseline.sql
```
Then reconcile this doc against the generated SQL and list every RLS policy, function, and trigger.
