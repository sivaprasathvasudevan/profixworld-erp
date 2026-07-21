import { useEffect, useState } from 'react'
import { api } from '../lib/api'

type Vendor = { id: string; vendor_no: string; name: string; phone?: string; email?: string; gstin?: string; address?: string; bank_details?: string; active: boolean }
type Item = { id: string; item_no: string; name: string; item_type: string; gst_rate: number; sales_price: number; avg_cost: number }
type Warehouse = { id: string; warehouse_no: string; name: string }
type Doc = {
  id: string; status: string; total_amount: number; vendor_id: string
  vendors?: { vendor_no: string; name: string }
  order_no?: string; order_date?: string; warehouse_id?: string
  grn_no?: string; grn_date?: string; purchase_order_id?: string
  invoice_no?: string; invoice_date?: string; goods_receipt_id?: string; voucher_id?: string; posted?: boolean
}
type DLine = { itemId: string; description?: string; qty: number; unitPrice: number; discount: number; taxRate: number }
type SrvLine = { line_no?: number; item_id: string; description?: string; qty: number; unit_price: number; discount: number; tax_rate: number; line_amount: number; items?: { item_no: string; name: string; item_type: string } }
type TxnRow = { voucher_id: string; line_no: number; debit: number; credit: number; memo?: string; ledger_accounts?: { account_no: string; name: string }; voucher?: { voucher_no: string; voucher_date: string; description?: string } | null }
type RegRow = { invoice_no: string; invoice_date: string; vendor_no: string; vendor_name: string; total: number; taxable: number; tax: number; status: string }

const TABS = ['Vendors', 'Purchase orders', 'Goods receipts', 'Invoices', 'Vendor transactions', 'Reports'] as const
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

export function Procurement({ entityId }: { entityId: string }) {
  const [tab, setTab] = useState<(typeof TABS)[number]>('Vendors')
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
      {tab === 'Vendors' && <Vendors entityId={entityId} setErr={setErr} />}
      {tab === 'Purchase orders' && <Orders entityId={entityId} setErr={setErr} />}
      {tab === 'Goods receipts' && <Receipts entityId={entityId} setErr={setErr} />}
      {tab === 'Invoices' && <Invoices entityId={entityId} setErr={setErr} />}
      {tab === 'Vendor transactions' && <Transactions entityId={entityId} setErr={setErr} />}
      {tab === 'Reports' && <Reports entityId={entityId} setErr={setErr} />}
    </div>
  )
}

function Vendors({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [rows, setRows] = useState<Vendor[]>([])
  const [form, setForm] = useState({ name: '', phone: '', email: '', gstin: '', address: '', bankDetails: '' })
  const load = () => api<Vendor[]>('/purchase/vendors', { entityId }).then(setRows).catch((e) => setErr(e.message))
  useEffect(() => { load() }, [entityId])
  return (
    <div>
      <div style={box}>
        <b style={{ fontSize: 14 }}>New vendor (vendor no is allocated automatically)</b>
        <div style={{ display: 'flex', gap: 8, marginTop: 10, flexWrap: 'wrap' }}>
          <input style={{ ...inp, flex: 1, minWidth: 160 }} placeholder="Name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
          <input style={inp} placeholder="Phone" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} />
          <input style={inp} placeholder="Email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} />
          <input style={inp} placeholder="GSTIN" value={form.gstin} onChange={(e) => setForm({ ...form, gstin: e.target.value })} />
          <input style={{ ...inp, minWidth: 180 }} placeholder="Address" value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })} />
          <input style={{ ...inp, minWidth: 180 }} placeholder="Bank details" value={form.bankDetails} onChange={(e) => setForm({ ...form, bankDetails: e.target.value })} />
          <button style={btn} disabled={!form.name}
            onClick={() => api('/purchase/vendors', { method: 'POST', body: form, entityId }).then(() => { setForm({ name: '', phone: '', email: '', gstin: '', address: '', bankDetails: '' }); load() }).catch((e) => setErr(e.message))}>Create</button>
        </div>
      </div>
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>No</th><th style={th}>Name</th><th style={th}>Phone</th><th style={th}>Email</th><th style={th}>GSTIN</th><th style={th}>Address</th><th style={th}>Bank details</th><th style={th}>Active</th></tr></thead>
        <tbody>{rows.map((r) => (
          <tr key={r.id}>
            <td style={td}><b>{r.vendor_no}</b></td><td style={td}>{r.name}</td><td style={td}>{r.phone ?? ''}</td><td style={td}>{r.email ?? ''}</td><td style={td}>{r.gstin ?? ''}</td>
            <td style={td}>{r.address ?? ''}</td><td style={td}>{r.bank_details ?? ''}</td><td style={td}>{r.active ? 'Yes' : 'No'}</td>
          </tr>
        ))}</tbody>
      </table>
    </div>
  )
}

// Shared line editor: item select suggests unit price = avg_cost * 1.18 (GST-inclusive hint, fully editable).
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
              const hint = it ? Math.round(+it.avg_cost * (1 + +it.gst_rate / 100) * 100) / 100 : 0
              setLines(lines.map((x, j) => j === i ? { ...x, itemId: e.target.value, unitPrice: it ? hint : x.unitPrice, taxRate: it ? +it.gst_rate : x.taxRate, description: it ? it.name : x.description } : x))
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

function Orders({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [docs, setDocs] = useState<Doc[]>([])
  const [vendors, setVendors] = useState<Vendor[]>([])
  const [items, setItems] = useState<Item[]>([])
  const [warehouses, setWarehouses] = useState<Warehouse[]>([])
  const [openId, setOpenId] = useState('')
  const [lines, setLines] = useState<DLine[]>([])
  const [form, setForm] = useState({ vendorId: '', warehouseId: '' })
  const [grnWh, setGrnWh] = useState('')
  const load = () => {
    api<Doc[]>('/purchase/orders', { entityId }).then(setDocs).catch((e) => setErr(e.message))
    api<Vendor[]>('/purchase/vendors', { entityId }).then(setVendors).catch(() => {})
    api<Item[]>('/inv/items', { entityId }).then(setItems).catch(() => {})
    api<Warehouse[]>('/inv/warehouses', { entityId }).then(setWarehouses).catch(() => {})
  }
  useEffect(() => { load() }, [entityId])
  const open = docs.find((d) => d.id === openId)
  return (
    <div>
      <div style={box}>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <select style={{ ...inp, flex: 1, minWidth: 180 }} value={form.vendorId} onChange={(e) => setForm({ ...form, vendorId: e.target.value })}>
            <option value="">Vendor…</option>{vendors.map((v) => <option key={v.id} value={v.id}>{v.vendor_no} {v.name}</option>)}
          </select>
          <select style={inp} value={form.warehouseId} onChange={(e) => setForm({ ...form, warehouseId: e.target.value })}>
            <option value="">Warehouse (optional)…</option>{warehouses.map((w) => <option key={w.id} value={w.id}>{w.warehouse_no} {w.name}</option>)}
          </select>
          <button style={btn} disabled={!form.vendorId}
            onClick={() => api<Doc>('/purchase/orders', { method: 'POST', body: form, entityId }).then((d) => { setForm({ vendorId: '', warehouseId: '' }); setOpenId(d.id); setLines([]); load() }).catch((e) => setErr(e.message))}>Create PO</button>
          <span style={{ fontSize: 13, alignSelf: 'center', color: '#64748b' }}>Receive into</span>
          <select style={inp} value={grnWh} onChange={(e) => setGrnWh(e.target.value)}>
            <option value="">GRN warehouse…</option>{warehouses.map((w) => <option key={w.id} value={w.id}>{w.warehouse_no} {w.name}</option>)}
          </select>
        </div>
      </div>
      {open && open.status === 'draft' && (
        <div style={box}>
          <b style={{ fontSize: 14 }}>{open.order_no} — {open.vendors?.name}</b>
          <LinesEditor lines={lines} setLines={setLines} items={items} />
          <div style={{ display: 'flex', gap: 8, marginTop: 10 }}>
            <button style={btn} onClick={() => api('/purchase/orders/' + open.id + '/lines', { method: 'PUT', body: { lines }, entityId }).then(load).catch((e) => setErr(e.message))}>Save lines</button>
            <button style={{ ...btn, background: '#166534' }} disabled={!lines.length || lines.some((l) => !l.itemId)}
              onClick={() => api('/purchase/orders/' + open.id + '/lines', { method: 'PUT', body: { lines }, entityId })
                .then(() => api('/purchase/orders/' + open.id + '/approve', { method: 'POST', body: {}, entityId }))
                .then(() => { setOpenId(''); setLines([]); load() }).catch((e) => setErr(e.message))}>Save + Approve</button>
          </div>
        </div>
      )}
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>No</th><th style={th}>Date</th><th style={th}>Vendor</th><th style={th}>Total</th><th style={th}>Status</th><th style={th}></th></tr></thead>
        <tbody>{docs.map((d) => (
          <tr key={d.id} onClick={() => { if (d.status === 'draft') { setOpenId(d.id); api<Doc & { lines: SrvLine[] }>('/purchase/orders/' + d.id, { entityId }).then((r) => setLines(toDLines(r.lines))).catch((e) => setErr(e.message)) } }}
            style={{ cursor: d.status === 'draft' ? 'pointer' : 'default', background: d.id === openId ? '#f8fafc' : undefined }}>
            <td style={td}><b>{d.order_no}</b></td><td style={td}>{d.order_date}</td>
            <td style={td}>{d.vendors ? `${d.vendors.vendor_no} ${d.vendors.name}` : ''}</td>
            <td style={num}>{fmt(d.total_amount)}</td>
            <td style={td}>{d.status === 'invoiced' ? '✅ invoiced' : d.status}</td>
            <td style={td}>{(d.status === 'approved' || d.status === 'received') && (
              <span style={{ display: 'flex', gap: 6 }}>
                <button style={{ ...btn, background: '#166534' }} disabled={!grnWh && !d.warehouse_id} title={!grnWh && !d.warehouse_id ? 'Pick a GRN warehouse above' : ''}
                  onClick={(e) => { e.stopPropagation(); api('/purchase/orders/' + d.id + '/receive', { method: 'POST', body: { warehouseId: grnWh || d.warehouse_id }, entityId }).then(load).catch((er) => setErr(er.message)) }}>Receive</button>
                <button style={{ ...btn, background: '#1d4ed8' }}
                  onClick={(e) => { e.stopPropagation(); api('/purchase/orders/' + d.id + '/invoice', { method: 'POST', body: {}, entityId }).then(load).catch((er) => setErr(er.message)) }}>Create invoice</button>
              </span>
            )}</td>
          </tr>
        ))}</tbody>
      </table>
    </div>
  )
}

function Receipts({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [docs, setDocs] = useState<Doc[]>([])
  const [open, setOpen] = useState<(Doc & { lines: SrvLine[] }) | null>(null)
  const load = () => api<Doc[]>('/purchase/grns', { entityId }).then(setDocs).catch((e) => setErr(e.message))
  useEffect(() => { load() }, [entityId])
  return (
    <div>
      {open && (
        <div style={box}>
          <b style={{ fontSize: 14 }}>{open.grn_no} — {open.grn_date} — {open.vendors?.name} ({open.status})</b>
          <table style={{ width: '100%', borderCollapse: 'collapse', marginTop: 8 }}>
            <thead><tr><th style={th}>Item</th><th style={th}>Description</th><th style={th}>Qty</th><th style={th}>Unit price</th><th style={th}>GST %</th><th style={th}>Taxable unit cost</th><th style={th}>Amount</th></tr></thead>
            <tbody>{open.lines.map((l) => (
              <tr key={l.line_no ?? l.item_id}>
                <td style={td}>{l.items ? `${l.items.item_no} ${l.items.name}` : ''}</td><td style={td}>{l.description ?? ''}</td>
                <td style={num}>{fmtQty(+l.qty)}</td><td style={num}>{fmt(+l.unit_price)}</td><td style={num}>{Number(l.tax_rate)}</td>
                <td style={num}>{fmt(Math.round((+l.unit_price / (1 + +l.tax_rate / 100)) * 10000) / 10000)}</td>
                <td style={num}>{fmt(+l.line_amount)}</td>
              </tr>
            ))}</tbody>
          </table>
          <div style={{ display: 'flex', gap: 16, marginTop: 10, fontSize: 13, alignItems: 'center' }}>
            <span>Total <b>{fmt(open.total_amount)}</b></span>
            {open.status === 'draft' && (
              <button style={{ ...btn, background: '#166534' }}
                onClick={() => api('/purchase/grns/' + open.id + '/post', { method: 'POST', body: {}, entityId }).then(() => { setOpen(null); load() }).catch((e) => setErr(e.message))}>Post</button>
            )}
            <button style={{ ...btn, background: '#e2e8f0', color: '#334155' }} onClick={() => setOpen(null)}>Close</button>
          </div>
        </div>
      )}
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>No</th><th style={th}>Date</th><th style={th}>Vendor</th><th style={th}>Total</th><th style={th}>Status</th></tr></thead>
        <tbody>{docs.map((d) => (
          <tr key={d.id} onClick={() => api<Doc & { lines: SrvLine[] }>('/purchase/grns/' + d.id, { entityId }).then(setOpen).catch((e) => setErr(e.message))} style={{ cursor: 'pointer' }}>
            <td style={td}><b>{d.grn_no}</b></td><td style={td}>{d.grn_date}</td>
            <td style={td}>{d.vendors ? `${d.vendors.vendor_no} ${d.vendors.name}` : ''}</td>
            <td style={num}>{fmt(d.total_amount)}</td>
            <td style={td}>{d.status === 'posted' ? '✅ posted' : d.status}</td>
          </tr>
        ))}</tbody>
      </table>
    </div>
  )
}

function Invoices({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [docs, setDocs] = useState<Doc[]>([])
  const [open, setOpen] = useState<(Doc & { lines: SrvLine[] }) | null>(null)
  const load = () => api<Doc[]>('/purchase/invoices', { entityId }).then(setDocs).catch((e) => setErr(e.message))
  useEffect(() => { load() }, [entityId])
  // GST-inclusive split per line: taxable = amount / (1 + rate/100); the rest is GST input credit
  const taxable = (l: SrvLine) => Math.round((+l.line_amount / (1 + +l.tax_rate / 100)) * 100) / 100
  const totTaxable = (open?.lines ?? []).reduce((s, l) => s + taxable(l), 0)
  const totTax = (open?.lines ?? []).reduce((s, l) => s + (+l.line_amount - taxable(l)), 0)
  return (
    <div>
      {open && (
        <div style={box}>
          <b style={{ fontSize: 14 }}>{open.invoice_no} — {open.invoice_date} — {open.vendors?.name} ({open.status})</b>
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
            <span>GST input credit <b>{fmt(totTax)}</b></span>
            <span>Total (payable) <b>{fmt(open.total_amount)}</b></span>
            {open.status === 'draft' && (
              <button style={{ ...btn, background: '#166534' }}
                onClick={() => api('/purchase/invoices/' + open.id + '/post', { method: 'POST', body: {}, entityId }).then(() => { setOpen(null); load() }).catch((e) => setErr(e.message))}>Post</button>
            )}
            <button style={{ ...btn, background: '#e2e8f0', color: '#334155' }} onClick={() => setOpen(null)}>Close</button>
          </div>
        </div>
      )}
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>No</th><th style={th}>Date</th><th style={th}>Vendor</th><th style={th}>Total</th><th style={th}>Status</th></tr></thead>
        <tbody>{docs.map((d) => (
          <tr key={d.id} onClick={() => api<Doc & { lines: SrvLine[] }>('/purchase/invoices/' + d.id, { entityId }).then(setOpen).catch((e) => setErr(e.message))} style={{ cursor: 'pointer' }}>
            <td style={td}><b>{d.invoice_no}</b></td><td style={td}>{d.invoice_date}</td>
            <td style={td}>{d.vendors ? `${d.vendors.vendor_no} ${d.vendors.name}` : ''}</td>
            <td style={num}>{fmt(d.total_amount)}</td>
            <td style={td}>{d.status === 'posted' ? '✅ posted' : d.status}</td>
          </tr>
        ))}</tbody>
      </table>
    </div>
  )
}

function Transactions({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [vendors, setVendors] = useState<Vendor[]>([])
  const [vendorId, setVendorId] = useState('')
  const [rows, setRows] = useState<TxnRow[]>([])
  useEffect(() => { api<Vendor[]>('/purchase/vendors', { entityId }).then(setVendors).catch((e) => setErr(e.message)) }, [entityId])
  const run = (id: string) => {
    setVendorId(id)
    if (id) api<TxnRow[]>('/purchase/vendors/' + id + '/transactions', { entityId }).then(setRows).catch((e) => setErr(e.message))
    else setRows([])
  }
  return (
    <div>
      <div style={{ display: 'flex', gap: 8, marginBottom: 12 }}>
        <select style={inp} value={vendorId} onChange={(e) => run(e.target.value)}>
          <option value="">Vendor…</option>{vendors.map((v) => <option key={v.id} value={v.id}>{v.vendor_no} {v.name}</option>)}
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
      {vendorId && rows.length === 0 && <p style={{ fontSize: 13, color: '#94a3b8' }}>No posted transactions for this vendor yet.</p>}
    </div>
  )
}

function Reports({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const today = new Date().toISOString().slice(0, 10)
  const [from, setFrom] = useState('2026-04-01')
  const [to, setTo] = useState(today)
  const [rows, setRows] = useState<RegRow[]>([])
  const run = () => api<RegRow[]>(`/purchase/reports/register?from=${from}&to=${to}`, { entityId }).then(setRows).catch((e) => setErr(e.message))
  useEffect(() => { run() }, [entityId])
  const tot = rows.reduce((s, r) => s + +r.total, 0)
  return (
    <div>
      <div style={{ display: 'flex', gap: 8, marginBottom: 12, alignItems: 'center' }}>
        <input style={inp} type="date" value={from} onChange={(e) => setFrom(e.target.value)} />
        <input style={inp} type="date" value={to} onChange={(e) => setTo(e.target.value)} />
        <button style={btn} onClick={run}>Run</button>
        <button style={{ ...btn, background: '#e2e8f0', color: '#334155' }}
          onClick={() => downloadCsv(`purchase-register-${from}-${to}`, ['Invoice', 'Date', 'Vendor no', 'Vendor', 'Taxable', 'GST input', 'Total', 'Status'],
            rows.map((r) => [r.invoice_no, r.invoice_date, r.vendor_no, r.vendor_name, r.taxable, r.tax, r.total, r.status]))}>
          Download CSV</button>
        <span style={{ fontSize: 13 }}>Invoices <b>{rows.length}</b> · Total <b>{fmt(tot)}</b></span>
      </div>
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>Invoice</th><th style={th}>Date</th><th style={th}>Vendor</th><th style={th}>Taxable</th><th style={th}>GST input</th><th style={th}>Total</th><th style={th}>Status</th></tr></thead>
        <tbody>{rows.map((r) => (
          <tr key={r.invoice_no}>
            <td style={td}><b>{r.invoice_no}</b></td><td style={td}>{r.invoice_date}</td><td style={td}>{r.vendor_no} {r.vendor_name}</td>
            <td style={num}>{fmt(+r.taxable)}</td><td style={num}>{fmt(+r.tax)}</td><td style={num}>{fmt(+r.total)}</td><td style={td}>{r.status}</td>
          </tr>
        ))}</tbody>
      </table>
      {rows.length === 0 && <p style={{ fontSize: 13, color: '#94a3b8' }}>No posted purchase invoices in this period.</p>}
    </div>
  )
}
