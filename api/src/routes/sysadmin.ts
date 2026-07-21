import { Hono } from 'hono'
import { db } from '../db'
import { requirePriv } from '../privileges'
import type { Bindings, Variables } from '../index'

type Env = { Bindings: Bindings; Variables: Variables }

// ---------------------------------------------------------------- entities
export const entities = new Hono<Env>()

// List is unrestricted (any signed-in user needs it to populate the entity picker).
entities.get('/', async (c) => {
  const { data, error } = await db(c.env).from('legal_entities').select('*').order('code')
  if (error) return c.json({ error: error.message }, 500)
  // Only entities where the user has at least one role (admins see what they're granted).
  const { data: mine } = await db(c.env).from('erp_user_roles').select('entity_id').eq('user_id', c.get('user').id)
  const ids = new Set((mine ?? []).map((r) => r.entity_id))
  return c.json(ids.size ? data?.filter((e) => ids.has(e.id)) : [])
})

entities.post('/', requirePriv('sysadmin.entities.write'), async (c) => {
  const body = await c.req.json()
  const { data, error } = await db(c.env).from('legal_entities')
    .insert({ code: body.code, name: body.name, gstin: body.gstin ?? null, address: body.address ?? null, base_currency: body.baseCurrency ?? 'INR', fiscal_year_start: body.fiscalYearStart ?? '04-01' })
    .select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data, 201)
})

entities.patch('/:id', requirePriv('sysadmin.entities.write'), async (c) => {
  const body = await c.req.json()
  const { data, error } = await db(c.env).from('legal_entities').update(body).eq('id', c.req.param('id')).select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data)
})

entities.get('/:id/branches', async (c) => {
  const { data, error } = await db(c.env).from('branches').select('*').eq('entity_id', c.req.param('id')).order('branch_no')
  if (error) return c.json({ error: error.message }, 500)
  return c.json(data)
})

// ---------------------------------------------------------------- sequences
export const sequences = new Hono<Env>()

sequences.get('/', requirePriv('sysadmin.sequences.read'), async (c) => {
  const { data, error } = await db(c.env).from('number_sequences').select('*').eq('entity_id', c.get('entityId')).order('code')
  if (error) return c.json({ error: error.message }, 500)
  return c.json(data)
})

sequences.post('/', requirePriv('sysadmin.sequences.write'), async (c) => {
  const b = await c.req.json()
  const { data, error } = await db(c.env).from('number_sequences')
    .upsert({ entity_id: c.get('entityId'), code: b.code, prefix: b.prefix ?? '', suffix: b.suffix ?? '', next_no: b.nextNo ?? 1, padding: b.padding ?? 5, reset_policy: b.resetPolicy ?? 'never' }, { onConflict: 'entity_id,code' })
    .select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data)
})

sequences.post('/allocate', requirePriv('sysadmin.sequences.write'), async (c) => {
  const { code } = await c.req.json()
  const { data, error } = await db(c.env).rpc('allocate_number', { p_entity: c.get('entityId'), p_code: code })
  if (error) return c.json({ error: error.message }, 400)
  return c.json({ number: data })
})

// ---------------------------------------------------------------- users
export const users = new Hono<Env>()

users.get('/', requirePriv('sysadmin.users.read'), async (c) => {
  const sb = db(c.env)
  const { data: list, error } = await sb.auth.admin.listUsers({ perPage: 200 })
  if (error) return c.json({ error: error.message }, 500)
  const { data: assignments } = await sb.from('erp_user_roles').select('user_id, role_id, entity_id, erp_roles(name)')
  return c.json(list.users.map((u) => ({
    id: u.id, email: u.email, lastSignIn: u.last_sign_in_at,
    roles: (assignments ?? []).filter((a) => a.user_id === u.id),
  })))
})

users.post('/:id/roles', requirePriv('sysadmin.users.write'), async (c) => {
  const { roleId } = await c.req.json()
  const { error } = await db(c.env).from('erp_user_roles')
    .upsert({ user_id: c.req.param('id'), role_id: roleId, entity_id: c.get('entityId') })
  if (error) return c.json({ error: error.message }, 400)
  return c.json({ ok: true })
})

users.delete('/:id/roles/:roleId', requirePriv('sysadmin.users.write'), async (c) => {
  const { error } = await db(c.env).from('erp_user_roles').delete()
    .eq('user_id', c.req.param('id')).eq('role_id', c.req.param('roleId')).eq('entity_id', c.get('entityId'))
  if (error) return c.json({ error: error.message }, 400)
  return c.json({ ok: true })
})

// Role copy: copy user A's role assignments (this entity) to user B.
users.post('/copy-roles', requirePriv('sysadmin.users.write'), async (c) => {
  const { fromUserId, toUserId } = await c.req.json()
  const sb = db(c.env)
  const { data: src, error } = await sb.from('erp_user_roles').select('role_id')
    .eq('user_id', fromUserId).eq('entity_id', c.get('entityId'))
  if (error) return c.json({ error: error.message }, 500)
  if (!src?.length) return c.json({ error: 'source user has no roles in this entity' }, 400)
  const rows = src.map((r) => ({ user_id: toUserId, role_id: r.role_id, entity_id: c.get('entityId') }))
  const { error: e2 } = await sb.from('erp_user_roles').upsert(rows)
  if (e2) return c.json({ error: e2.message }, 400)
  return c.json({ ok: true, copied: rows.length })
})

// ---------------------------------------------------------------- roles
export const roles = new Hono<Env>()

roles.get('/', requirePriv('sysadmin.roles.read'), async (c) => {
  const sb = db(c.env)
  const [{ data: rs, error }, { data: privs }, { data: rp }] = await Promise.all([
    sb.from('erp_roles').select('*').order('name'),
    sb.from('erp_privileges').select('*').order('code'),
    sb.from('erp_role_privileges').select('*'),
  ])
  if (error) return c.json({ error: error.message }, 500)
  return c.json({ roles: rs, privileges: privs, rolePrivileges: rp })
})

roles.post('/', requirePriv('sysadmin.roles.write'), async (c) => {
  const b = await c.req.json()
  const { data, error } = await db(c.env).from('erp_roles').insert({ name: b.name, description: b.description ?? null }).select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data, 201)
})

// Replace a role's privilege set (the checkbox grid saves the whole set).
roles.put('/:id/privileges', requirePriv('sysadmin.roles.write'), async (c) => {
  const { privilegeCodes } = await c.req.json() as { privilegeCodes: string[] }
  const sb = db(c.env)
  const roleId = c.req.param('id')
  const { error: delErr } = await sb.from('erp_role_privileges').delete().eq('role_id', roleId)
  if (delErr) return c.json({ error: delErr.message }, 400)
  if (privilegeCodes.length) {
    const { error } = await sb.from('erp_role_privileges').insert(privilegeCodes.map((p) => ({ role_id: roleId, privilege_code: p })))
    if (error) return c.json({ error: error.message }, 400)
  }
  return c.json({ ok: true })
})

// ---------------------------------------------------------------- data import/export (Phase 9)
// CSV export + validated import (dry-run mode) for the master-data whitelist.
export const dataio = new Hono<Env>()

type IoRow = Record<string, unknown>
const str = (v: unknown) => (v == null ? '' : String(v).trim())
const numOr = (v: unknown, dflt: number) => (str(v) === '' || Number.isNaN(Number(v)) ? dflt : Number(v))

const IO_TABLES: Record<string, { seq: string | null; noField: string; required: string[]; columns: string[] }> = {
  erp_customers: {
    seq: 'CUST', noField: 'customer_no', required: ['name'],
    columns: ['customer_no', 'name', 'phone', 'email', 'gstin', 'billing_address', 'shipping_address', 'credit_limit', 'active'],
  },
  vendors: {
    seq: 'VEND', noField: 'vendor_no', required: ['name'],
    columns: ['vendor_no', 'name', 'phone', 'email', 'gstin', 'address', 'bank_details', 'active'],
  },
  items: {
    seq: 'ITEM', noField: 'item_no', required: ['name', 'item_type'],
    columns: ['item_no', 'name', 'item_type', 'category', 'uom', 'gst_rate', 'sales_price', 'active'],
  },
  employees: {
    seq: 'EMP', noField: 'employee_no', required: ['display_name', 'join_date'],
    columns: ['employee_no', 'display_name', 'phone', 'email', 'join_date', 'active'],
  },
  ledger_accounts: {
    seq: null, noField: 'account_no', required: ['account_no', 'name', 'group_code'],  // account_no is provided, not allocated
    columns: ['account_no', 'name', 'group_code', 'active'],
  },
}

function validateIoRow(table: string, r: IoRow, groups: Map<string, string>): string | null {
  const cfg = IO_TABLES[table]
  for (const f of cfg.required) if (!str(r[f])) return `${f} required`
  if (table === 'items' && !['product', 'part', 'service'].includes(str(r.item_type))) {
    return "item_type must be 'product', 'part' or 'service'"
  }
  if (table === 'employees' && !/^\d{4}-\d{2}-\d{2}$/.test(str(r.join_date))) {
    return 'join_date must look like 2026-07-01'
  }
  if (table === 'ledger_accounts' && !groups.has(str(r.group_code))) {
    return `unknown ledger group code '${str(r.group_code)}'`
  }
  return null
}

function ioPayload(table: string, r: IoRow, no: string, groups: Map<string, string>): IoRow {
  const active = str(r.active) === '' ? true : !['false', '0', 'no'].includes(str(r.active).toLowerCase())
  switch (table) {
    case 'erp_customers': return {
      customer_no: no, name: str(r.name), phone: str(r.phone) || null, email: str(r.email) || null,
      gstin: str(r.gstin) || null, billing_address: str(r.billing_address) || null,
      shipping_address: str(r.shipping_address) || null, credit_limit: numOr(r.credit_limit, 0), active,
    }
    case 'vendors': return {
      vendor_no: no, name: str(r.name), phone: str(r.phone) || null, email: str(r.email) || null,
      gstin: str(r.gstin) || null, address: str(r.address) || null, bank_details: str(r.bank_details) || null, active,
    }
    case 'items': return {
      item_no: no, name: str(r.name), item_type: str(r.item_type), category: str(r.category) || null,
      uom: str(r.uom) || 'pcs', gst_rate: numOr(r.gst_rate, 18), sales_price: numOr(r.sales_price, 0), active,
    }
    case 'employees': return {
      employee_no: no, display_name: str(r.display_name), phone: str(r.phone) || null,
      email: str(r.email) || null, join_date: str(r.join_date), active,
    }
    default: return {  // ledger_accounts
      account_no: no, name: str(r.name), group_id: groups.get(str(r.group_code)), active,
    }
  }
}

dataio.get('/export/:table', requirePriv('sysadmin.dataio.read'), async (c) => {
  const table = c.req.param('table')
  const cfg = IO_TABLES[table]
  if (!cfg) return c.json({ error: `table must be one of: ${Object.keys(IO_TABLES).join(', ')}` }, 400)
  const sel = table === 'ledger_accounts' ? '*, ledger_groups(code)' : '*'
  const { data, error } = await db(c.env).from(table).select(sel)
    .eq('entity_id', c.get('entityId')).order(cfg.noField)
  if (error) return c.json({ error: error.message }, 500)
  const rows = ((data ?? []) as unknown as IoRow[]).map((r) =>
    table === 'ledger_accounts' ? { ...r, group_code: (r.ledger_groups as { code?: string } | null)?.code ?? '' } : r)
  const esc = (v: unknown) => `"${String(v ?? '').replace(/"/g, '""')}"`
  const csv = [cfg.columns.map(esc).join(','), ...rows.map((r) => cfg.columns.map((k) => esc(r[k])).join(','))].join('\n')
  return c.json({ table, rows: rows.length, csv })
})

dataio.post('/import/:table', requirePriv('sysadmin.dataio.write'), async (c) => {
  const table = c.req.param('table')
  const cfg = IO_TABLES[table]
  if (!cfg) return c.json({ error: `table must be one of: ${Object.keys(IO_TABLES).join(', ')}` }, 400)
  const { rows, dryRun } = await c.req.json() as { rows: IoRow[]; dryRun?: boolean }
  if (!Array.isArray(rows) || !rows.length) return c.json({ error: 'rows (non-empty array) required' }, 400)
  if (rows.length > 1000) return c.json({ error: 'max 1000 rows per import' }, 400)

  const sb = db(c.env)
  const groups = new Map<string, string>()
  if (table === 'ledger_accounts') {
    const { data: gs, error } = await sb.from('ledger_groups').select('id, code')
    if (error) return c.json({ error: error.message }, 500)
    for (const g of gs ?? []) groups.set(g.code, g.id)
  }

  const results: { row: number; ok: boolean; error?: string; no?: string }[] = []
  let inserted = 0
  for (let i = 0; i < rows.length; i++) {
    const r = rows[i]
    const invalid = validateIoRow(table, r, groups)
    if (invalid) { results.push({ row: i + 1, ok: false, error: invalid }); continue }
    if (dryRun) { results.push({ row: i + 1, ok: true }); continue }
    let no = str(r[cfg.noField])
    if (cfg.seq) {  // never trust pasted numbers: masters get sequence-allocated ids (backbone rule 2)
      const { data, error: seqErr } = await sb.rpc('allocate_number', { p_entity: c.get('entityId'), p_code: cfg.seq })
      if (seqErr) { results.push({ row: i + 1, ok: false, error: seqErr.message }); continue }
      no = data as string
    }
    const { error } = await sb.from(table).insert({ entity_id: c.get('entityId'), ...ioPayload(table, r, no, groups) })
    if (error) results.push({ row: i + 1, ok: false, error: error.message })
    else { inserted++; results.push({ row: i + 1, ok: true, no }) }
  }
  return c.json({ dryRun: !!dryRun, total: rows.length, inserted, results })
})

// ---------------------------------------------------------------- audit
export const audit = new Hono<Env>()

audit.get('/', requirePriv('sysadmin.audit.read'), async (c) => {
  let q = db(c.env).from('erp_audit_log').select('*').order('at', { ascending: false }).limit(200)
  const table = c.req.query('table')
  if (table) q = q.eq('table_name', table)
  const { data, error } = await q
  if (error) return c.json({ error: error.message }, 500)
  return c.json(data)
})
