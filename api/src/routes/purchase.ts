import { Hono } from 'hono'
import { db } from '../db'
import { requirePriv } from '../privileges'
import type { Bindings, Variables } from '../index'

type Env = { Bindings: Bindings; Variables: Variables }

export const purchase = new Hono<Env>()

type LineIn = { itemId: string; description?: string; qty: number; unitPrice: number; discount?: number; taxRate?: number }
// GST-inclusive line amount (taxable/GST-input split happens at display and posting time)
const lineAmount = (l: LineIn) => Math.round(((l.qty || 0) * (l.unitPrice || 0) - (l.discount || 0)) * 100) / 100

// ------------------------------------------------------------ vendors
purchase.get('/vendors', requirePriv('purchase.vendors.read'), async (c) => {
  const { data, error } = await db(c.env).from('vendors').select('*')
    .eq('entity_id', c.get('entityId')).order('vendor_no')
  if (error) return c.json({ error: error.message }, 500)
  return c.json(data)
})

purchase.post('/vendors', requirePriv('purchase.vendors.write'), async (c) => {
  const b = await c.req.json()
  const sb = db(c.env)
  const { data: no, error: seqErr } = await sb.rpc('allocate_number', { p_entity: c.get('entityId'), p_code: 'VEND' })
  if (seqErr) return c.json({ error: seqErr.message }, 400)
  const { data, error } = await sb.from('vendors')
    .insert({
      entity_id: c.get('entityId'), vendor_no: no, name: b.name,
      phone: b.phone ?? null, email: b.email ?? null, gstin: b.gstin ?? null,
      address: b.address ?? null, bank_details: b.bankDetails ?? null,
    })
    .select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data, 201)
})

purchase.patch('/vendors/:id', requirePriv('purchase.vendors.write'), async (c) => {
  const b = await c.req.json()
  const { data, error } = await db(c.env).from('vendors')
    .update({ name: b.name, phone: b.phone, email: b.email, gstin: b.gstin, address: b.address, bank_details: b.bankDetails, active: b.active })
    .eq('id', c.req.param('id')).eq('entity_id', c.get('entityId'))
    .select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data)
})

// Payables ledger for one vendor: voucher lines of vouchers sourced from this vendor's purchase invoices.
purchase.get('/vendors/:id/transactions', requirePriv('purchase.vendors.read'), async (c) => {
  const sb = db(c.env)
  const { data: invs, error: iErr } = await sb.from('purchase_invoices').select('id')
    .eq('entity_id', c.get('entityId')).eq('vendor_id', c.req.param('id'))
  if (iErr) return c.json({ error: iErr.message }, 500)
  const invoiceIds = (invs ?? []).map((i) => i.id)
  if (!invoiceIds.length) return c.json([])
  const { data: vouchers, error: vErr } = await sb.from('vouchers')
    .select('id, voucher_no, voucher_date, description')
    .eq('entity_id', c.get('entityId')).eq('source_module', 'purchase').in('source_doc_id', invoiceIds)
    .order('voucher_date', { ascending: false })
  if (vErr) return c.json({ error: vErr.message }, 500)
  if (!vouchers?.length) return c.json([])
  const { data: lines, error: lErr } = await sb.from('voucher_lines')
    .select('voucher_id, line_no, debit, credit, memo, ledger_accounts(account_no, name)')
    .in('voucher_id', vouchers.map((v) => v.id))
  if (lErr) return c.json({ error: lErr.message }, 500)
  const vmap = new Map(vouchers.map((v) => [v.id, v]))
  return c.json((lines ?? []).map((l) => ({ ...l, voucher: vmap.get(l.voucher_id) ?? null })))
})

// ------------------------------------------------------------ documents (PO / GRN / invoice share the code path)
const docRoutes = (opts: {
  base: string; header: string; linesTable: string; fk: string;
  editableStatus: string; readPriv: string; writePriv: string;
}) => {
  const { base, header, linesTable, fk, editableStatus, readPriv, writePriv } = opts

  purchase.get(base, requirePriv(readPriv), async (c) => {
    const { data, error } = await db(c.env).from(header).select('*, vendors(vendor_no, name)')
      .eq('entity_id', c.get('entityId')).order('created_at', { ascending: false }).limit(100)
    if (error) return c.json({ error: error.message }, 500)
    return c.json(data)
  })

  purchase.get(`${base}/:id`, requirePriv(readPriv), async (c) => {
    const sb = db(c.env)
    const [{ data: h, error }, { data: lines }] = await Promise.all([
      sb.from(header).select('*, vendors(vendor_no, name)').eq('id', c.req.param('id')).eq('entity_id', c.get('entityId')).single(),
      sb.from(linesTable).select('*, items(item_no, name, item_type)').eq(fk, c.req.param('id')).order('line_no'),
    ])
    if (error) return c.json({ error: error.message }, 404)
    return c.json({ ...h, lines })
  })

  // Replace the full line set of an editable document; header total recomputed (backbone rule 3).
  purchase.put(`${base}/:id/lines`, requirePriv(writePriv), async (c) => {
    const { lines } = await c.req.json() as { lines: LineIn[] }
    const sb = db(c.env)
    const id = c.req.param('id')
    const { data: h, error: hErr } = await sb.from(header).select('status').eq('id', id).eq('entity_id', c.get('entityId')).single()
    if (hErr) return c.json({ error: hErr.message }, 404)
    if (h.status !== editableStatus) return c.json({ error: `only ${editableStatus} documents can be edited` }, 400)
    const { error: delErr } = await sb.from(linesTable).delete().eq(fk, id)
    if (delErr) return c.json({ error: delErr.message }, 400)
    if (lines.length) {
      const { error } = await sb.from(linesTable).insert(lines.map((l, i) => ({
        [fk]: id, entity_id: c.get('entityId'), line_no: i + 1,
        item_id: l.itemId, description: l.description ?? null,
        qty: l.qty || 0, unit_price: l.unitPrice || 0, discount: l.discount || 0,
        tax_rate: l.taxRate ?? 18, line_amount: lineAmount(l),
      })))
      if (error) return c.json({ error: error.message }, 400)
    }
    const total = lines.reduce((s, l) => s + lineAmount(l), 0)
    const { data, error } = await sb.from(header)
      .update({ total_amount: Math.round(total * 100) / 100 })
      .eq('id', id).select().single()
    if (error) return c.json({ error: error.message }, 400)
    return c.json(data)
  })
}

docRoutes({ base: '/orders', header: 'purchase_orders', linesTable: 'purchase_order_lines', fk: 'order_id', editableStatus: 'draft', readPriv: 'purchase.orders.read', writePriv: 'purchase.orders.write' })
docRoutes({ base: '/grns', header: 'goods_receipts', linesTable: 'goods_receipt_lines', fk: 'grn_id', editableStatus: 'draft', readPriv: 'purchase.grn.read', writePriv: 'purchase.grn.write' })
docRoutes({ base: '/invoices', header: 'purchase_invoices', linesTable: 'purchase_invoice_lines', fk: 'invoice_id', editableStatus: 'draft', readPriv: 'purchase.invoices.read', writePriv: 'purchase.invoices.write' })

// ------------------------------------------------------------ purchase orders: create, approve
purchase.post('/orders', requirePriv('purchase.orders.write'), async (c) => {
  const b = await c.req.json()
  const sb = db(c.env)
  if (!b.vendorId) return c.json({ error: 'vendorId required' }, 400)
  const { data: no, error: seqErr } = await sb.rpc('allocate_number', { p_entity: c.get('entityId'), p_code: 'PO' })
  if (seqErr) return c.json({ error: seqErr.message }, 400)
  const { data, error } = await sb.from('purchase_orders')
    .insert({ entity_id: c.get('entityId'), order_no: no, order_date: b.orderDate ?? new Date().toISOString().slice(0, 10), vendor_id: b.vendorId, warehouse_id: b.warehouseId ?? null, created_by: c.get('user').id })
    .select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data, 201)
})

purchase.post('/orders/:id/approve', requirePriv('purchase.orders.approve'), async (c) => {
  const sb = db(c.env)
  const id = c.req.param('id')
  const { data: o, error: oErr } = await sb.from('purchase_orders').select('status').eq('id', id).eq('entity_id', c.get('entityId')).single()
  if (oErr) return c.json({ error: oErr.message }, 404)
  if (o.status !== 'draft') return c.json({ error: `purchase order is ${o.status}, only draft can be approved` }, 400)
  const { data, error } = await sb.from('purchase_orders').update({ status: 'approved' }).eq('id', id).select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data)
})

// ------------------------------------------------------------ receive: create a draft GRN from an approved PO
purchase.post('/orders/:id/receive', requirePriv('purchase.grn.write'), async (c) => {
  const b = await c.req.json().catch(() => ({} as { warehouseId?: string }))
  const sb = db(c.env)
  const id = c.req.param('id')
  const [{ data: o, error: oErr }, { data: oLines, error: lErr }] = await Promise.all([
    sb.from('purchase_orders').select('*').eq('id', id).eq('entity_id', c.get('entityId')).single(),
    sb.from('purchase_order_lines').select('*').eq('order_id', id).order('line_no'),
  ])
  if (oErr) return c.json({ error: oErr.message }, 404)
  if (lErr) return c.json({ error: lErr.message }, 400)
  if (o.status !== 'approved' && o.status !== 'received') return c.json({ error: `purchase order is ${o.status}, only approved orders can be received` }, 400)
  const warehouseId = b.warehouseId ?? o.warehouse_id
  if (!warehouseId) return c.json({ error: 'warehouseId required (in the body or on the order)' }, 400)
  const { data: no, error: seqErr } = await sb.rpc('allocate_number', { p_entity: c.get('entityId'), p_code: 'GRN' })
  if (seqErr) return c.json({ error: seqErr.message }, 400)
  const { data: grn, error: gErr } = await sb.from('goods_receipts')
    .insert({ entity_id: c.get('entityId'), grn_no: no, grn_date: new Date().toISOString().slice(0, 10), vendor_id: o.vendor_id, purchase_order_id: o.id, warehouse_id: warehouseId, total_amount: o.total_amount, created_by: c.get('user').id })
    .select().single()
  if (gErr) return c.json({ error: gErr.message }, 400)
  if (oLines?.length) {
    const { error } = await sb.from('goods_receipt_lines').insert(oLines.map((l) => ({
      grn_id: grn.id, entity_id: c.get('entityId'), line_no: l.line_no,
      item_id: l.item_id, description: l.description, qty: l.qty, unit_price: l.unit_price,
      discount: l.discount, tax_rate: l.tax_rate, line_amount: l.line_amount,
    })))
    if (error) return c.json({ error: error.message }, 400)
  }
  return c.json(grn, 201)
})

// ------------------------------------------------------------ invoice: create a draft purchase invoice from a PO
purchase.post('/orders/:id/invoice', requirePriv('purchase.invoices.write'), async (c) => {
  const b = await c.req.json().catch(() => ({} as { goodsReceiptId?: string }))
  const sb = db(c.env)
  const id = c.req.param('id')
  const [{ data: o, error: oErr }, { data: oLines, error: lErr }] = await Promise.all([
    sb.from('purchase_orders').select('*').eq('id', id).eq('entity_id', c.get('entityId')).single(),
    sb.from('purchase_order_lines').select('*').eq('order_id', id).order('line_no'),
  ])
  if (oErr) return c.json({ error: oErr.message }, 404)
  if (lErr) return c.json({ error: lErr.message }, 400)
  if (o.status !== 'approved' && o.status !== 'received') return c.json({ error: `purchase order is ${o.status}, only approved/received orders can be invoiced` }, 400)
  const { data: no, error: seqErr } = await sb.rpc('allocate_number', { p_entity: c.get('entityId'), p_code: 'PINV' })
  if (seqErr) return c.json({ error: seqErr.message }, 400)
  const { data: inv, error: iErr } = await sb.from('purchase_invoices')
    .insert({ entity_id: c.get('entityId'), invoice_no: no, invoice_date: new Date().toISOString().slice(0, 10), vendor_id: o.vendor_id, purchase_order_id: o.id, goods_receipt_id: b.goodsReceiptId ?? null, total_amount: o.total_amount, created_by: c.get('user').id })
    .select().single()
  if (iErr) return c.json({ error: iErr.message }, 400)
  if (oLines?.length) {
    const { error } = await sb.from('purchase_invoice_lines').insert(oLines.map((l) => ({
      invoice_id: inv.id, entity_id: c.get('entityId'), line_no: l.line_no,
      item_id: l.item_id, description: l.description, qty: l.qty, unit_price: l.unit_price,
      discount: l.discount, tax_rate: l.tax_rate, line_amount: l.line_amount,
    })))
    if (error) return c.json({ error: error.message }, 400)
  }
  return c.json(inv, 201)
})

// ------------------------------------------------------------ posting (backbone rule 4, one Postgres transaction each)
purchase.post('/grns/:id/post', requirePriv('purchase.grn.post'), async (c) => {
  const { data, error } = await db(c.env).rpc('post_goods_receipt', { p_grn: c.req.param('id'), p_actor: c.get('user').id })
  if (error) return c.json({ error: error.message }, 400)
  return c.json({ grnId: data })
})

purchase.post('/invoices/:id/post', requirePriv('purchase.invoices.post'), async (c) => {
  const { data, error } = await db(c.env).rpc('post_purchase_invoice', { p_invoice: c.req.param('id'), p_actor: c.get('user').id })
  if (error) return c.json({ error: error.message }, 400)
  return c.json({ voucherId: data })
})

// ------------------------------------------------------------ reports
purchase.get('/reports/register', requirePriv('purchase.reports.read'), async (c) => {
  const from = c.req.query('from') ?? '2000-01-01'
  const to = c.req.query('to') ?? '2099-12-31'
  const { data, error } = await db(c.env).rpc('purchase_register', { p_entity: c.get('entityId'), p_from: from, p_to: to })
  if (error) return c.json({ error: error.message }, 500)
  return c.json(data)
})
