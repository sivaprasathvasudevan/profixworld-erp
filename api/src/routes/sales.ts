import { Hono } from 'hono'
import { db } from '../db'
import { requirePriv } from '../privileges'
import type { Bindings, Variables } from '../index'

type Env = { Bindings: Bindings; Variables: Variables }

export const sales = new Hono<Env>()

type LineIn = { itemId: string; description?: string; qty: number; unitPrice: number; discount?: number; taxRate?: number }
// GST-inclusive line amount (CGST/SGST split happens at display and posting time)
const lineAmount = (l: LineIn) => Math.round(((l.qty || 0) * (l.unitPrice || 0) - (l.discount || 0)) * 100) / 100

// ------------------------------------------------------------ customers
sales.get('/customers', requirePriv('sales.customers.read'), async (c) => {
  const { data, error } = await db(c.env).from('erp_customers').select('*')
    .eq('entity_id', c.get('entityId')).order('customer_no')
  if (error) return c.json({ error: error.message }, 500)
  return c.json(data)
})

sales.post('/customers', requirePriv('sales.customers.write'), async (c) => {
  const b = await c.req.json()
  const sb = db(c.env)
  const { data: no, error: seqErr } = await sb.rpc('allocate_number', { p_entity: c.get('entityId'), p_code: 'CUST' })
  if (seqErr) return c.json({ error: seqErr.message }, 400)
  const { data, error } = await sb.from('erp_customers')
    .insert({
      entity_id: c.get('entityId'), customer_no: no, name: b.name,
      phone: b.phone ?? null, email: b.email ?? null, gstin: b.gstin ?? null,
      billing_address: b.billingAddress ?? null, shipping_address: b.shippingAddress ?? null,
      credit_limit: b.creditLimit ?? 0,
    })
    .select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data, 201)
})

sales.patch('/customers/:id', requirePriv('sales.customers.write'), async (c) => {
  const b = await c.req.json()
  const { data, error } = await db(c.env).from('erp_customers')
    .update({ name: b.name, phone: b.phone, email: b.email, gstin: b.gstin, billing_address: b.billingAddress, shipping_address: b.shippingAddress, credit_limit: b.creditLimit, active: b.active })
    .eq('id', c.req.param('id')).eq('entity_id', c.get('entityId'))
    .select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data)
})

// Receivables ledger for one customer: voucher lines of vouchers sourced from this customer's invoices.
sales.get('/customers/:id/transactions', requirePriv('sales.customers.read'), async (c) => {
  const sb = db(c.env)
  const { data: invs, error: iErr } = await sb.from('sales_invoices').select('id')
    .eq('entity_id', c.get('entityId')).eq('customer_id', c.req.param('id'))
  if (iErr) return c.json({ error: iErr.message }, 500)
  const invoiceIds = (invs ?? []).map((i) => i.id)
  if (!invoiceIds.length) return c.json([])
  const { data: vouchers, error: vErr } = await sb.from('vouchers')
    .select('id, voucher_no, voucher_date, description')
    .eq('entity_id', c.get('entityId')).eq('source_module', 'sales').in('source_doc_id', invoiceIds)
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

// ------------------------------------------------------------ documents (quotation / order / invoice share the code path)
const docRoutes = (opts: {
  base: string; header: string; linesTable: string; fk: string;
  editableStatus: string; readPriv: string; writePriv: string;
}) => {
  const { base, header, linesTable, fk, editableStatus, readPriv, writePriv } = opts

  sales.get(base, requirePriv(readPriv), async (c) => {
    const { data, error } = await db(c.env).from(header).select('*, erp_customers(customer_no, name)')
      .eq('entity_id', c.get('entityId')).order('created_at', { ascending: false }).limit(100)
    if (error) return c.json({ error: error.message }, 500)
    return c.json(data)
  })

  sales.get(`${base}/:id`, requirePriv(readPriv), async (c) => {
    const sb = db(c.env)
    const [{ data: h, error }, { data: lines }] = await Promise.all([
      sb.from(header).select('*, erp_customers(customer_no, name)').eq('id', c.req.param('id')).eq('entity_id', c.get('entityId')).single(),
      sb.from(linesTable).select('*, items(item_no, name, item_type)').eq(fk, c.req.param('id')).order('line_no'),
    ])
    if (error) return c.json({ error: error.message }, 404)
    return c.json({ ...h, lines })
  })

  // Replace the full line set of an editable document; header total recomputed (backbone rule 3).
  sales.put(`${base}/:id/lines`, requirePriv(writePriv), async (c) => {
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

docRoutes({ base: '/quotations', header: 'sales_quotations', linesTable: 'sales_quotation_lines', fk: 'quotation_id', editableStatus: 'draft', readPriv: 'sales.quotations.read', writePriv: 'sales.quotations.write' })
docRoutes({ base: '/orders', header: 'sales_orders', linesTable: 'sales_order_lines', fk: 'order_id', editableStatus: 'open', readPriv: 'sales.orders.read', writePriv: 'sales.orders.write' })
docRoutes({ base: '/invoices', header: 'sales_invoices', linesTable: 'sales_invoice_lines', fk: 'invoice_id', editableStatus: 'draft', readPriv: 'sales.invoices.read', writePriv: 'sales.invoices.write' })

// ------------------------------------------------------------ quotations: create, approve, convert
sales.post('/quotations', requirePriv('sales.quotations.write'), async (c) => {
  const b = await c.req.json()
  const sb = db(c.env)
  if (!b.customerId) return c.json({ error: 'customerId required' }, 400)
  const { data: no, error: seqErr } = await sb.rpc('allocate_number', { p_entity: c.get('entityId'), p_code: 'SQ' })
  if (seqErr) return c.json({ error: seqErr.message }, 400)
  const { data, error } = await sb.from('sales_quotations')
    .insert({ entity_id: c.get('entityId'), quotation_no: no, quotation_date: b.quotationDate ?? new Date().toISOString().slice(0, 10), customer_id: b.customerId, created_by: c.get('user').id })
    .select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data, 201)
})

sales.post('/quotations/:id/approve', requirePriv('sales.quotations.approve'), async (c) => {
  const sb = db(c.env)
  const id = c.req.param('id')
  const { data: q, error: qErr } = await sb.from('sales_quotations').select('status').eq('id', id).eq('entity_id', c.get('entityId')).single()
  if (qErr) return c.json({ error: qErr.message }, 404)
  if (q.status !== 'draft') return c.json({ error: `quotation is ${q.status}, only draft can be approved` }, 400)
  const { data, error } = await sb.from('sales_quotations').update({ status: 'approved' }).eq('id', id).select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data)
})

sales.post('/quotations/:id/convert', requirePriv('sales.orders.write'), async (c) => {
  const { data, error } = await db(c.env).rpc('convert_quotation_to_order', { p_quotation: c.req.param('id'), p_actor: c.get('user').id })
  if (error) return c.json({ error: error.message }, 400)
  return c.json({ orderId: data })
})

// ------------------------------------------------------------ orders: create direct, create invoice
sales.post('/orders', requirePriv('sales.orders.write'), async (c) => {
  const b = await c.req.json()
  const sb = db(c.env)
  if (!b.customerId) return c.json({ error: 'customerId required' }, 400)
  const { data: no, error: seqErr } = await sb.rpc('allocate_number', { p_entity: c.get('entityId'), p_code: 'SO' })
  if (seqErr) return c.json({ error: seqErr.message }, 400)
  const { data, error } = await sb.from('sales_orders')
    .insert({ entity_id: c.get('entityId'), order_no: no, order_date: b.orderDate ?? new Date().toISOString().slice(0, 10), customer_id: b.customerId, warehouse_id: b.warehouseId ?? null, created_by: c.get('user').id })
    .select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data, 201)
})

// Create a draft invoice from an open order (copies header + lines; posting happens separately).
sales.post('/orders/:id/invoice', requirePriv('sales.invoices.write'), async (c) => {
  const b = await c.req.json().catch(() => ({} as { warehouseId?: string }))
  const sb = db(c.env)
  const id = c.req.param('id')
  const [{ data: o, error: oErr }, { data: oLines, error: lErr }] = await Promise.all([
    sb.from('sales_orders').select('*').eq('id', id).eq('entity_id', c.get('entityId')).single(),
    sb.from('sales_order_lines').select('*').eq('order_id', id).order('line_no'),
  ])
  if (oErr) return c.json({ error: oErr.message }, 404)
  if (lErr) return c.json({ error: lErr.message }, 400)
  if (o.status !== 'open') return c.json({ error: `order is ${o.status}, only open orders can be invoiced` }, 400)
  const warehouseId = b.warehouseId ?? o.warehouse_id
  if (!warehouseId) return c.json({ error: 'warehouseId required (in the body or on the order)' }, 400)
  const { data: no, error: seqErr } = await sb.rpc('allocate_number', { p_entity: c.get('entityId'), p_code: 'SINV' })
  if (seqErr) return c.json({ error: seqErr.message }, 400)
  const { data: inv, error: iErr } = await sb.from('sales_invoices')
    .insert({ entity_id: c.get('entityId'), invoice_no: no, invoice_date: new Date().toISOString().slice(0, 10), customer_id: o.customer_id, warehouse_id: warehouseId, order_id: o.id, total_amount: o.total_amount, created_by: c.get('user').id })
    .select().single()
  if (iErr) return c.json({ error: iErr.message }, 400)
  if (oLines?.length) {
    const { error } = await sb.from('sales_invoice_lines').insert(oLines.map((l) => ({
      invoice_id: inv.id, entity_id: c.get('entityId'), line_no: l.line_no,
      item_id: l.item_id, description: l.description, qty: l.qty, unit_price: l.unit_price,
      discount: l.discount, tax_rate: l.tax_rate, line_amount: l.line_amount,
    })))
    if (error) return c.json({ error: error.message }, 400)
  }
  return c.json(inv, 201)
})

// ------------------------------------------------------------ invoices: post (backbone rule 4, one Postgres transaction)
sales.post('/invoices/:id/post', requirePriv('sales.invoices.post'), async (c) => {
  const { data, error } = await db(c.env).rpc('post_sales_invoice', { p_invoice: c.req.param('id'), p_actor: c.get('user').id })
  if (error) return c.json({ error: error.message }, 400)
  return c.json({ voucherId: data })
})

// ------------------------------------------------------------ reports
sales.get('/reports/register', requirePriv('sales.reports.read'), async (c) => {
  const from = c.req.query('from') ?? '2000-01-01'
  const to = c.req.query('to') ?? '2099-12-31'
  const { data, error } = await db(c.env).rpc('sales_register', { p_entity: c.get('entityId'), p_from: from, p_to: to })
  if (error) return c.json({ error: error.message }, 500)
  return c.json(data)
})
