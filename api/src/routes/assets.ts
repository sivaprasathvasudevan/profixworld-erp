import { Hono } from 'hono'
import { db } from '../db'
import { requirePriv } from '../privileges'
import type { Bindings, Variables } from '../index'

type Env = { Bindings: Bindings; Variables: Variables }

export const assets = new Hono<Env>()

const r2 = (n: number) => Math.round(n * 100) / 100

type AssetRow = {
  cost: number | string; salvage_value: number | string; accumulated_depreciation: number | string
  method: string; rate_percent: number | string; useful_life_months: number
}

/**
 * Depreciation schedule preview — mirrors public.generate_depreciation in
 * db/supabase/migrations/00000000000009_assets_dms.sql and computeDepreciationMonth in
 * packages/shared (keep the three in sync): project monthly amounts from the asset's
 * current accumulated depreciation until fully depreciated, max 120 rows.
 */
function schedulePreview(a: AssetRow) {
  const cost = Number(a.cost)
  const base = r2(cost - Number(a.salvage_value)) // depreciable base
  let accum = Number(a.accumulated_depreciation)
  const rows: { monthNo: number; amount: number; accumulatedAfter: number; bookValueAfter: number }[] = []
  for (let m = 1; m <= 120 && accum < base - 0.005; m++) {
    let amount = a.method === 'straight_line'
      ? r2(base / Math.max(a.useful_life_months, 1))
      : r2((cost - accum) * (Number(a.rate_percent) / 100) / 12)
    if (accum + amount > base) amount = r2(base - accum)
    if (amount <= 0) break
    accum = r2(accum + amount)
    rows.push({ monthNo: m, amount, accumulatedAfter: accum, bookValueAfter: r2(cost - accum) })
  }
  return rows
}

// ------------------------------------------------------------ asset register (CRUD)
assets.get('/assets', requirePriv('assets.assets.read'), async (c) => {
  const { data, error } = await db(c.env).from('assets').select('*')
    .eq('entity_id', c.get('entityId')).order('asset_no')
  if (error) return c.json({ error: error.message }, 500)
  return c.json(data)
})

// Assets are created standalone or referencing a purchase invoice; acquisition posting is a
// deliberate non-goal for now (the purchase invoice already posted the spend).
assets.post('/assets', requirePriv('assets.assets.write'), async (c) => {
  const b = await c.req.json()
  if (!b.name) return c.json({ error: 'name required' }, 400)
  const cost = r2(Number(b.cost ?? 0))
  if (!(cost >= 0)) return c.json({ error: 'cost must be >= 0' }, 400)
  const method = b.method ?? 'straight_line'
  if (!['straight_line', 'wdv'].includes(method)) return c.json({ error: "method must be 'straight_line' or 'wdv'" }, 400)
  const sb = db(c.env)
  const { data: no, error: seqErr } = await sb.rpc('allocate_number', { p_entity: c.get('entityId'), p_code: 'AST' })
  if (seqErr) return c.json({ error: seqErr.message }, 400)
  const { data, error } = await sb.from('assets')
    .insert({
      entity_id: c.get('entityId'), asset_no: no, name: b.name, category: b.category ?? null,
      acquisition_date: b.acquisitionDate ?? new Date().toISOString().slice(0, 10), cost,
      method, rate_percent: b.ratePercent ?? 15, useful_life_months: b.usefulLifeMonths ?? 60,
      salvage_value: b.salvageValue ?? 0, purchase_invoice_id: b.purchaseInvoiceId ?? null,
    })
    .select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data, 201)
})

assets.get('/assets/:id', requirePriv('assets.assets.read'), async (c) => {
  const { data, error } = await db(c.env).from('assets').select('*')
    .eq('id', c.req.param('id')).eq('entity_id', c.get('entityId')).single()
  if (error) return c.json({ error: error.message }, 404)
  return c.json({ ...data, book_value: r2(Number(data.cost) - Number(data.accumulated_depreciation)), schedule: schedulePreview(data) })
})

// Active assets only; financial parameters stay editable (they only affect future runs).
assets.patch('/assets/:id', requirePriv('assets.assets.write'), async (c) => {
  const b = await c.req.json()
  const sb = db(c.env)
  const { data: a, error: aErr } = await sb.from('assets').select('status')
    .eq('id', c.req.param('id')).eq('entity_id', c.get('entityId')).single()
  if (aErr) return c.json({ error: aErr.message }, 404)
  if (a.status !== 'active') return c.json({ error: `asset is ${a.status}, only active assets can be edited` }, 400)
  const patch: Record<string, unknown> = {}
  if (b.name !== undefined) patch.name = b.name
  if (b.category !== undefined) patch.category = b.category
  if (b.method !== undefined) patch.method = b.method
  if (b.ratePercent !== undefined) patch.rate_percent = b.ratePercent
  if (b.usefulLifeMonths !== undefined) patch.useful_life_months = b.usefulLifeMonths
  if (b.salvageValue !== undefined) patch.salvage_value = b.salvageValue
  const { data, error } = await sb.from('assets').update(patch)
    .eq('id', c.req.param('id')).select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data)
})

// Disposal posts cash/gain/loss in one Postgres transaction (backbone rule 4).
assets.post('/assets/:id/dispose', requirePriv('assets.assets.write'), async (c) => {
  const b = await c.req.json()
  const proceeds = Number(b.proceeds ?? 0)
  if (!(proceeds >= 0)) return c.json({ error: 'proceeds must be >= 0' }, 400)
  const sb = db(c.env)
  const { data: a, error: aErr } = await sb.from('assets').select('id')
    .eq('id', c.req.param('id')).eq('entity_id', c.get('entityId')).single()
  if (aErr) return c.json({ error: aErr.message }, 404)
  const { data, error } = await sb.rpc('dispose_asset', { p_asset: a.id, p_proceeds: proceeds, p_actor: c.get('user').id })
  if (error) return c.json({ error: error.message }, 400)
  return c.json({ voucherId: data })
})

// ------------------------------------------------------------ depreciation runs
assets.get('/runs', requirePriv('assets.depreciation.read'), async (c) => {
  const { data, error } = await db(c.env).from('depreciation_runs').select('*')
    .eq('entity_id', c.get('entityId')).order('period_code', { ascending: false })
  if (error) return c.json({ error: error.message }, 500)
  return c.json(data)
})

assets.post('/runs', requirePriv('assets.depreciation.write'), async (c) => {
  const b = await c.req.json()
  if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(b.periodCode ?? '')) {
    return c.json({ error: 'periodCode must look like 2026-07' }, 400)
  }
  const { data, error } = await db(c.env).from('depreciation_runs')
    .insert({ entity_id: c.get('entityId'), period_code: b.periodCode, created_by: c.get('user').id })
    .select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data, 201)
})

assets.get('/runs/:id', requirePriv('assets.depreciation.read'), async (c) => {
  const sb = db(c.env)
  const [{ data: run, error }, { data: lines, error: lErr }] = await Promise.all([
    sb.from('depreciation_runs').select('*').eq('id', c.req.param('id')).eq('entity_id', c.get('entityId')).single(),
    sb.from('depreciation_lines').select('*, assets(asset_no, name)').eq('run_id', c.req.param('id')),
  ])
  if (error) return c.json({ error: error.message }, 404)
  if (lErr) return c.json({ error: lErr.message }, 500)
  const sorted = (lines ?? []).sort((a, b) =>
    String(a.assets?.asset_no ?? '').localeCompare(String(b.assets?.asset_no ?? '')))
  return c.json({ ...run, lines: sorted })
})

// Regenerate draft lines (SQL function, one transaction).
assets.post('/runs/:id/generate', requirePriv('assets.depreciation.write'), async (c) => {
  const sb = db(c.env)
  const { data: run, error: rErr } = await sb.from('depreciation_runs').select('id')
    .eq('id', c.req.param('id')).eq('entity_id', c.get('entityId')).single()
  if (rErr) return c.json({ error: rErr.message }, 404)
  const { data, error } = await sb.rpc('generate_depreciation', { p_run: run.id, p_actor: c.get('user').id })
  if (error) return c.json({ error: error.message }, 400)
  return c.json({ lines: data })
})

// Post to GL (backbone rule 4; drafts post directly — no approve step for depreciation).
assets.post('/runs/:id/post', requirePriv('assets.depreciation.post'), async (c) => {
  const sb = db(c.env)
  const { data: run, error: rErr } = await sb.from('depreciation_runs').select('id')
    .eq('id', c.req.param('id')).eq('entity_id', c.get('entityId')).single()
  if (rErr) return c.json({ error: rErr.message }, 404)
  const { data, error } = await sb.rpc('post_depreciation', { p_run: run.id, p_actor: c.get('user').id })
  if (error) return c.json({ error: error.message }, 400)
  return c.json({ voucherId: data })
})

// ------------------------------------------------------------ reports
assets.get('/reports/register', requirePriv('assets.reports.read'), async (c) => {
  const { data, error } = await db(c.env).from('assets').select('*')
    .eq('entity_id', c.get('entityId')).order('asset_no')
  if (error) return c.json({ error: error.message }, 500)
  return c.json((data ?? []).map((a) => ({
    ...a, book_value: r2(Number(a.cost) - Number(a.accumulated_depreciation)),
  })))
})
