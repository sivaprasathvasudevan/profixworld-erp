import { Hono } from 'hono'
import { db } from '../db'
import { requirePriv } from '../privileges'
import type { Bindings, Variables } from '../index'

type Env = { Bindings: Bindings; Variables: Variables }

export const gl = new Hono<Env>()

// ------------------------------------------------------------ chart of accounts
gl.get('/groups', requirePriv('gl.accounts.read'), async (c) => {
  const { data, error } = await db(c.env).from('ledger_groups').select('*').order('code')
  if (error) return c.json({ error: error.message }, 500)
  return c.json(data)
})

gl.get('/accounts', requirePriv('gl.accounts.read'), async (c) => {
  const { data, error } = await db(c.env).from('ledger_accounts')
    .select('*, ledger_groups(code, name, kind)')
    .eq('entity_id', c.get('entityId')).order('account_no')
  if (error) return c.json({ error: error.message }, 500)
  return c.json(data)
})

gl.post('/accounts', requirePriv('gl.accounts.write'), async (c) => {
  const b = await c.req.json()
  const { data, error } = await db(c.env).from('ledger_accounts')
    .insert({ entity_id: c.get('entityId'), account_no: b.accountNo, name: b.name, group_id: b.groupId })
    .select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data, 201)
})

gl.patch('/accounts/:id', requirePriv('gl.accounts.write'), async (c) => {
  const b = await c.req.json()
  const { data, error } = await db(c.env).from('ledger_accounts')
    .update({ name: b.name, active: b.active }).eq('id', c.req.param('id')).eq('entity_id', c.get('entityId'))
    .select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data)
})

// ------------------------------------------------------------ posting profiles
gl.get('/profiles', requirePriv('gl.profiles.read'), async (c) => {
  const { data, error } = await db(c.env).from('posting_profiles').select('*')
    .eq('entity_id', c.get('entityId')).order('module').order('event')
  if (error) return c.json({ error: error.message }, 500)
  return c.json(data)
})

gl.post('/profiles', requirePriv('gl.profiles.write'), async (c) => {
  const b = await c.req.json()
  const { data, error } = await db(c.env).from('posting_profiles')
    .upsert({ entity_id: c.get('entityId'), module: b.module, event: b.event, debit_account_id: b.debitAccountId ?? null, credit_account_id: b.creditAccountId ?? null }, { onConflict: 'entity_id,module,event' })
    .select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data)
})

// ------------------------------------------------------------ journals (header/lines, draft → posted)
gl.get('/journals', requirePriv('gl.journals.read'), async (c) => {
  const { data, error } = await db(c.env).from('gl_journals').select('*')
    .eq('entity_id', c.get('entityId')).order('created_at', { ascending: false }).limit(100)
  if (error) return c.json({ error: error.message }, 500)
  return c.json(data)
})

gl.get('/journals/:id', requirePriv('gl.journals.read'), async (c) => {
  const sb = db(c.env)
  const [{ data: header, error }, { data: lines }] = await Promise.all([
    sb.from('gl_journals').select('*').eq('id', c.req.param('id')).eq('entity_id', c.get('entityId')).single(),
    sb.from('gl_journal_lines').select('*').eq('journal_id', c.req.param('id')).order('line_no'),
  ])
  if (error) return c.json({ error: error.message }, 404)
  return c.json({ ...header, lines })
})

gl.post('/journals', requirePriv('gl.journals.write'), async (c) => {
  const b = await c.req.json()
  const sb = db(c.env)
  const { data: no, error: seqErr } = await sb.rpc('allocate_number', { p_entity: c.get('entityId'), p_code: 'GLJ' })
  if (seqErr) return c.json({ error: seqErr.message }, 400)
  const { data, error } = await sb.from('gl_journals')
    .insert({ entity_id: c.get('entityId'), journal_no: no, journal_date: b.journalDate ?? new Date().toISOString().slice(0, 10), description: b.description ?? null, created_by: c.get('user').id })
    .select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data, 201)
})

// Replace the full line set of a draft journal; header totals recomputed (backbone rule 3).
gl.put('/journals/:id/lines', requirePriv('gl.journals.write'), async (c) => {
  const { lines } = await c.req.json() as { lines: { accountId: string; debit: number; credit: number; memo?: string }[] }
  const sb = db(c.env)
  const id = c.req.param('id')
  const { data: j, error: jErr } = await sb.from('gl_journals').select('status').eq('id', id).eq('entity_id', c.get('entityId')).single()
  if (jErr) return c.json({ error: jErr.message }, 404)
  if (j.status !== 'draft') return c.json({ error: 'only draft journals can be edited' }, 400)
  const { error: delErr } = await sb.from('gl_journal_lines').delete().eq('journal_id', id)
  if (delErr) return c.json({ error: delErr.message }, 400)
  if (lines.length) {
    const { error } = await sb.from('gl_journal_lines').insert(lines.map((l, i) => ({
      journal_id: id, entity_id: c.get('entityId'), line_no: i + 1,
      account_id: l.accountId, debit: l.debit || 0, credit: l.credit || 0, memo: l.memo ?? null,
    })))
    if (error) return c.json({ error: error.message }, 400)
  }
  const dr = lines.reduce((s, l) => s + (l.debit || 0), 0)
  const cr = lines.reduce((s, l) => s + (l.credit || 0), 0)
  const { data, error } = await sb.from('gl_journals')
    .update({ total_debit: Math.round(dr * 100) / 100, total_credit: Math.round(cr * 100) / 100 })
    .eq('id', id).select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data)
})

gl.post('/journals/:id/post', requirePriv('gl.journals.post'), async (c) => {
  const { data, error } = await db(c.env).rpc('post_gl_journal', { p_journal: c.req.param('id'), p_actor: c.get('user').id })
  if (error) return c.json({ error: error.message }, 400)
  return c.json({ voucherId: data })
})

// ------------------------------------------------------------ vouchers
gl.get('/vouchers', requirePriv('gl.vouchers.read'), async (c) => {
  let q = db(c.env).from('vouchers').select('*').eq('entity_id', c.get('entityId'))
    .order('voucher_date', { ascending: false }).limit(200)
  const from = c.req.query('from'); const to = c.req.query('to'); const source = c.req.query('source')
  if (from) q = q.gte('voucher_date', from)
  if (to) q = q.lte('voucher_date', to)
  if (source) q = q.eq('source_module', source)
  const { data, error } = await q
  if (error) return c.json({ error: error.message }, 500)
  return c.json(data)
})

gl.get('/vouchers/:id', requirePriv('gl.vouchers.read'), async (c) => {
  const sb = db(c.env)
  const [{ data: header, error }, { data: lines }] = await Promise.all([
    sb.from('vouchers').select('*').eq('id', c.req.param('id')).eq('entity_id', c.get('entityId')).single(),
    sb.from('voucher_lines').select('*, ledger_accounts(account_no, name)').eq('voucher_id', c.req.param('id')).order('line_no'),
  ])
  if (error) return c.json({ error: error.message }, 404)
  return c.json({ ...header, lines })
})

// ------------------------------------------------------------ reports
gl.get('/reports/trial-balance', requirePriv('gl.reports.read'), async (c) => {
  const from = c.req.query('from') ?? '2000-01-01'
  const to = c.req.query('to') ?? '2099-12-31'
  const { data, error } = await db(c.env).rpc('gl_trial_balance', { p_entity: c.get('entityId'), p_from: from, p_to: to })
  if (error) return c.json({ error: error.message }, 500)
  return c.json(data)
})

gl.get('/reports/ledger', requirePriv('gl.reports.read'), async (c) => {
  const account = c.req.query('account')
  if (!account) return c.json({ error: 'account query param required' }, 400)
  const from = c.req.query('from') ?? '2000-01-01'
  const to = c.req.query('to') ?? '2099-12-31'
  const { data, error } = await db(c.env).rpc('gl_ledger', { p_entity: c.get('entityId'), p_account: account, p_from: from, p_to: to })
  if (error) return c.json({ error: error.message }, 500)
  return c.json(data)
})
