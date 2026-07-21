// Docker-free schema baseline via the Supabase Management API.
// Usage: SUPABASE_ACCESS_TOKEN=sbp_... node extract-baseline.mjs
// Writes supabase/migrations/00000000000000_remote_baseline.sql
import { writeFileSync } from 'node:fs'

const REF = 'toxwbjofyglbyjanxmzv'
const TOKEN = process.env.SUPABASE_ACCESS_TOKEN
if (!TOKEN) { console.error('set SUPABASE_ACCESS_TOKEN'); process.exit(1) }
const API = `https://api.supabase.com/v1/projects/${REF}/database/query`

async function q(sql) {
  const r = await fetch(API, {
    method: 'POST',
    headers: { Authorization: `Bearer ${TOKEN}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ query: sql }),
  })
  const j = await r.json()
  if (!r.ok) { console.error('QUERY FAILED:', j.message || JSON.stringify(j)); return [] }
  return j
}
const ddl = (rows) => rows.map((x) => Object.values(x)[0]).filter(Boolean).join('\n')

// --- introspection queries (public schema) ---
const Q = {
  extensions: `select 'CREATE EXTENSION IF NOT EXISTS ' || quote_ident(extname) || ';' from pg_extension e join pg_namespace n on n.oid=e.extnamespace where extname not in ('plpgsql') order by extname`,
  sequences: `select 'CREATE SEQUENCE IF NOT EXISTS public.' || quote_ident(sequencename) || ';' from pg_sequences where schemaname='public' order by sequencename`,
  tables: `select 'CREATE TABLE IF NOT EXISTS public.' || quote_ident(c.relname) || E' (\n' ||
      string_agg('  ' || quote_ident(a.attname) || ' ' || format_type(a.atttypid, a.atttypmod)
        || case when a.attnotnull then ' NOT NULL' else '' end
        || case when ad.adbin is not null then ' DEFAULT ' || pg_get_expr(ad.adbin, ad.adrelid) else '' end,
        E',\n' order by a.attnum) || E'\n);'
    from pg_class c join pg_namespace n on n.oid=c.relnamespace
      join pg_attribute a on a.attrelid=c.oid and a.attnum>0 and not a.attisdropped
      left join pg_attrdef ad on ad.adrelid=c.oid and ad.adnum=a.attnum
    where n.nspname='public' and c.relkind='r'
    group by c.relname order by c.relname`,
  constraints: `select 'ALTER TABLE public.' || quote_ident(rel.relname) || ' ADD CONSTRAINT ' || quote_ident(con.conname) || ' ' || pg_get_constraintdef(con.oid) || ';'
    from pg_constraint con join pg_class rel on rel.oid=con.conrelid join pg_namespace n on n.oid=rel.relnamespace
    where n.nspname='public' order by (con.contype='f'), rel.relname, con.conname`,
  indexes: `select indexdef || ';' from pg_indexes where schemaname='public'
    and indexname not in (select conname from pg_constraint where connamespace='public'::regnamespace and contype in ('p','u'))
    order by tablename, indexname`,
  rls: `select 'ALTER TABLE public.' || quote_ident(tablename) || ' ENABLE ROW LEVEL SECURITY;' from pg_tables where schemaname='public' and rowsecurity order by tablename`,
  policies: `select 'CREATE POLICY ' || quote_ident(policyname) || ' ON public.' || quote_ident(tablename)
      || ' AS ' || permissive || ' FOR ' || cmd || ' TO ' || array_to_string(roles, ', ')
      || coalesce(' USING (' || qual || ')', '') || coalesce(' WITH CHECK (' || with_check || ')', '') || ';'
    from pg_policies where schemaname='public' order by tablename, policyname`,
  functions: `select pg_get_functiondef(p.oid) || ';' from pg_proc p where p.pronamespace='public'::regnamespace and p.prokind in ('f','p') order by p.proname`,
  triggers: `select pg_get_triggerdef(t.oid) || ';' from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and not t.tgisinternal order by c.relname, t.tgname`,
  grants: `select 'GRANT ' || string_agg(distinct privilege_type, ', ') || ' ON public.' || quote_ident(table_name) || ' TO ' || quote_ident(grantee) || ';'
    from information_schema.role_table_grants where table_schema='public' and grantee in ('anon','authenticated','service_role')
    group by table_name, grantee order by table_name, grantee`,
}

const sections = [
  ['EXTENSIONS', Q.extensions],
  ['SEQUENCES', Q.sequences],
  ['TABLES', Q.tables],
  ['CONSTRAINTS (PK/UNIQUE/CHECK/FK)', Q.constraints],
  ['INDEXES', Q.indexes],
  ['FUNCTIONS / RPCs', Q.functions],
  ['TRIGGERS', Q.triggers],
  ['ROW LEVEL SECURITY', Q.rls],
  ['POLICIES', Q.policies],
  ['GRANTS', Q.grants],
]

let out = `-- ProFixWorld baseline schema (public) — project ${REF}
-- Generated Docker-free via Supabase Management API (extract-baseline.mjs).
-- Regenerate the authoritative version with \`supabase db pull\` once Docker is available.
set search_path = public;

`
for (const [title, sql] of sections) {
  const rows = await q(sql)
  const body = ddl(rows)
  out += `-- ============================================================\n-- ${title} (${rows.length})\n-- ============================================================\n${body}\n\n`
  console.error(`${title}: ${rows.length}`)
}

writeFileSync('supabase/migrations/00000000000000_remote_baseline.sql', out)
console.error(`\nwrote supabase/migrations/00000000000000_remote_baseline.sql (${out.length} bytes)`)
