import { Hono } from 'hono'
import { db } from '../db'
import { requirePriv } from '../privileges'
import type { Bindings, Variables } from '../index'

type Env = { Bindings: Bindings; Variables: Variables }

export const service = new Hono<Env>()

// Lines: item_id is nullable — manual lines (labour, misc) carry only a description
// and post as Service Revenue. GST-inclusive amounts, no discount column on service lines.
type LineIn = { itemId?: string | null; description?: string; qty: number; unitPrice: number; taxRate?: number }
const lineAmount = (l: LineIn) => Math.round(((l.qty || 0) * (l.unitPrice || 0)) * 100) / 100

const EDITABLE = ['received', 'wip']

// ------------------------------------------------------------ orders
service.get('/orders', requirePriv('service.orders.read'), async (c) => {
  let q = db(c.env).from('service_orders')
    .select('*, erp_customers(customer_no, name, phone), warehouses(warehouse_no, name)')
    .eq('entity_id', c.get('entityId'))
  const status = c.req.query('status')
  if (status) q = q.eq('status', status)
  const { data, error } = await q.order('created_at', { ascending: false }).limit(200)
  if (error) return c.json({ error: error.message }, 500)
  return c.json(data)
})

service.get('/orders/:id', requirePriv('service.orders.read'), async (c) => {
  const sb = db(c.env)
  const id = c.req.param('id')
  const [{ data: h, error }, { data: lines }, { data: log }] = await Promise.all([
    sb.from('service_orders').select('*, erp_customers(customer_no, name, phone), warehouses(warehouse_no, name)')
      .eq('id', id).eq('entity_id', c.get('entityId')).single(),
    sb.from('service_order_lines').select('*, items(item_no, name, item_type)').eq('service_order_id', id).order('line_no'),
    sb.from('service_workflow_log').select('*').eq('service_order_id', id).order('at'),
  ])
  if (error) return c.json({ error: error.message }, 404)
  return c.json({ ...h, lines, log })
})

service.post('/orders', requirePriv('service.orders.write'), async (c) => {
  const b = await c.req.json()
  const sb = db(c.env)
  if (!b.customerId) return c.json({ error: 'customerId required' }, 400)
  if (!b.warehouseId) return c.json({ error: 'warehouseId required (the store doing the work)' }, 400)
  const { data: no, error: seqErr } = await sb.rpc('allocate_number', { p_entity: c.get('entityId'), p_code: 'SVC' })
  if (seqErr) return c.json({ error: seqErr.message }, 400)
  const { data, error } = await sb.from('service_orders')
    .insert({
      entity_id: c.get('entityId'), service_order_no: no,
      customer_id: b.customerId, warehouse_id: b.warehouseId,
      device_brand: b.deviceBrand ?? null, device_model: b.deviceModel ?? null,
      imei: b.imei ?? null, complaint: b.complaint ?? null,
      created_by: c.get('user').id,
    })
    .select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data, 201)
})

// Replace the full line set while the order is still editable; header total recomputed (backbone rule 3).
service.put('/orders/:id/lines', requirePriv('service.orders.write'), async (c) => {
  const { lines } = await c.req.json() as { lines: LineIn[] }
  const sb = db(c.env)
  const id = c.req.param('id')
  const { data: h, error: hErr } = await sb.from('service_orders').select('status')
    .eq('id', id).eq('entity_id', c.get('entityId')).single()
  if (hErr) return c.json({ error: hErr.message }, 404)
  if (!EDITABLE.includes(h.status)) return c.json({ error: `order is ${h.status}, lines are editable only while received or wip` }, 400)
  const { error: delErr } = await sb.from('service_order_lines').delete().eq('service_order_id', id)
  if (delErr) return c.json({ error: delErr.message }, 400)
  if (lines.length) {
    const { error } = await sb.from('service_order_lines').insert(lines.map((l, i) => ({
      service_order_id: id, entity_id: c.get('entityId'), line_no: i + 1,
      item_id: l.itemId || null, description: l.description ?? null,
      qty: l.qty || 0, unit_price: l.unitPrice || 0,
      tax_rate: l.taxRate ?? 18, line_amount: lineAmount(l),
    })))
    if (error) return c.json({ error: error.message }, 400)
  }
  const total = lines.reduce((s, l) => s + lineAmount(l), 0)
  const { data, error } = await sb.from('service_orders')
    .update({ total_amount: Math.round(total * 100) / 100 })
    .eq('id', id).select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data)
})

// ------------------------------------------------------------ workflow transition (backbone rule 4: one Postgres transaction)
// received → wip → completed → delivered → closed (cancelled from received/wip); 'delivered' posts revenue + parts.
service.post('/orders/:id/transition', requirePriv('service.orders.transition'), async (c) => {
  const b = await c.req.json() as { to?: string; note?: string }
  if (!b.to) return c.json({ error: 'to required' }, 400)
  const sb = db(c.env)
  const id = c.req.param('id')
  // Entity guard: the RPC trusts its caller, so scope the order to the selected entity first.
  const { error: hErr } = await sb.from('service_orders').select('id')
    .eq('id', id).eq('entity_id', c.get('entityId')).single()
  if (hErr) return c.json({ error: hErr.message }, 404)
  const { error } = await sb.rpc('service_transition', {
    p_order: id, p_to: b.to, p_actor: c.get('user').id, p_note: b.note ?? null,
  })
  if (error) return c.json({ error: error.message }, 400)
  const { data } = await sb.from('service_orders').select('*').eq('id', id).single()
  return c.json(data)
})

// ------------------------------------------------------------ reports
// Open orders (not closed/cancelled) with age in days. Public status stays DB-side (service_public_status).
service.get('/reports/open', requirePriv('service.reports.read'), async (c) => {
  const { data, error } = await db(c.env).from('service_orders')
    .select('id, service_order_no, status, device_brand, device_model, total_amount, warehouse_id, created_at, erp_customers(customer_no, name)')
    .eq('entity_id', c.get('entityId'))
    .not('status', 'in', '(closed,cancelled)')
    .order('created_at', { ascending: true })
  if (error) return c.json({ error: error.message }, 500)
  const now = Date.now()
  return c.json((data ?? []).map((r) => ({
    ...r,
    age_days: Math.floor((now - new Date(r.created_at as string).getTime()) / 86400000),
  })))
})
