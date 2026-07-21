import { Hono } from 'hono'
import { db } from '../db'
import { requirePriv } from '../privileges'
import type { Bindings, Variables } from '../index'

type Env = { Bindings: Bindings; Variables: Variables }

export const inventory = new Hono<Env>()

// ------------------------------------------------------------ items
inventory.get('/items', requirePriv('inv.items.read'), async (c) => {
  const { data, error } = await db(c.env).from('items').select('*')
    .eq('entity_id', c.get('entityId')).order('item_no')
  if (error) return c.json({ error: error.message }, 500)
  return c.json(data)
})

inventory.post('/items', requirePriv('inv.items.write'), async (c) => {
  const b = await c.req.json()
  const sb = db(c.env)
  const { data: no, error: seqErr } = await sb.rpc('allocate_number', { p_entity: c.get('entityId'), p_code: 'ITEM' })
  if (seqErr) return c.json({ error: seqErr.message }, 400)
  const { data, error } = await sb.from('items')
    .insert({
      entity_id: c.get('entityId'), item_no: no, name: b.name,
      item_type: b.itemType ?? 'product', category: b.category ?? null, uom: b.uom || 'pcs',
      gst_rate: b.gstRate ?? 18, sales_price: b.salesPrice ?? 0, avg_cost: b.avgCost ?? 0,
    })
    .select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data, 201)
})

inventory.patch('/items/:id', requirePriv('inv.items.write'), async (c) => {
  const b = await c.req.json()
  const { data, error } = await db(c.env).from('items')
    .update({ name: b.name, item_type: b.itemType, category: b.category, uom: b.uom, gst_rate: b.gstRate, sales_price: b.salesPrice, avg_cost: b.avgCost, active: b.active })
    .eq('id', c.req.param('id')).eq('entity_id', c.get('entityId'))
    .select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data)
})

// ------------------------------------------------------------ item ↔ dimension attach/detach
inventory.get('/items/:id/dimensions', requirePriv('inv.dimensions.read'), async (c) => {
  const { data, error } = await db(c.env).from('item_dimensions')
    .select('dimension_value_id, dimension_values(id, value, dimension_types(code, name))')
    .eq('item_id', c.req.param('id'))
  if (error) return c.json({ error: error.message }, 500)
  return c.json(data)
})

inventory.post('/items/:id/dimensions', requirePriv('inv.items.write'), async (c) => {
  const b = await c.req.json()
  const { data, error } = await db(c.env).from('item_dimensions')
    .upsert({ item_id: c.req.param('id'), dimension_value_id: b.dimensionValueId })
    .select()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data, 201)
})

inventory.delete('/items/:id/dimensions/:valueId', requirePriv('inv.items.write'), async (c) => {
  const { error } = await db(c.env).from('item_dimensions')
    .delete().eq('item_id', c.req.param('id')).eq('dimension_value_id', c.req.param('valueId'))
  if (error) return c.json({ error: error.message }, 400)
  return c.json({ ok: true })
})

// ------------------------------------------------------------ dimension types & values
inventory.get('/dimensions/types', requirePriv('inv.dimensions.read'), async (c) => {
  const { data, error } = await db(c.env).from('dimension_types').select('*').order('code')
  if (error) return c.json({ error: error.message }, 500)
  return c.json(data)
})

inventory.post('/dimensions/types', requirePriv('inv.dimensions.write'), async (c) => {
  const b = await c.req.json()
  const { data, error } = await db(c.env).from('dimension_types')
    .insert({ code: b.code, name: b.name }).select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data, 201)
})

inventory.get('/dimensions/values', requirePriv('inv.dimensions.read'), async (c) => {
  let q = db(c.env).from('dimension_values').select('*, dimension_types(code, name)').order('value')
  const typeId = c.req.query('typeId')
  if (typeId) q = q.eq('type_id', typeId)
  const { data, error } = await q
  if (error) return c.json({ error: error.message }, 500)
  return c.json(data)
})

inventory.post('/dimensions/values', requirePriv('inv.dimensions.write'), async (c) => {
  const b = await c.req.json()
  const { data, error } = await db(c.env).from('dimension_values')
    .insert({ type_id: b.typeId, value: b.value }).select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data, 201)
})

// ------------------------------------------------------------ warehouses
inventory.get('/warehouses', requirePriv('inv.warehouses.read'), async (c) => {
  const { data, error } = await db(c.env).from('warehouses').select('*, branches(branch_no, name)')
    .eq('entity_id', c.get('entityId')).order('warehouse_no')
  if (error) return c.json({ error: error.message }, 500)
  return c.json(data)
})

inventory.post('/warehouses', requirePriv('inv.warehouses.write'), async (c) => {
  const b = await c.req.json()
  const { data, error } = await db(c.env).from('warehouses')
    .insert({ entity_id: c.get('entityId'), warehouse_no: b.warehouseNo, name: b.name, branch_id: b.branchId ?? null, is_store: b.isStore ?? true })
    .select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data, 201)
})

inventory.patch('/warehouses/:id', requirePriv('inv.warehouses.write'), async (c) => {
  const b = await c.req.json()
  const { data, error } = await db(c.env).from('warehouses')
    .update({ name: b.name, branch_id: b.branchId, is_store: b.isStore, active: b.active })
    .eq('id', c.req.param('id')).eq('entity_id', c.get('entityId'))
    .select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data)
})

// ------------------------------------------------------------ on-hand
inventory.get('/onhand', requirePriv('inv.onhand.read'), async (c) => {
  const { data, error } = await db(c.env).rpc('inv_on_hand', { p_entity: c.get('entityId') })
  if (error) return c.json({ error: error.message }, 500)
  return c.json(data)
})

// ------------------------------------------------------------ journals (transfer + movement share the code path)
const journalRoutes = (
  kind: 'transfer' | 'movement',
  header: string, linesTable: string, seq: string, postFn: string,
) => {
  const base = `/${kind}s`

  inventory.get(base, requirePriv('inv.journals.read'), async (c) => {
    const { data, error } = await db(c.env).from(header).select('*')
      .eq('entity_id', c.get('entityId')).order('created_at', { ascending: false }).limit(100)
    if (error) return c.json({ error: error.message }, 500)
    return c.json(data)
  })

  inventory.get(`${base}/:id`, requirePriv('inv.journals.read'), async (c) => {
    const sb = db(c.env)
    const [{ data: h, error }, { data: lines }] = await Promise.all([
      sb.from(header).select('*').eq('id', c.req.param('id')).eq('entity_id', c.get('entityId')).single(),
      sb.from(linesTable).select('*').eq('journal_id', c.req.param('id')).order('line_no'),
    ])
    if (error) return c.json({ error: error.message }, 404)
    return c.json({ ...h, lines })
  })

  inventory.post(base, requirePriv('inv.journals.write'), async (c) => {
    const b = await c.req.json()
    const sb = db(c.env)
    const { data: no, error: seqErr } = await sb.rpc('allocate_number', { p_entity: c.get('entityId'), p_code: seq })
    if (seqErr) return c.json({ error: seqErr.message }, 400)
    const row: Record<string, unknown> = {
      entity_id: c.get('entityId'), journal_no: no,
      journal_date: b.journalDate ?? new Date().toISOString().slice(0, 10),
      description: b.description ?? null, created_by: c.get('user').id,
    }
    if (kind === 'transfer') {
      row.from_warehouse_id = b.fromWarehouseId ?? null
      row.to_warehouse_id = b.toWarehouseId ?? null
    }
    const { data, error } = await sb.from(header).insert(row).select().single()
    if (error) return c.json({ error: error.message }, 400)
    return c.json(data, 201)
  })

  // Replace the full line set of a draft journal; header totals recomputed (backbone rule 3).
  inventory.put(`${base}/:id/lines`, requirePriv('inv.journals.write'), async (c) => {
    const { lines } = await c.req.json() as { lines: { itemId: string; qty: number; warehouseId?: string; reason?: string }[] }
    const sb = db(c.env)
    const id = c.req.param('id')
    const { data: j, error: jErr } = await sb.from(header).select('status').eq('id', id).eq('entity_id', c.get('entityId')).single()
    if (jErr) return c.json({ error: jErr.message }, 404)
    if (j.status !== 'draft') return c.json({ error: 'only draft journals can be edited' }, 400)
    const { error: delErr } = await sb.from(linesTable).delete().eq('journal_id', id)
    if (delErr) return c.json({ error: delErr.message }, 400)
    if (lines.length) {
      const { error } = await sb.from(linesTable).insert(lines.map((l, i) => ({
        journal_id: id, entity_id: c.get('entityId'), line_no: i + 1,
        item_id: l.itemId, qty: l.qty || 0,
        ...(kind === 'movement' ? { warehouse_id: l.warehouseId, reason: l.reason ?? null } : {}),
      })))
      if (error) return c.json({ error: error.message }, 400)
    }
    const total = lines.reduce((s, l) => s + (l.qty || 0), 0)
    const { data, error } = await sb.from(header)
      .update({ total_qty: Math.round(total * 1000) / 1000 })
      .eq('id', id).select().single()
    if (error) return c.json({ error: error.message }, 400)
    return c.json(data)
  })

  inventory.post(`${base}/:id/post`, requirePriv('inv.journals.post'), async (c) => {
    const { data, error } = await db(c.env).rpc(postFn, { p_journal: c.req.param('id'), p_actor: c.get('user').id })
    if (error) return c.json({ error: error.message }, 400)
    return c.json({ journalId: data })
  })
}

journalRoutes('transfer', 'transfer_journals', 'transfer_journal_lines', 'TRJ', 'post_transfer_journal')
journalRoutes('movement', 'movement_journals', 'movement_journal_lines', 'MVJ', 'post_movement_journal')
