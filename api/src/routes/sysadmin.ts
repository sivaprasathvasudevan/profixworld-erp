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
