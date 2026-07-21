import { useEffect, useState } from 'react'
import { api } from '../lib/api'

type Customer = { id: string; customer_no: string; name: string; phone?: string }
type Item = { id: string; item_no: string; name: string; item_type: string; gst_rate: number; sales_price: number }
type Warehouse = { id: string; warehouse_no: string; name: string }
type Order = {
  id: string; service_order_no: string; status: string; customer_id: string; warehouse_id?: string
  device_brand?: string; device_model?: string; imei?: string; complaint?: string
  total_amount: number; public_token: string; voucher_id?: string; posted: boolean; created_at: string
  erp_customers?: { customer_no: string; name: string; phone?: string }
  warehouses?: { warehouse_no: string; name: string }
}
type SvcLine = { line_no?: number; item_id: string | null; description?: string; qty: number; unit_price: number; tax_rate: number; line_amount: number; items?: { item_no: string; name: string; item_type: string } }
type LogRow = { id: number; from_status?: string; to_status: string; note?: string; at: string }
type Detail = Order & { lines: SvcLine[]; log: LogRow[] }
type LineIn = { itemId: string; description?: string; qty: number; unitPrice: number; taxRate: number }
type OpenRow = { id: string; service_order_no: string; status: string; device_brand?: string; device_model?: string; total_amount: number; created_at: string; age_days: number; erp_customers?: { customer_no: string; name: string } }

// Forward-only workflow (mirror of service_transition in the DB): the UI shows only the legal next steps.
const NEXT: Record<string, string[]> = {
  received: ['wip', 'cancelled'],
  wip: ['completed', 'cancelled'],
  completed: ['delivered'],
  delivered: ['closed'],
  closed: [],
  cancelled: [],
}
const BOARD_COLS = ['received', 'wip', 'completed', 'delivered'] as const
const STATUSES = ['received', 'wip', 'completed', 'delivered', 'closed', 'cancelled'] as const
const LABEL: Record<string, string> = { received: 'Received', wip: 'Work in progress', completed: 'Completed', delivered: 'Delivered', closed: 'Closed', cancelled: 'Cancelled' }
const EDITABLE = ['received', 'wip']

const TABS = ['Board', 'All orders', 'Reports'] as const
const box: React.CSSProperties = { border: '1px solid #e2e8f0', borderRadius: 8, padding: 16, marginBottom: 16 }
const th: React.CSSProperties = { textAlign: 'left', padding: '6px 10px', background: '#f1f5f9', fontSize: 13 }
const td: React.CSSProperties = { padding: '6px 10px', borderTop: '1px solid #e2e8f0', fontSize: 13 }
const num: React.CSSProperties = { ...td, textAlign: 'right', fontVariantNumeric: 'tabular-nums' }
const inp: React.CSSProperties = { padding: '6px 8px', border: '1px solid #cbd5e1', borderRadius: 6, fontSize: 13 }
const btn: React.CSSProperties = { padding: '6px 12px', border: 0, borderRadius: 6, background: '#0b1320', color: '#fff', cursor: 'pointer', fontSize: 13 }
const fmt = (n: number) => Number(n ?? 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })
const fmtQty = (n: number) => Number(n ?? 0).toLocaleString('en-IN', { maximumFractionDigits: 3 })
const lineAmt = (l: LineIn) => Math.round((l.qty || 0) * (l.unitPrice || 0) * 100) / 100

function downloadCsv(name: string, headers: string[], rows: (string | number)[][]) {
  const esc = (v: string | number) => `"${String(v ?? '').replace(/"/g, '""')}"`
  const csv = [headers.map(esc).join(','), ...rows.map((r) => r.map(esc).join(','))].join('\n')
  const a = document.createElement('a')
  a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv' }))
  a.download = `${name}.csv`
  a.click()
}

// wa.me share: order no + status + public tracking link (link placeholder until the public page is wired).
const waShareUrl = (o: Order) => {
  const link = `https://profixworld.com/s/${o.public_token}`
  const device = [o.device_brand, o.device_model].filter(Boolean).join(' ')
  const text = `ProFix service update\nOrder: ${o.service_order_no}${device ? `\nDevice: ${device}` : ''}\nStatus: ${LABEL[o.status] ?? o.status}\nTrack: ${link}`
  return `https://wa.me/?text=${encodeURIComponent(text)}`
}

export function Service({ entityId }: { entityId: string }) {
  const [tab, setTab] = useState<(typeof TABS)[number]>('Board')
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
      {tab === 'Board' && <Board entityId={entityId} setErr={setErr} />}
      {tab === 'All orders' && <AllOrders entityId={entityId} setErr={setErr} />}
      {tab === 'Reports' && <Reports entityId={entityId} setErr={setErr} />}
    </div>
  )
}

// Line editor: pick an item (auto-fills price/GST/description) or leave the item empty for a manual
// service line — manual lines post as Service Revenue and carry no stock.
function LinesEditor({ lines, setLines, items }: { lines: LineIn[]; setLines: (l: LineIn[]) => void; items: Item[] }) {
  const total = lines.reduce((s, l) => s + lineAmt(l), 0)
  return (
    <div>
      <table style={{ width: '100%', borderCollapse: 'collapse', marginTop: 8 }}>
        <thead><tr><th style={th}>Item</th><th style={th}>Description</th><th style={th}>Qty</th><th style={th}>Unit price</th><th style={th}>GST %</th><th style={th}>Amount</th><th style={th}></th></tr></thead>
        <tbody>{lines.map((l, i) => (
          <tr key={i}>
            <td style={td}><select style={inp} value={l.itemId} onChange={(e) => {
              const it = items.find((x) => x.id === e.target.value)
              setLines(lines.map((x, j) => j === i ? { ...x, itemId: e.target.value, unitPrice: it ? +it.sales_price : x.unitPrice, taxRate: it ? +it.gst_rate : x.taxRate, description: it ? it.name : x.description } : x))
            }}>
              <option value="">Manual line…</option>{items.map((it) => <option key={it.id} value={it.id}>{it.item_no} {it.name} ({it.item_type})</option>)}
            </select></td>
            <td style={td}><input style={{ ...inp, minWidth: 160 }} placeholder="Description" value={l.description ?? ''} onChange={(e) => setLines(lines.map((x, j) => j === i ? { ...x, description: e.target.value } : x))} /></td>
            <td style={td}><input style={{ ...inp, width: 70 }} type="number" value={l.qty || ''} onChange={(e) => setLines(lines.map((x, j) => j === i ? { ...x, qty: +e.target.value } : x))} /></td>
            <td style={td}><input style={{ ...inp, width: 100 }} type="number" value={l.unitPrice || ''} onChange={(e) => setLines(lines.map((x, j) => j === i ? { ...x, unitPrice: +e.target.value } : x))} /></td>
            <td style={td}><input style={{ ...inp, width: 70 }} type="number" value={l.taxRate} onChange={(e) => setLines(lines.map((x, j) => j === i ? { ...x, taxRate: +e.target.value } : x))} /></td>
            <td style={num}>{fmt(lineAmt(l))}</td>
            <td style={td}><button style={{ ...btn, background: '#fee2e2', color: '#b91c1c' }} onClick={() => setLines(lines.filter((_, j) => j !== i))}>×</button></td>
          </tr>
        ))}</tbody>
      </table>
      <div style={{ display: 'flex', gap: 8, marginTop: 10, alignItems: 'center' }}>
        <button style={{ ...btn, background: '#e2e8f0', color: '#334155' }} onClick={() => setLines([...lines, { itemId: '', qty: 1, unitPrice: 0, taxRate: 18 }])}>+ line</button>
        <span style={{ fontSize: 13 }}>Total (GST-inclusive) <b>{fmt(total)}</b></span>
      </div>
    </div>
  )
}

const toLineIns = (lines: SvcLine[]): LineIn[] =>
  (lines ?? []).map((l) => ({ itemId: l.item_id ?? '', description: l.description ?? undefined, qty: +l.qty, unitPrice: +l.unit_price, taxRate: +l.tax_rate }))

// Detail panel shared by Board and All orders: lines editor (while editable), workflow timeline,
// transition buttons showing only the legal next steps, WhatsApp share.
function OrderDetail({ entityId, orderId, setErr, onChanged, onClose }: {
  entityId: string; orderId: string; setErr: (s: string) => void; onChanged: () => void; onClose: () => void
}) {
  const [detail, setDetail] = useState<Detail | null>(null)
  const [items, setItems] = useState<Item[]>([])
  const [lines, setLines] = useState<LineIn[]>([])
  const [note, setNote] = useState('')
  const load = () => api<Detail>('/service/orders/' + orderId, { entityId })
    .then((d) => { setDetail(d); setLines(toLineIns(d.lines)) }).catch((e) => setErr(e.message))
  useEffect(() => { load(); api<Item[]>('/inv/items', { entityId }).then(setItems).catch(() => {}) }, [entityId, orderId])
  if (!detail) return null
  const editable = EDITABLE.includes(detail.status)
  const next = NEXT[detail.status] ?? []
  const transition = (to: string) =>
    api('/service/orders/' + detail.id + '/transition', { method: 'POST', body: { to, note: note || undefined }, entityId })
      .then(() => { setNote(''); load(); onChanged() }).catch((e) => setErr(e.message))
  return (
    <div style={box}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', flexWrap: 'wrap', gap: 8 }}>
        <b style={{ fontSize: 14 }}>
          {detail.service_order_no} — {detail.erp_customers?.name}
          {(detail.device_brand || detail.device_model) && <> — {[detail.device_brand, detail.device_model].filter(Boolean).join(' ')}</>}
          {detail.imei && <span style={{ color: '#64748b' }}> (IMEI {detail.imei})</span>}
        </b>
        <span style={{ fontSize: 13 }}>Status <b>{LABEL[detail.status] ?? detail.status}</b>{detail.posted ? ' · ✅ posted' : ''}</span>
      </div>
      {detail.complaint && <p style={{ fontSize: 13, color: '#475569', margin: '6px 0 0' }}>Complaint: {detail.complaint}</p>}
      {editable ? (
        <>
          <LinesEditor lines={lines} setLines={setLines} items={items} />
          <div style={{ marginTop: 10 }}>
            <button style={btn} onClick={() => api('/service/orders/' + detail.id + '/lines', { method: 'PUT', body: { lines }, entityId })
              .then(() => { load(); onChanged() }).catch((e) => setErr(e.message))}>Save lines</button>
          </div>
        </>
      ) : (
        detail.lines.length > 0 && (
          <table style={{ width: '100%', borderCollapse: 'collapse', marginTop: 8 }}>
            <thead><tr><th style={th}>Item</th><th style={th}>Description</th><th style={th}>Qty</th><th style={th}>Unit price</th><th style={th}>GST %</th><th style={th}>Amount</th></tr></thead>
            <tbody>{detail.lines.map((l) => (
              <tr key={l.line_no}>
                <td style={td}>{l.items ? `${l.items.item_no} ${l.items.name}` : 'manual'}</td><td style={td}>{l.description ?? ''}</td>
                <td style={num}>{fmtQty(+l.qty)}</td><td style={num}>{fmt(+l.unit_price)}</td><td style={num}>{Number(l.tax_rate)}</td><td style={num}>{fmt(+l.line_amount)}</td>
              </tr>
            ))}</tbody>
          </table>
        )
      )}
      <div style={{ display: 'flex', gap: 8, marginTop: 12, alignItems: 'center', flexWrap: 'wrap' }}>
        <span style={{ fontSize: 13 }}>Total <b>{fmt(detail.total_amount)}</b></span>
        {next.length > 0 && <input style={{ ...inp, minWidth: 160 }} placeholder="Transition note (optional)" value={note} onChange={(e) => setNote(e.target.value)} />}
        {next.map((to) => (
          <button key={to} onClick={() => transition(to)}
            style={{ ...btn, background: to === 'cancelled' ? '#fee2e2' : '#166534', color: to === 'cancelled' ? '#b91c1c' : '#fff' }}>
            {to === 'cancelled' ? 'Cancel order' : `→ ${LABEL[to]}`}
          </button>
        ))}
        <a href={waShareUrl(detail)} target="_blank" rel="noreferrer"
          style={{ ...btn, background: '#25d366', textDecoration: 'none', display: 'inline-block' }}>WhatsApp status</a>
        <button style={{ ...btn, background: '#e2e8f0', color: '#334155' }} onClick={onClose}>Close</button>
      </div>
      {detail.log.length > 0 && (
        <div style={{ marginTop: 12, fontSize: 13, color: '#475569' }}>
          <b>Timeline</b>
          {detail.log.map((w) => (
            <div key={w.id}>
              {new Date(w.at).toLocaleString('en-IN')} — {w.from_status ? `${LABEL[w.from_status] ?? w.from_status} → ` : ''}{LABEL[w.to_status] ?? w.to_status}{w.note ? ` — ${w.note}` : ''}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

function Board({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [orders, setOrders] = useState<Order[]>([])
  const [customers, setCustomers] = useState<Customer[]>([])
  const [warehouses, setWarehouses] = useState<Warehouse[]>([])
  const [openId, setOpenId] = useState('')
  const [form, setForm] = useState({ customerId: '', warehouseId: '', deviceBrand: '', deviceModel: '', imei: '', complaint: '' })
  const load = () => api<Order[]>('/service/orders', { entityId }).then(setOrders).catch((e) => setErr(e.message))
  useEffect(() => {
    load()
    api<Customer[]>('/sales/customers', { entityId }).then(setCustomers).catch(() => {})
    api<Warehouse[]>('/inv/warehouses', { entityId }).then(setWarehouses).catch(() => {})
  }, [entityId])
  return (
    <div>
      <div style={box}>
        <b style={{ fontSize: 14 }}>New service order (order no is allocated automatically)</b>
        <div style={{ display: 'flex', gap: 8, marginTop: 10, flexWrap: 'wrap' }}>
          <select style={{ ...inp, minWidth: 180 }} value={form.customerId} onChange={(e) => setForm({ ...form, customerId: e.target.value })}>
            <option value="">Customer…</option>{customers.map((c) => <option key={c.id} value={c.id}>{c.customer_no} {c.name}</option>)}
          </select>
          <select style={inp} value={form.warehouseId} onChange={(e) => setForm({ ...form, warehouseId: e.target.value })}>
            <option value="">Store / warehouse…</option>{warehouses.map((w) => <option key={w.id} value={w.id}>{w.warehouse_no} {w.name}</option>)}
          </select>
          <input style={inp} placeholder="Brand" value={form.deviceBrand} onChange={(e) => setForm({ ...form, deviceBrand: e.target.value })} />
          <input style={inp} placeholder="Model" value={form.deviceModel} onChange={(e) => setForm({ ...form, deviceModel: e.target.value })} />
          <input style={inp} placeholder="IMEI" value={form.imei} onChange={(e) => setForm({ ...form, imei: e.target.value })} />
          <input style={{ ...inp, flex: 1, minWidth: 200 }} placeholder="Complaint" value={form.complaint} onChange={(e) => setForm({ ...form, complaint: e.target.value })} />
          <button style={btn} disabled={!form.customerId || !form.warehouseId}
            onClick={() => api<Order>('/service/orders', { method: 'POST', body: form, entityId })
              .then((o) => { setForm({ customerId: '', warehouseId: '', deviceBrand: '', deviceModel: '', imei: '', complaint: '' }); setOpenId(o.id); load() })
              .catch((e) => setErr(e.message))}>Create</button>
        </div>
      </div>
      {openId && <OrderDetail entityId={entityId} orderId={openId} setErr={setErr} onChanged={load} onClose={() => setOpenId('')} />}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12 }}>
        {BOARD_COLS.map((col) => {
          const cards = orders.filter((o) => o.status === col)
          return (
            <div key={col} style={{ background: '#f8fafc', border: '1px solid #e2e8f0', borderRadius: 8, padding: 10, minHeight: 120 }}>
              <div style={{ fontSize: 13, fontWeight: 700, marginBottom: 8, color: '#334155' }}>{LABEL[col]} ({cards.length})</div>
              {cards.map((o) => (
                <div key={o.id} onClick={() => setOpenId(o.id)}
                  style={{ background: '#fff', border: '1px solid ' + (o.id === openId ? '#0b1320' : '#e2e8f0'), borderRadius: 8, padding: 10, marginBottom: 8, cursor: 'pointer', fontSize: 13 }}>
                  <b>{o.service_order_no}</b>
                  <div>{o.erp_customers?.name ?? ''}</div>
                  <div style={{ color: '#64748b' }}>{[o.device_brand, o.device_model].filter(Boolean).join(' ')}</div>
                  <div style={{ textAlign: 'right', fontVariantNumeric: 'tabular-nums' }}>{fmt(o.total_amount)}</div>
                </div>
              ))}
            </div>
          )
        })}
      </div>
    </div>
  )
}

function AllOrders({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [orders, setOrders] = useState<Order[]>([])
  const [status, setStatus] = useState('')
  const [openId, setOpenId] = useState('')
  const load = () => api<Order[]>('/service/orders' + (status ? `?status=${status}` : ''), { entityId }).then(setOrders).catch((e) => setErr(e.message))
  useEffect(() => { load() }, [entityId, status])
  return (
    <div>
      <div style={{ display: 'flex', gap: 8, marginBottom: 12 }}>
        <select style={inp} value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value="">All statuses…</option>{STATUSES.map((s) => <option key={s} value={s}>{LABEL[s]}</option>)}
        </select>
      </div>
      {openId && <OrderDetail entityId={entityId} orderId={openId} setErr={setErr} onChanged={load} onClose={() => setOpenId('')} />}
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>No</th><th style={th}>Date</th><th style={th}>Customer</th><th style={th}>Device</th><th style={th}>Store</th><th style={th}>Total</th><th style={th}>Status</th></tr></thead>
        <tbody>{orders.map((o) => (
          <tr key={o.id} onClick={() => setOpenId(o.id)} style={{ cursor: 'pointer', background: o.id === openId ? '#f8fafc' : undefined }}>
            <td style={td}><b>{o.service_order_no}</b></td>
            <td style={td}>{new Date(o.created_at).toLocaleDateString('en-IN')}</td>
            <td style={td}>{o.erp_customers ? `${o.erp_customers.customer_no} ${o.erp_customers.name}` : ''}</td>
            <td style={td}>{[o.device_brand, o.device_model].filter(Boolean).join(' ')}</td>
            <td style={td}>{o.warehouses ? `${o.warehouses.warehouse_no} ${o.warehouses.name}` : ''}</td>
            <td style={num}>{fmt(o.total_amount)}</td>
            <td style={td}>{o.posted ? '✅ ' : ''}{LABEL[o.status] ?? o.status}</td>
          </tr>
        ))}</tbody>
      </table>
      {orders.length === 0 && <p style={{ fontSize: 13, color: '#94a3b8' }}>No service orders{status ? ` with status ${LABEL[status]}` : ''} yet.</p>}
    </div>
  )
}

function Reports({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [rows, setRows] = useState<OpenRow[]>([])
  const run = () => api<OpenRow[]>('/service/reports/open', { entityId }).then(setRows).catch((e) => setErr(e.message))
  useEffect(() => { run() }, [entityId])
  const tot = rows.reduce((s, r) => s + +r.total_amount, 0)
  return (
    <div>
      <div style={{ display: 'flex', gap: 8, marginBottom: 12, alignItems: 'center' }}>
        <button style={btn} onClick={run}>Refresh</button>
        <button style={{ ...btn, background: '#e2e8f0', color: '#334155' }}
          onClick={() => downloadCsv('service-open-orders', ['Order', 'Customer no', 'Customer', 'Device', 'Status', 'Age (days)', 'Total'],
            rows.map((r) => [r.service_order_no, r.erp_customers?.customer_no ?? '', r.erp_customers?.name ?? '', [r.device_brand, r.device_model].filter(Boolean).join(' '), r.status, r.age_days, r.total_amount]))}>
          Download CSV</button>
        <span style={{ fontSize: 13 }}>Open orders <b>{rows.length}</b> · Total <b>{fmt(tot)}</b></span>
      </div>
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>Order</th><th style={th}>Customer</th><th style={th}>Device</th><th style={th}>Status</th><th style={th}>Age (days)</th><th style={th}>Total</th></tr></thead>
        <tbody>{rows.map((r) => (
          <tr key={r.id} style={{ background: r.age_days > 7 ? '#fef2f2' : undefined }}>
            <td style={td}><b>{r.service_order_no}</b></td>
            <td style={td}>{r.erp_customers ? `${r.erp_customers.customer_no} ${r.erp_customers.name}` : ''}</td>
            <td style={td}>{[r.device_brand, r.device_model].filter(Boolean).join(' ')}</td>
            <td style={td}>{LABEL[r.status] ?? r.status}</td>
            <td style={num}>{r.age_days}</td>
            <td style={num}>{fmt(+r.total_amount)}</td>
          </tr>
        ))}</tbody>
      </table>
      {rows.length === 0 && <p style={{ fontSize: 13, color: '#94a3b8' }}>No open service orders.</p>}
    </div>
  )
}
