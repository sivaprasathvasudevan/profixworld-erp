# ProFixWorld ERP — Claude Code Prompts (Phase by Phase)

How to use: create the monorepo, put the CLAUDE.md below at its root, then run one phase prompt per Claude Code session. Review + deploy after each phase. Do not skip Phase 0.

---

## CLAUDE.md (put this at the repo root first)

```markdown
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
```

---

## Phase 0 — Foundation & hygiene

```
Set up the ProFixWorld ERP monorepo and bring the existing system under control.

1. Create a pnpm monorepo: apps/erp (React+TS+Vite, empty shell), apps/legacy (copy the current profix-crm index.html and profix-deploy HTML apps as-is, excluding all *.bak.html), api/ (Cloudflare Workers + Hono, hello-world route with Supabase JWT validation middleware), db/ (supabase CLI project), packages/shared (Zod schemas + TS types).
2. Using the supabase CLI against our project, pull the ENTIRE remote schema into db/migrations as a baseline migration: all tables, RLS policies, functions/RPCs, triggers, grants. This is the single most important step — nothing in the DB is currently versioned.
3. Write db/SCHEMA.md documenting every existing table grouped by domain (store_*, staff_*, driver_*, partner_*, CRM tables: shops, memberships, repair_tickets, customers, ticket_*, parts*, inventory, sales, bills, cash_movements, activity_log, shop_settings).
4. GitHub Actions: on push to main, deploy apps to Cloudflare Pages and api to Workers; supabase migrations applied via CI with a manual approval gate for prod.
5. Move all keys/URLs into env config; document dev vs prod environments in README.
Do not change any runtime behavior of the legacy apps in this phase.
```

## Phase 1 — Core platform (System Administration + Legal Entities)

```
Build the ERP backbone. Follow CLAUDE.md backbone rules.

1. Migrations: legal_entities (id, code, name, gstin, address, base_currency, fiscal_year_start, active); branches table linking existing shops rows to an entity (migration script maps every current shop to a default entity 'PROFIX'); number_sequences (entity_id, code, prefix, suffix, next_no, padding, reset_policy) + allocate_number(entity_id, code) as an atomic SQL function (SELECT ... FOR UPDATE); app_users view over auth.users + profile table; roles, privileges (module, function, action), role_privileges, user_roles (user_id, role_id, entity_id); audit_log (entity_id, actor, table_name, record_id, action, diff jsonb, at) + generic audit trigger.
2. API: CRUD for entities, sequences, users, roles; role-copy endpoint (copy all privileges from user A to user B); permission middleware reading user_roles per entity; seed script creating admin role with all privileges.
3. apps/erp shell: login (Supabase Auth), left-nav with the 12 ERP modules, top-bar legal entity picker persisted per user, System Administration screens: entity master, number sequences, user master, role matrix editor (checkbox grid module×action), role copy, audit log viewer.
4. Tests: sequence allocation under concurrency (no gaps/dupes in a 100-parallel test), permission middleware deny/allow.
```

## Phase 2 — Financial core (General Ledger / Chart of Accounts)

```
Build the GL module and the posting engine. Follow CLAUDE.md backbone rules.

1. Migrations: ledger_groups (hierarchical: Assets/Liabilities/Equity/Income/Expense), ledger_accounts (entity_id, account_no via sequence, name, group_id, type, active), financial_dimensions (code, name) + dimension_values, vouchers (entity_id, voucher_no, date, source_module, source_doc_id, description, posted_at, posted_by), voucher_lines (voucher_id, line_no, account_id, debit, credit, dimension_values jsonb), posting_profiles (entity_id, module, event, debit_account_id, credit_account_id — e.g. sales.invoice → Dr Receivables / Cr Revenue + Cr GST payable), fiscal_periods with open/closed status.
2. API: post_voucher(entity, lines[]) — validates balanced debits=credits, open period, allocates voucher_no, writes atomically. Manual GL journal endpoints (create draft header/lines, post). Posting-profile CRUD.
3. UI: chart of accounts tree, ledger account master, posting profiles, manual journal (header/lines form using the shared document component — build that reusable component now), voucher browser with filters (date, account, source).
4. Reports (separate screens, CSV/XLSX download): trial balance, ledger account detail, P&L, balance sheet — all filtered by entity + period.
5. Seed a standard Indian CoA (with GST output/input accounts) for the default entity.
6. Tests: unbalanced voucher rejected, closed-period rejected, P&L totals match posted vouchers.
```

## Phase 3 — Inventory + Warehouse

```
Build Inventory and Warehouse on the backbone. Follow CLAUDE.md rules.

1. Migrations: items (entity_id, item_no via sequence, name, type product/part/service, category, uom, gst_rate, active) with a data migration folding legacy store_products and CRM parts/inventory into it (keep legacy tables as views or sync during transition); dimension_types (Model, Specification, Size, Colour — admin-extensible) + dimension_values + item_dimensions; warehouses (entity_id, warehouse_no, name, branch_id, is_store) mapped from existing shops; inventory_transactions (entity_id, item_id, warehouse_id, dimensions jsonb, qty_in, qty_out, cost, source_module, source_doc_id, date); on_hand as a materialized view or maintained table per item+warehouse+dimensions; transfer_journals and movement_journals (header/lines, posted flag).
2. API: item + dimension + warehouse CRUD; journal create/post — transfer posts paired out/in inventory_transactions between warehouses; movement journal posts adjustments with a GL voucher (Dr/Cr inventory adjustment via posting profile); weighted-average cost maintained on items per entity.
3. UI: item master with dimension attachment, warehouse master, on-hand inquiry (filter by item/warehouse/dimension), transfer journal, movement journal — all using the shared document component.
4. Reports: stock on hand, stock movement/ledger, valuation — CSV/XLSX download.
5. Tests: transfer conserves total qty; valuation recomputes correctly; on-hand never negative without an override privilege.
```

## Phase 4 — Sales & Marketing

```
Build the sales cycle: Quotation → Order → Invoice → Posting. Follow CLAUDE.md rules.

1. Migrations: customers upgrade (entity_id, customer_no via sequence, name, phone, email, billing/shipping addresses, gstin, credit_points, credit_limit) with migration from CRM customers + store phone-book; sales_quotations + lines; sales_orders + lines (fields: item_id, description, qty, unit_price, discount, tax, line_amount; header total_amount maintained from lines); sales_invoices + lines; customer_transactions view over vouchers filtered to receivables.
2. API: quotation CRUD + convert-to-order endpoint (approval flag → creates SO referencing quotation); order CRUD; invoice creation from order (full or partial qty); invoice POST uses the posting engine: voucher (Dr Receivables, Cr Revenue, Cr GST output per posting profile) + inventory_transactions (issue from the order's warehouse) in one transaction; payment receipt endpoint posting Dr Bank/Cash, Cr Receivables; credit_points accrual rule on posted invoices.
3. UI: customer master; quotation form (header/lines, convert button); sales order form; invoice from order with post button; customer transactions screen filterable by customer_no / sales_no / date; print/PDF invoice keeping the existing GST-inclusive CGST+SGST layout.
4. Reports: sales register, customer aging, item-wise sales — CSV/XLSX/PDF.
5. Transition: write an adapter so legacy store checkout creates a sales_order via the API; legacy counter sale creates order+invoice+post in one call.
6. Tests: quote→order copies lines; posting decrements on-hand and balances the voucher; partial invoicing; aging math.
```

## Phase 5 — Procurement & Sourcing

```
Mirror the sales cycle for vendors. Follow CLAUDE.md rules.

1. Migrations: vendors (entity_id, vendor_no via sequence, name, phone, gstin, bank details, addresses) migrating partner_members/trade partners; purchase_quotations, purchase_orders, goods_receipts, purchase_invoices (all header/lines); vendor_transactions view.
2. API: PO lifecycle (draft → approved → sent); GRN posting → inventory_transactions IN at PO cost (updates weighted average); purchase invoice posting → voucher (Dr Inventory/Expense + GST input, Cr Payables), 3-way match warning (PO vs GRN vs invoice qty/price); vendor payment posting.
3. UI: vendor master, PO form, GRN form (receive against PO lines), purchase invoice with post, vendor transactions screen.
4. Reports: purchase register, vendor aging, pending POs/GRNs.
5. Transition: partner app submissions become PO-linked; trade_docs map to purchase documents.
6. Tests: GRN updates on-hand and cost; 3-way mismatch flagged; payables balance.
```

## Phase 6 — HR & Payroll + Employee Management

```
Extend the existing HR foundation into full HR/Payroll + Employee Management. Follow CLAUDE.md rules. Existing tables staff_members, staff_attendance, staff_roster, staff_leave, staff_advances, staff_incentives KEEP WORKING — the staff/me PWAs depend on them.

1. Migrations: employees (entity_id, employee_no via sequence, linked 1:1 to staff_members, personal details, statutory ids PAN/Aadhaar/UAN/ESI, bank); departments, positions/designations, employment_history (position, department, from/to, salary revision), workplace_assignments (employee, branch/warehouse, from/to); employee_documents (uses the DMS tables from Phase 8 or a simple storage table now); salary_structures (components: basic, HRA, allowances, deductions PF/ESI/PT/TDS with formula type fixed/percent); payroll_runs + payroll_lines (per employee per component), payslips.
2. API: payroll run generation for entity+month — pulls attendance (present days from staff_attendance), applies salary structure, leave without pay, advances recovery (staff_advances), incentives (staff_incentives); approve → post via posting engine (Dr Salary expense components, Cr Payables/statutory liabilities); payslip PDF endpoint.
3. UI: employee master (tabs: profile, employment history, documents, workplace, salary structure); department/position masters; leave approval (reuse data, new screen); payroll run screen (generate → review lines → approve/post); payslip download; attendance monthly view.
4. Reports: attendance register, payroll register, PF/ESI/PT/TDS summaries, headcount — CSV/XLSX.
5. Tests: pay run math (LOP, advance recovery, PF caps), payroll voucher balances, history immutability after posting.
```

## Phase 7 — Service Management

```
Formalize repair tickets into ERP service orders with a workflow engine. Follow CLAUDE.md rules. The CRM repair flow is live — migrate without breaking it.

1. Migrations: service_orders (entity_id, service_order_no via sequence, customer_id fetched from customer master, device fields from repair_tickets, status, warehouse_id) + service_order_lines (item_id nullable for manual lines, description, qty, price) — migrate repair_tickets/ticket_parts/ticket_services into these; workflows + workflow_steps (configurable: Order received → Work in progress → Completed → Delivered → Closed) + workflow_transitions log (who, when, note).
2. API: service order CRUD; transition endpoint enforcing step order + privilege; on Completed→Delivered: post via posting engine (Dr Cash/Receivables, Cr Service revenue + parts revenue, GST; inventory issue for parts lines); keep/upgrade public_ticket_status RPC → public status page /s/<token> shareable via wa.me link (already the pattern in the codebase).
3. UI: service order board (kanban by workflow step — port the CRM board), order form with customer fetch, lines from item master or manual, status timeline, WhatsApp share button.
4. Reports: open orders by status/age, technician productivity, service revenue.
5. Tests: illegal transitions rejected; delivery posts revenue + consumes parts; public link shows status only (no prices).
```

## Phase 8 — Asset Management + Document Management

```
Build the two remaining modules. Follow CLAUDE.md rules.

1. Document management migrations: documents (entity_id, doc_no via sequence, title, category, storage_path in Supabase Storage, version, uploaded_by, at) + document_links (document_id, table_name, record_id) so any master/transaction can carry attachments; versioning keeps prior storage paths.
2. DMS API/UI: upload/download via signed URLs, attachment panel component dropped into every master form (customer, vendor, employee, item, asset) and document form.
3. Asset migrations: assets (entity_id, asset_no via sequence, name, category, acquisition_date, cost, depreciation_method straight_line/wdv, rate, useful_life, accumulated_depreciation, status active/disposed, linked purchase_invoice_id); depreciation_runs + lines.
4. Asset API: create from purchase invoice line (asset-type item); monthly depreciation run → posting engine (Dr Depreciation expense, Cr Accumulated depreciation); disposal posting with gain/loss.
5. UI: asset register, asset form with depreciation schedule preview, depreciation run screen, disposal.
6. Reports: fixed asset register, depreciation schedule — CSV/XLSX.
7. Tests: SL and WDV math, disposal gain/loss, document version retrieval.
```

## Phase 9 — Reporting, Import/Export, Integrations

```
Close out System Administration and cross-cutting features. Follow CLAUDE.md rules.

1. Data import/export: CSV template download + validated import (dry-run mode showing row errors) for every master: customers, vendors, items, employees, ledger accounts, assets, sequences. Export respects entity + role.
2. Report framework polish: every module's report screens get consistent filter bar (entity, date range, master filters), server-side pagination, CSV/XLSX/PDF download endpoints.
3. Consolidated reporting: cross-entity trial balance and P&L (read-only, owner privilege), entity comparison dashboard.
4. Integration framework: outbound webhooks (order posted, invoice posted, service status changed) with retry + signing; WhatsApp integration abstraction (current wa.me deep links, upgrade path to WhatsApp Business API behind one interface); payment gateway abstraction (current UPI intent, Razorpay-ready interface).
5. Ops: API rate limiting, structured logs, /health, backup/restore runbook for Supabase, RLS review ensuring every ERP table denies direct client writes.
6. Final verification suite: end-to-end test — quotation → order → invoice → GL → stock; PO → GRN → purchase invoice → payables; payroll run → GL; service order full workflow → revenue.
```

---

## Tips for running these with Claude

- One phase per session; paste the phase prompt, let Claude plan first (plan mode), review the plan, then execute.
- After each phase: run the tests, deploy to dev, click through, then prod.
- If a phase is too big for one session, split at the numbered items — they're ordered by dependency.
- Keep CLAUDE.md updated when conventions change; it's the contract every future session inherits.
