import { useEffect, useState } from 'react'
import { api } from '../lib/api'

type Customer = { id: string; customer_no: string; name: string; phone?: string; email?: string; gstin?: string; billing_address?: string; shipping_address?: string; credit_points: number; credit_limit: number; active: boolean }
type Item = { id: string; item_no: string; name: string; item_type: string; gst_rate: number; sales_price: number }
type Warehouse = { id: string; warehouse_no: string; name: string }
type Doc = {
  id: string; status: string; total_amount: number; customer_id: string
  erp_customers?: { customer_no: string; name: string }
  quotation_no?: string; quotation_date?: string
  order_no?: string; order_date?: string; warehouse_id?: string; quotation_id?: string
  invoice_no?: string; invoice_date?: string; order_id?: string; voucher_id?: string; posted?: boolean
}
type DLine = { itemId: string; description?: string; qty: number; unitPrice: number; discount: number; taxRate: number }
type SrvLine = { line_no?: number; item_id: string; description?: string; qty: number; unit_price: number; discount: number; tax_rate: number; line_amount: number; items?: { item_no: string; name: string; item_type: string } }
type TxnRow = { voucher_id: string; line_no: number; debit: number; credit: number; memo?: string; ledger_accounts?: { account_no: string; name: string }; voucher?: { voucher_no: string; voucher_date: string; description?: string } | null }
type RegRow = { invoice_no: string; invoice_date: string; customer_no: string; customer_name: string; total: number; taxable: number; tax: number; status: string }

const TABS = ['Customers', 'Quotations', 'Sales orders', 'Invoices', 'Customer transactions', 'Reports'] as const
const box: React.CSSProperties = { border: '1px solid #e2e8f0', borderRadius: 8, padding: 16, marginBottom: 16 }
const th: React.CSSProperties = { textAlign: 'left', padding: '6px 10px', background: '#f1f5f9', fontSize: 13 }
const td: React.CSSProperties = { padding: '6px 10px', borderTop: '1px solid #e2e8f0', fontSize: 13 }
const num: React.CSSProperties = { ...td, textAlign: 'right', fontVariantNumeric: 'tabular-nums' }
const inp: React.CSSProperties = { padding: '6px 8px', border: '1px solid #cbd5e1', borderRadius: 6, fontSize: 13 }
const btn: React.CSSProperties = { padding: '6px 12px', border: 0, borderRadius: 6, background: '#0b1320', color: '#fff', cursor: 'pointer', fontSize: 13 }
const fmt = (n: number) => Number(n ?? 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })
const fmtQty = (n: number) => Number(n ?? 0).toLocaleString('en-IN', { maximumFractionDigits: 3 })
const lineAmt = (l: DLine) => Math.round(((l.qty || 0) * (l.unitPrice || 0) - (l.discount || 0)) * 100) / 100

function downloadCsv(name: string, headers: string[], rows: (string | number)[][]) {
  const esc = (v: string | number) => `"${String(v ?? '').replace(/"/g, '""')}"`
  const csv = [headers.map(esc).join(','), ...rows.map((r) => r.map(esc).join(','))].join('\n')
  const a = document.createElement('a')
  a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv' }))
  a.download = `${name}.csv`
  a.click()
}

export function Sales({ entityId }: { entityId: string }) {
  const [tab, setTab] = useState<(typeof TABS)[number]>('Customers')
  const [err, setErr] = useState('')
  return (
    <div>
      <div style={{ display: 'flex', gap: 8, marginBottom: 16, flexWrap: 'wrap' }}>
        {TABS.map((t) => (
          <button key={t} onClick={() => { setTab(t); setErr('') }}
            style={{ ...btn, background: tab === t ? '#0b1320' : '#e2e8f0', color: tab === t ? '#fff' : '#334155' }}>{t}</button>
        ))}
      </div>
      {err && <div style={{ color: '#b91c1c', marginBottom: 12, fontSize: 13 }}>{err}</div>}
      {tab === 'Customers' && <Customers entityId={entityId} setErr={setErr} />}
      {tab === 'Quotations' && <Quotations entityId={entityId} setErr={setErr} />}
      {tab === 'Sales orders' && <Orders entityId={entityId} setErr={setErr} />}
      {tab === 'Invoices' && <Invoices entityId={entityId} setErr={setErr} />}
      {tab === 'Customer transactions' && <Transactions entityId={entityId} setErr={setErr} />}
      {tab === 'Reports' && <Reports entityId={entityId} setErr={setErr} />}
    </div>
  )
}

function Customers({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [rows, setRows] = useState<Customer[]>([])
  const [form, setForm] = useState({ name: '', phone: '', email: '', gstin: '', billingAddress: '', shippingAddress: '', creditLimit: 0 })
  const load = () => api<Customer[]>('/sales/customers', { entityId }).then(setRows).catch((e) => setErr(e.message))
  useEffect(() => { load() }, [entityId])
  return (
    <div>
      <div style={box}>
        <b style={{ fontSize: 14 }}>New customer (customer no is allocated automatically)</b>
        <div style={{ display: 'flex', gap: 8, marginTop: 10, flexWrap: 'wrap' }}>
          <input style={{ ...inp, flex: 1, minWidth: 160 }} placeholder="Name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
          <input style={inp} placeholder="Phone" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} />
          <input style={inp} placeholder="Email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} />
          <input style={inp} placeholder="GSTIN" value={form.gstin} onChange={(e) => setForm({ ...form, gstin: e.target.value })} />
          <input style={{ ...inp, minWidth: 180 }} placeholder="Billing address" value={form.billingAddress} onChange={(e) => setForm({ ...form, billingAddress: e.target.value })} />
          <input style={{ ...inp, minWidth: 180 }} placeholder="Shipping address" value={form.shippingAddress} onChange={(e) => setForm({ ...form, shippingAddress: e.target.value })} />
          <input style={{ ...inp, width: 110 }} type="number" placeholder="Credit limit" value={form.creditLimit || ''} onChange={(e) => setForm({ ...form, creditLimit: +e.target.value })} />
          <button style={btn} disabled={!form.name}
            onClick={() => api('/sales/customers', { method: 'POST', body: form, entityId }).then(() => { setForm({ name: '', phone: '', email: '', gstin: '', billingAddress: '', shippingAddress: '', creditLimit: 0 }); load() }).catch((e) => setErr(e.message))}>Create</button>
        </div>
      </div>
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>No</th><th style={th}>Name</th><th style={th}>Phone</th><th style={th}>Email</th><th style={th}>GSTIN</th><th style={th}>Credit points</th><th style={th}>Credit limit</th><th style={th}>Active</th></tr></thead>
        <tbody>{rows.map((r) => (
          <tr key={r.id}>
            <td style={td}><b>{r.customer_no}</b></td><td style={td}>{r.name}</td><td style={td}>{r.phone ?? ''}</td><td style={td}>{r.email ?? ''}</td><td style={td}>{r.gstin ?? ''}</td>
            <td style={num}>{fmtQty(+r.credit_points)}</td><td style={num}>{fmt(r.credit_limit)}</td><td style={td}>{r.active ? 'Yes' : 'No'}</td>
          </tr>
        ))}</tbody>
      </table>
    </div>
  )
}

// Shared line editor: item select auto-fills unit price (sales_price), GST rate and description.
function LinesEditor({ lines, setLines, items }: { lines: DLine[]; setLines: (l: DLine[]) => void; items: Item[] }) {
  const total = lines.reduce((s, l) => s + lineAmt(l), 0)
  return (
    <div>
      <table style={{ width: '100%', borderCollapse: 'collapse', marginTop: 8 }}>
        <thead><tr><th style={th}>Item</th><th style={th}>Description</th><th style={th}>Qty</th><th style={th}>Unit price</th><th style={th}>Discount</th><th style={th}>GST %</th><th style={th}>Amount</th><th style={th}></th></tr></thead>
        <tbody>{lines.map((l, i) => (
          <tr key={i}>
            <td style={td}><select style={inp} value={l.itemId} onChange={(e) => {
              const it = items.find((x) => x.id === e.target.value)
              setLines(lines.map((x, j) => j === i ? { ...x, itemId: e.target.value, unitPrice: it ? +it.sales_price : x.unitPrice, taxRate: it ? +it.gst_rate : x.taxRate, description: it ? it.name : x.description } : x))
            }}>
              <option value="">Item…</option>{items.map((it) => <option key={it.id} value={it.id}>{it.item_no} {it.name}</option>)}
            </select></td>
            <td style={td}><input style={inp} value={l.description ?? ''} onChange={(e) => setLines(lines.map((x, j) => j === i ? { ...x, description: e.target.value } : x))} /></td>
            <td style={td}><input style={{ ...inp, width: 70 }} type="number" value={l.qty || ''} onChange={(e) => setLines(lines.map((x, j) => j === i ? { ...x, qty: +e.target.value } : x))} /></td>
            <td style={td}><input style={{ ...inp, width: 100 }} type="number" value={l.unitPrice || ''} onChange={(e) => setLines(lines.map((x, j) => j === i ? { ...x, unitPrice: +e.target.value } : x))} /></td>
            <td style={td}><input style={{ ...inp, width: 90 }} type="number" value={l.discount || ''} onChange={(e) => setLines(lines.map((x, j) => j === i ? { ...x, discount: +e.target.value } : x))} /></td>
            <td style={td}><input style={{ ...inp, width: 70 }} type="number" value={l.taxRate} onChange={(e) => setLines(lines.map((x, j) => j === i ? { ...x, taxRate: +e.target.value } : x))} /></td>
            <td style={num}>{fmt(lineAmt(l))}</td>
            <td style={td}><button style={{ ...btn, background: '#fee2e2', color: '#b91c1c' }} onClick={() => setLines(lines.filter((_, j) => j !== i))}>×</button></td>
          </tr>
        ))}</tbody>
      </table>
      <div style={{ display: 'flex', gap: 8, marginTop: 10, alignItems: 'center' }}>
        <button style={{ ...btn, background: '#e2e8f0', color: '#334155' }} onClick={() => setLines([...lines, { itemId: '', qty: 1, unitPrice: 0, discount: 0, taxRate: 18 }])}>+ line</button>
        <span style={{ fontSize: 13 }}>Total (GST-inclusive) <b>{fmt(total)}</b></span>
      </div>
    </div>
  )
}

const toDLines = (lines: SrvLine[]): DLine[] =>
  (lines ?? []).map((l) => ({ itemId: l.item_id, description: l.description ?? undefined, qty: +l.qty, unitPrice: +l.unit_price, discount: +l.discount, taxRate: +l.tax_rate }))

function Quotations({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [docs, setDocs] = useState<Doc[]>([])
  const [customers, setCustomers] = useState<Customer[]>([])
  const [items, setItems] = useState<Item[]>([])
  const [openId, setOpenId] = useState('')
  const [lines, setLines] = useState<DLine[]>([])
  const [customerId, setCustomerId] = useState('')
  const load = () => {
    api<Doc[]>('/sales/quotations', { entityId }).then(setDocs).catch((e) => setErr(e.message))
    api<Customer[]>('/sales/customers', { entityId }).then(setCustomers).catch(() => {})
    api<Item[]>('/inv/items', { entityId }).then(setItems).catch(() => {})
  }
  useEffect(() => { load() }, [entityId])
  const open = docs.find((d) => d.id === openId)
  return (
    <div>
      <div style={box}>
        <div style={{ display: 'flex', gap: 8 }}>
          <select style={{ ...inp, flex: 1 }} value={customerId} onChange={(e) => setCustomerId(e.target.value)}>
            <option value="">Customer…</option>{customers.map((c) => <option key={c.id} value={c.id}>{c.customer_no} {c.name}</option>)}
          </select>
          <button style={btn} disabled={!customerId}
            onClick={() => api<Doc>('/sales/quotations', { method: 'POST', body: { customerId }, entityId }).then((d) => { setCustomerId(''); setOpenId(d.id); setLines([]); load() }).catch((e) => setErr(e.message))}>Create draft</button>
        </div>
      </div>
      {open && open.status === 'draft' && (
        <div style={box}>
          <b style={{ fontSize: 14 }}>{open.quotation_no} — {open.erp_customers?.name}</b>
          <LinesEditor lines={lines} setLines={setLines} items={items} />
          <div style={{ display: 'flex', gap: 8, marginTop: 10 }}>
            <button style={btn} onClick={() => api('/sales/quotations/' + open.id + '/lines', { method: 'PUT', body: { lines }, entityId }).then(load).catch((e) => setErr(e.message))}>Save lines</button>
            <button style={{ ...btn, background: '#166534' }} disabled={!lines.length || lines.some((l) => !l.itemId)}
              onClick={() => api('/sales/quotations/' + open.id + '/lines', { method: 'PUT', body: { lines }, entityId })
                .then(() => api('/sales/quotations/' + open.id + '/approve', { method: 'POST', body: {}, entityId }))
                .then(() => { setOpenId(''); setLines([]); load() }).catch((e) => setErr(e.message))}>Save + Approve</button>
          </div>
        </div>
      )}
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>No</th><th style={th}>Date</th><th style={th}>Customer</th><th style={th}>Total</th><th style={th}>Status</th><th style={th}></th></tr></thead>
        <tbody>{docs.map((d) => (
          <tr key={d.id} onClick={() => { if (d.status === 'draft') { setOpenId(d.id); api<Doc & { lines: SrvLine[] }>('/sales/quotations/' + d.id, { entityId }).then((r) => setLines(toDLines(r.lines))).catch((e) => setErr(e.message)) } }}
            style={{ cursor: d.status === 'draft' ? 'pointer' : 'default', background: d.id === openId ? '#f8fafc' : undefined }}>
            <td style={td}><b>{d.quotation_no}</b></td><td style={td}>{d.quotation_date}</td>
            <td style={td}>{d.erp_customers ? `${d.erp_customers.customer_no} ${d.erp_customers.name}` : ''}</td>
            <td style={num}>{fmt(d.total_amount)}</td><td style={td}>{d.status}</td>
            <td style={td}>{d.status === 'approved' && (
              <button style={{ ...btn, background: '#166534' }} onClick={(e) => { e.stopPropagation(); api('/sales/quotations/' + d.id + '/convert', { method: 'POST', body: {}, entityId }).then(load).catch((er) => setErr(er.message)) }}>Convert → SO</button>
            )}</td>
          </tr>
        ))}</tbody>
      </table>
    </div>
  )
}

function Orders({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [docs, setDocs] = useState<Doc[]>([])
  const [customers, setCustomers] = useState<Customer[]>([])
  const [items, setItems] = useState<Item[]>([])
  const [warehouses, setWarehouses] = useState<Warehouse[]>([])
  const [openId, setOpenId] = useState('')
  const [lines, setLines] = useState<DLine[]>([])
  const [form, setForm] = useState({ customerId: '', warehouseId: '' })
  const [invWh, setInvWh] = useState('')
  const load = () => {
    api<Doc[]>('/sales/orders', { entityId }).then(setDocs).catch((e) => setErr(e.message))
    api<Customer[]>('/sales/customers', { entityId }).then(setCustomers).catch(() => {})
    api<Item[]>('/inv/items', { entityId }).then(setItems).catch(() => {})
    api<Warehouse[]>('/inv/warehouses', { entityId }).then(setWarehouses).catch(() => {})
  }
  useEffect(() => { load() }, [entityId])
  const open = docs.find((d) => d.id === openId)
  const openOrder = (d: Doc) => {
    setOpenId(d.id); setInvWh(d.warehouse_id ?? '')
    api<Doc & { lines: SrvLine[] }>('/sales/orders/' + d.id, { entityId }).then((r) => setLines(toDLines(r.lines))).catch((e) => setErr(e.message))
  }
  return (
    <div>
      <div style={box}>
        <div style={{ display: 'flex', gap: 8 }}>
          <select style={{ ...inp, flex: 1 }} value={form.customerId} onChange={(e) => setForm({ ...form, customerId: e.target.value })}>
            <option value="">Customer…</option>{customers.map((c) => <option key={c.id} value={c.id}>{c.customer_no} {c.name}</option>)}
          </select>
          <select style={inp} value={form.warehouseId} onChange={(e) => setForm({ ...form, warehouseId: e.target.value })}>
            <option value="">Warehouse (optional)…</option>{warehouses.map((w) => <option key={w.id} value={w.id}>{w.warehouse_no} {w.name}</option>)}
          </select>
          <button style={btn} disabled={!form.customerId}
            onClick={() => api<Doc>('/sales/orders', { method: 'POST', body: form, entityId }).then((d) => { setForm({ customerId: '', warehouseId: '' }); setOpenId(d.id); setInvWh(d.warehouse_id ?? ''); setLines([]); load() }).catch((e) => setErr(e.message))}>Create order</button>
        </div>
      </div>
      {open && open.status === 'open' && (
        <div style={box}>
          <b style={{ fontSize: 14 }}>{open.order_no} — {open.erp_customers?.name}</b>
          <LinesEditor lines={lines} setLines={setLines} items={items} />
          <div style={{ display: 'flex', gap: 8, marginTop: 10, alignItems: 'center' }}>
            <button style={btn} onClick={() => api('/sales/orders/' + open.id + '/lines', { method: 'PUT', body: { lines }, entityId }).then(load).catch((e) => setErr(e.message))}>Save lines</button>
            <select style={inp} value={invWh} onChange={(e) => setInvWh(e.target.value)}>
              <option value="">Invoice warehouse…</option>{warehouses.map((w) => <option key={w.id} value={w.id}>{w.warehouse_no} {w.name}</option>)}
            </select>
            <button style={{ ...btn, background: '#166534' }} disabled={!invWh || !lines.length || lines.some((l) => !l.itemId)}
              onClick={() => api('/sales/orders/' + open.id + '/lines', { method: 'PUT', body: { lines }, entityId })
                .then(() => api('/sales/orders/' + open.id + '/invoice', { method: 'POST', body: { warehouseId: invWh }, entityId }))
                .then(() => { setOpenId(''); setLines([]); load() }).catch((e) => setErr(e.message))}>Create invoice</button>
          </div>
        </div>
      )}
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>No</th><th style={th}>Date</th><th style={th}>Customer</th><th style={th}>Total</th><th style={th}>Status</th></tr></thead>
        <tbody>{docs.map((d) => (
          <tr key={d.id} onClick={() => { if (d.status === 'open') openOrder(d) }}
            style={{ cursor: d.status === 'open' ? 'pointer' : 'default', background: d.id === openId ? '#f8fafc' : undefined }}>
            <td style={td}><b>{d.order_no}</b></td><td style={td}>{d.order_date}</td>
            <td style={td}>{d.erp_customers ? `${d.erp_customers.customer_no} ${d.erp_customers.name}` : ''}</td>
            <td style={num}>{fmt(d.total_amount)}</td>
            <td style={td}>{d.status === 'invoiced' ? '✅ invoiced' : d.status}</td>
          </tr>
        ))}</tbody>
      </table>
    </div>
  )
}

function Invoices({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [docs, setDocs] = useState<Doc[]>([])
  const [open, setOpen] = useState<(Doc & { lines: SrvLine[] }) | null>(null)
  const load = () => api<Doc[]>('/sales/invoices', { entityId }).then(setDocs).catch((e) => setErr(e.message))
  useEffect(() => { load() }, [entityId])
  // GST-inclusive split per line: taxable = amount / (1 + rate/100), tax halves to CGST/SGST at display
  const taxable = (l: SrvLine) => Math.round((+l.line_amount / (1 + +l.tax_rate / 100)) * 100) / 100
  const totTaxable = (open?.lines ?? []).reduce((s, l) => s + taxable(l), 0)
  const totTax = (open?.lines ?? []).reduce((s, l) => s + (+l.line_amount - taxable(l)), 0)
  return (
    <div>
      {open && (
        <div style={box}>
          <b style={{ fontSize: 14 }}>{open.invoice_no} — {open.invoice_date} — {open.erp_customers?.name} ({open.status})</b>
          <table style={{ width: '100%', borderCollapse: 'collapse', marginTop: 8 }}>
            <thead><tr><th style={th}>Item</th><th style={th}>Description</th><th style={th}>Qty</th><th style={th}>Unit price</th><th style={th}>Discount</th><th style={th}>GST %</th><th style={th}>Taxable</th><th style={th}>Amount</th></tr></thead>
            <tbody>{open.lines.map((l) => (
              <tr key={l.line_no ?? l.item_id}>
                <td style={td}>{l.items ? `${l.items.item_no} ${l.items.name}` : ''}</td><td style={td}>{l.description ?? ''}</td>
                <td style={num}>{fmtQty(+l.qty)}</td><td style={num}>{fmt(+l.unit_price)}</td><td style={num}>{fmt(+l.discount)}</td>
                <td style={num}>{Number(l.tax_rate)}</td><td style={num}>{fmt(taxable(l))}</td><td style={num}>{fmt(+l.line_amount)}</td>
              </tr>
            ))}</tbody>
          </table>
          <div style={{ display: 'flex', gap: 16, marginTop: 10, fontSize: 13, alignItems: 'center', flexWrap: 'wrap' }}>
            <span>Taxable <b>{fmt(totTaxable)}</b></span>
            <span>CGST <b>{fmt(totTax / 2)}</b></span>
            <span>SGST <b>{fmt(totTax / 2)}</b></span>
            <span>Total <b>{fmt(open.total_amount)}</b></span>
            {open.status === 'draft' && (
              <button style={{ ...btn, background: '#166534' }}
                onClick={() => api('/sales/invoices/' + open.id + '/post', { method: 'POST', body: {}, entityId }).then(() => { setOpen(null); load() }).catch((e) => setErr(e.message))}>Post</button>
            )}
            <button style={{ ...btn, background: '#e2e8f0', color: '#334155' }} onClick={() => setOpen(null)}>Close</button>
          </div>
        </div>
      )}
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>No</th><th style={th}>Date</th><th style={th}>Customer</th><th style={th}>Total</th><th style={th}>Status</th></tr></thead>
        <tbody>{docs.map((d) => (
          <tr key={d.id} onClick={() => api<Doc & { lines: SrvLine[] }>('/sales/invoices/' + d.id, { entityId }).then(setOpen).catch((e) => setErr(e.message))} style={{ cursor: 'pointer' }}>
            <td style={td}><b>{d.invoice_no}</b></td><td style={td}>{d.invoice_date}</td>
            <td style={td}>{d.erp_customers ? `${d.erp_customers.customer_no} ${d.erp_customers.name}` : ''}</td>
            <td style={num}>{fmt(d.total_amount)}</td>
            <td style={td}>{d.status === 'posted' ? '✅ posted' : d.status}</td>
          </tr>
        ))}</tbody>
      </table>
    </div>
  )
}

function Transactions({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [customers, setCustomers] = useState<Customer[]>([])
  const [customerId, setCustomerId] = useState('')
  const [rows, setRows] = useState<TxnRow[]>([])
  useEffect(() => { api<Customer[]>('/sales/customers', { entityId }).then(setCustomers).catch((e) => setErr(e.message)) }, [entityId])
  const run = (id: string) => {
    setCustomerId(id)
    if (id) api<TxnRow[]>('/sales/customers/' + id + '/transactions', { entityId }).then(setRows).catch((e) => setErr(e.message))
    else setRows([])
  }
  return (
    <div>
      <div style={{ display: 'flex', gap: 8, marginBottom: 12 }}>
        <select style={inp} value={customerId} onChange={(e) => run(e.target.value)}>
          <option value="">Customer…</option>{customers.map((c) => <option key={c.id} value={c.id}>{c.customer_no} {c.name}</option>)}
        </select>
      </div>
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>Voucher</th><th style={th}>Date</th><th style={th}>Description</th><th style={th}>Account</th><th style={th}>Debit</th><th style={th}>Credit</th></tr></thead>
        <tbody>{rows.map((r, i) => (
          <tr key={i}>
            <td style={td}><b>{r.voucher?.voucher_no ?? ''}</b></td><td style={td}>{r.voucher?.voucher_date ?? ''}</td><td style={td}>{r.voucher?.description ?? ''}</td>
            <td style={td}>{r.ledger_accounts ? `${r.ledger_accounts.account_no} ${r.ledger_accounts.name}` : ''}</td>
            <td style={num}>{fmt(+r.debit)}</td><td style={num}>{fmt(+r.credit)}</td>
          </tr>
        ))}</tbody>
      </table>
      {customerId && rows.length === 0 && <p style={{ fontSize: 13, color: '#94a3b8' }}>No posted transactions for this customer yet.</p>}
    </div>
  )
}

function Reports({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const today = new Date().toISOString().slice(0, 10)
  const [from, setFrom] = useState('2026-04-01')
  const [to, setTo] = useState(today)
  const [rows, setRows] = useState<RegRow[]>([])
  const run = () => api<RegRow[]>(`/sales/reports/register?from=${from}&to=${to}`, { entityId }).then(setRows).catch((e) => setErr(e.message))
  useEffect(() => { run() }, [entityId])
  const tot = rows.reduce((s, r) => s + +r.total, 0)
  return (
    <div>
      <div style={{ display: 'flex', gap: 8, marginBottom: 12, alignItems: 'center' }}>
        <input style={inp} type="date" value={from} onChange={(e) => setFrom(e.target.value)} />
        <input style={inp} type="date" value={to} onChange={(e) => setTo(e.target.value)} />
        <button style={btn} onClick={run}>Run</button>
        <button style={{ ...btn, background: '#e2e8f0', color: '#334155' }}
          onClick={() => downloadCsv(`sales-register-${from}-${to}`, ['Invoice', 'Date', 'Customer no', 'Customer', 'Taxable', 'CGST', 'SGST', 'Total', 'Status'],
            rows.map((r) => [r.invoice_no, r.invoice_date, r.customer_no, r.customer_name, r.taxable, +r.tax / 2, +r.tax / 2, r.total, r.status]))}>
          Download CSV</button>
        <span style={{ fontSize: 13 }}>Invoices <b>{rows.length}</b> · Total <b>{fmt(tot)}</b></span>
      </div>
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>Invoice</th><th style={th}>Date</th><th style={th}>Customer</th><th style={th}>Taxable</th><th style={th}>CGST</th><th style={th}>SGST</th><th style={th}>Total</th><th style={th}>Status</th></tr></thead>
        <tbody>{rows.map((r) => (
          <tr key={r.invoice_no}>
            <td style={td}><b>{r.invoice_no}</b></td><td style={td}>{r.invoice_date}</td><td style={td}>{r.customer_no} {r.customer_name}</td>
            <td style={num}>{fmt(+r.taxable)}</td><td style={num}>{fmt(+r.tax / 2)}</td><td style={num}>{fmt(+r.tax / 2)}</td><td style={num}>{fmt(+r.total)}</td><td style={td}>{r.status}</td>
          </tr>
        ))}</tbody>
      </table>
      {rows.length === 0 && <p style={{ fontSize: 13, color: '#94a3b8' }}>No posted invoices in this period.</p>}
    </div>
  )
}
