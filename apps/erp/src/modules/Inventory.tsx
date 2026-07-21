import { useEffect, useState } from 'react'
import { api } from '../lib/api'

type Item = { id: string; item_no: string; name: string; item_type: string; category?: string; uom: string; gst_rate: number; sales_price: number; avg_cost: number; active: boolean }
type DimType = { id: string; code: string; name: string }
type DimValue = { id: string; type_id: string; value: string; dimension_types?: { code: string; name: string } }
type ItemDim = { dimension_value_id: string; dimension_values?: { id: string; value: string; dimension_types?: { code: string; name: string } } }
type Warehouse = { id: string; warehouse_no: string; name: string; branch_id?: string; is_store: boolean; active: boolean; branches?: { branch_no: string; name: string } }
type OnHand = { item_id: string; item_no: string; item_name: string; warehouse_id: string; warehouse_no: string; qty: number }
type Journal = { id: string; journal_no: string; journal_date: string; description?: string; status: string; total_qty: number; from_warehouse_id?: string; to_warehouse_id?: string; voucher_id?: string }
type TLine = { itemId: string; qty: number }
type MLine = { itemId: string; warehouseId: string; qty: number; reason?: string }

const TABS = ['Items', 'Warehouses', 'On-hand', 'Transfer journal', 'Movement journal'] as const
const box: React.CSSProperties = { border: '1px solid #e2e8f0', borderRadius: 8, padding: 16, marginBottom: 16 }
const th: React.CSSProperties = { textAlign: 'left', padding: '6px 10px', background: '#f1f5f9', fontSize: 13 }
const td: React.CSSProperties = { padding: '6px 10px', borderTop: '1px solid #e2e8f0', fontSize: 13 }
const num: React.CSSProperties = { ...td, textAlign: 'right', fontVariantNumeric: 'tabular-nums' }
const inp: React.CSSProperties = { padding: '6px 8px', border: '1px solid #cbd5e1', borderRadius: 6, fontSize: 13 }
const btn: React.CSSProperties = { padding: '6px 12px', border: 0, borderRadius: 6, background: '#0b1320', color: '#fff', cursor: 'pointer', fontSize: 13 }
const fmt = (n: number) => Number(n ?? 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })
const fmtQty = (n: number) => Number(n ?? 0).toLocaleString('en-IN', { maximumFractionDigits: 3 })

function downloadCsv(name: string, headers: string[], rows: (string | number)[][]) {
  const esc = (v: string | number) => `"${String(v ?? '').replace(/"/g, '""')}"`
  const csv = [headers.map(esc).join(','), ...rows.map((r) => r.map(esc).join(','))].join('\n')
  const a = document.createElement('a')
  a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv' }))
  a.download = `${name}.csv`
  a.click()
}

export function Inventory({ entityId }: { entityId: string }) {
  const [tab, setTab] = useState<(typeof TABS)[number]>('Items')
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
      {tab === 'Items' && <Items entityId={entityId} setErr={setErr} />}
      {tab === 'Warehouses' && <Warehouses entityId={entityId} setErr={setErr} />}
      {tab === 'On-hand' && <OnHandTab entityId={entityId} setErr={setErr} />}
      {tab === 'Transfer journal' && <TransferTab entityId={entityId} setErr={setErr} />}
      {tab === 'Movement journal' && <MovementTab entityId={entityId} setErr={setErr} />}
    </div>
  )
}

function Items({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [rows, setRows] = useState<Item[]>([])
  const [types, setTypes] = useState<DimType[]>([])
  const [values, setValues] = useState<DimValue[]>([])
  const [form, setForm] = useState({ name: '', itemType: 'product', category: '', uom: 'pcs', gstRate: 18, salesPrice: 0 })
  const [openId, setOpenId] = useState('')
  const [itemDims, setItemDims] = useState<ItemDim[]>([])
  const [attachId, setAttachId] = useState('')
  const [newVal, setNewVal] = useState({ typeId: '', value: '' })
  const load = () => {
    api<Item[]>('/inv/items', { entityId }).then(setRows).catch((e) => setErr(e.message))
    api<DimType[]>('/inv/dimensions/types', { entityId }).then(setTypes).catch(() => {})
    api<DimValue[]>('/inv/dimensions/values', { entityId }).then(setValues).catch(() => {})
  }
  useEffect(() => { load() }, [entityId])
  const loadDims = (id: string) => api<ItemDim[]>('/inv/items/' + id + '/dimensions', { entityId }).then(setItemDims).catch((e) => setErr(e.message))
  const open = rows.find((r) => r.id === openId)
  return (
    <div>
      <div style={box}>
        <b style={{ fontSize: 14 }}>New item (item no is allocated automatically)</b>
        <div style={{ display: 'flex', gap: 8, marginTop: 10, flexWrap: 'wrap' }}>
          <input style={{ ...inp, flex: 1, minWidth: 160 }} placeholder="Name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
          <select style={inp} value={form.itemType} onChange={(e) => setForm({ ...form, itemType: e.target.value })}>
            {['product', 'part', 'service'].map((t) => <option key={t}>{t}</option>)}
          </select>
          <input style={inp} placeholder="Category" value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })} />
          <input style={{ ...inp, width: 60 }} placeholder="UoM" value={form.uom} onChange={(e) => setForm({ ...form, uom: e.target.value })} />
          <input style={{ ...inp, width: 80 }} type="number" placeholder="GST %" value={form.gstRate} onChange={(e) => setForm({ ...form, gstRate: +e.target.value })} />
          <input style={{ ...inp, width: 110 }} type="number" placeholder="Sales price" value={form.salesPrice || ''} onChange={(e) => setForm({ ...form, salesPrice: +e.target.value })} />
          <button style={btn} onClick={() => api('/inv/items', { method: 'POST', body: form, entityId }).then(() => { setForm({ name: '', itemType: 'product', category: '', uom: 'pcs', gstRate: 18, salesPrice: 0 }); load() }).catch((e) => setErr(e.message))}>Create</button>
        </div>
      </div>
      {open && (
        <div style={box}>
          <b style={{ fontSize: 14 }}>{open.item_no} {open.name} — dimensions</b>
          <div style={{ display: 'flex', gap: 8, marginTop: 10, flexWrap: 'wrap' }}>
            {itemDims.map((d) => (
              <span key={d.dimension_value_id} style={{ background: '#f1f5f9', borderRadius: 6, padding: '4px 8px', fontSize: 13 }}>
                {d.dimension_values?.dimension_types?.name}: <b>{d.dimension_values?.value}</b>
                <button style={{ ...btn, marginLeft: 6, padding: '0 6px', background: '#fee2e2', color: '#b91c1c' }}
                  onClick={() => api('/inv/items/' + open.id + '/dimensions/' + d.dimension_value_id, { method: 'DELETE', entityId }).then(() => loadDims(open.id)).catch((e) => setErr(e.message))}>×</button>
              </span>
            ))}
            {itemDims.length === 0 && <span style={{ fontSize: 13, color: '#94a3b8' }}>No dimensions attached</span>}
          </div>
          <div style={{ display: 'flex', gap: 8, marginTop: 10, flexWrap: 'wrap', alignItems: 'center' }}>
            <select style={inp} value={attachId} onChange={(e) => setAttachId(e.target.value)}>
              <option value="">Attach dimension value…</option>
              {values.map((v) => <option key={v.id} value={v.id}>{v.dimension_types?.name}: {v.value}</option>)}
            </select>
            <button style={btn} disabled={!attachId} onClick={() => api('/inv/items/' + open.id + '/dimensions', { method: 'POST', body: { dimensionValueId: attachId }, entityId }).then(() => { setAttachId(''); loadDims(open.id) }).catch((e) => setErr(e.message))}>Attach</button>
            <span style={{ color: '#94a3b8', fontSize: 13 }}>|</span>
            <select style={inp} value={newVal.typeId} onChange={(e) => setNewVal({ ...newVal, typeId: e.target.value })}>
              <option value="">New value: type…</option>{types.map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}
            </select>
            <input style={inp} placeholder="Value (e.g. iPhone 13)" value={newVal.value} onChange={(e) => setNewVal({ ...newVal, value: e.target.value })} />
            <button style={{ ...btn, background: '#e2e8f0', color: '#334155' }} disabled={!newVal.typeId || !newVal.value}
              onClick={() => api('/inv/dimensions/values', { method: 'POST', body: newVal, entityId }).then(() => { setNewVal({ typeId: '', value: '' }); load() }).catch((e) => setErr(e.message))}>Add value</button>
            <button style={{ ...btn, background: '#e2e8f0', color: '#334155' }} onClick={() => setOpenId('')}>Close</button>
          </div>
        </div>
      )}
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>No</th><th style={th}>Name</th><th style={th}>Type</th><th style={th}>Category</th><th style={th}>UoM</th><th style={th}>GST %</th><th style={th}>Sales price</th><th style={th}>Avg cost</th><th style={th}>Active</th></tr></thead>
        <tbody>{rows.map((r) => (
          <tr key={r.id} onClick={() => { setOpenId(r.id); loadDims(r.id) }} style={{ cursor: 'pointer', background: r.id === openId ? '#f8fafc' : undefined }}>
            <td style={td}><b>{r.item_no}</b></td><td style={td}>{r.name}</td><td style={td}>{r.item_type}</td><td style={td}>{r.category ?? ''}</td><td style={td}>{r.uom}</td>
            <td style={num}>{Number(r.gst_rate)}</td><td style={num}>{fmt(r.sales_price)}</td><td style={num}>{fmt(r.avg_cost)}</td><td style={td}>{r.active ? 'Yes' : 'No'}</td>
          </tr>
        ))}</tbody>
      </table>
    </div>
  )
}

function Warehouses({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [rows, setRows] = useState<Warehouse[]>([])
  const [form, setForm] = useState({ warehouseNo: '', name: '', isStore: true })
  const load = () => api<Warehouse[]>('/inv/warehouses', { entityId }).then(setRows).catch((e) => setErr(e.message))
  useEffect(() => { load() }, [entityId])
  return (
    <div>
      <div style={box}>
        <b style={{ fontSize: 14 }}>New warehouse</b>
        <div style={{ display: 'flex', gap: 8, marginTop: 10, alignItems: 'center' }}>
          <input style={inp} placeholder="Warehouse no (e.g. WH-MAIN)" value={form.warehouseNo} onChange={(e) => setForm({ ...form, warehouseNo: e.target.value })} />
          <input style={{ ...inp, flex: 1 }} placeholder="Name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
          <label style={{ fontSize: 13, display: 'flex', gap: 4, alignItems: 'center' }}>
            <input type="checkbox" checked={form.isStore} onChange={(e) => setForm({ ...form, isStore: e.target.checked })} /> Store
          </label>
          <button style={btn} onClick={() => api('/inv/warehouses', { method: 'POST', body: form, entityId }).then(() => { setForm({ warehouseNo: '', name: '', isStore: true }); load() }).catch((e) => setErr(e.message))}>Create</button>
        </div>
      </div>
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>No</th><th style={th}>Name</th><th style={th}>Branch</th><th style={th}>Store</th><th style={th}>Active</th></tr></thead>
        <tbody>{rows.map((r) => (
          <tr key={r.id}><td style={td}><b>{r.warehouse_no}</b></td><td style={td}>{r.name}</td><td style={td}>{r.branches ? `${r.branches.branch_no} ${r.branches.name}` : '—'}</td><td style={td}>{r.is_store ? 'Yes' : 'No'}</td><td style={td}>{r.active ? 'Yes' : 'No'}</td></tr>
        ))}</tbody>
      </table>
    </div>
  )
}

function OnHandTab({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [rows, setRows] = useState<OnHand[]>([])
  const [items, setItems] = useState<Item[]>([])
  const [warehouses, setWarehouses] = useState<Warehouse[]>([])
  const [fItem, setFItem] = useState('')
  const [fWh, setFWh] = useState('')
  const load = () => {
    api<OnHand[]>('/inv/onhand', { entityId }).then(setRows).catch((e) => setErr(e.message))
    api<Item[]>('/inv/items', { entityId }).then(setItems).catch(() => {})
    api<Warehouse[]>('/inv/warehouses', { entityId }).then(setWarehouses).catch(() => {})
  }
  useEffect(() => { load() }, [entityId])
  const whName = (id: string) => { const w = warehouses.find((x) => x.id === id); return w ? w.name : '' }
  const view = rows.filter((r) => (!fItem || r.item_id === fItem) && (!fWh || r.warehouse_id === fWh))
  const total = view.reduce((s, r) => s + +r.qty, 0)
  return (
    <div>
      <div style={{ display: 'flex', gap: 8, marginBottom: 12, alignItems: 'center' }}>
        <select style={inp} value={fItem} onChange={(e) => setFItem(e.target.value)}>
          <option value="">All items</option>{items.map((i) => <option key={i.id} value={i.id}>{i.item_no} {i.name}</option>)}
        </select>
        <select style={inp} value={fWh} onChange={(e) => setFWh(e.target.value)}>
          <option value="">All warehouses</option>{warehouses.map((w) => <option key={w.id} value={w.id}>{w.warehouse_no} {w.name}</option>)}
        </select>
        <button style={btn} onClick={load}>Refresh</button>
        <button style={{ ...btn, background: '#e2e8f0', color: '#334155' }}
          onClick={() => downloadCsv('on-hand', ['Item no', 'Item', 'Warehouse no', 'Warehouse', 'Qty'], view.map((r) => [r.item_no, r.item_name, r.warehouse_no, whName(r.warehouse_id), r.qty]))}>
          Download CSV</button>
        <span style={{ fontSize: 13 }}>Total qty <b>{fmtQty(total)}</b></span>
      </div>
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>Item no</th><th style={th}>Item</th><th style={th}>Warehouse</th><th style={th}>Qty</th></tr></thead>
        <tbody>{view.map((r) => (
          <tr key={r.item_id + r.warehouse_id}>
            <td style={td}><b>{r.item_no}</b></td><td style={td}>{r.item_name}</td><td style={td}>{r.warehouse_no} {whName(r.warehouse_id)}</td>
            <td style={{ ...num, color: +r.qty < 0 ? '#b91c1c' : undefined }}>{fmtQty(+r.qty)}</td>
          </tr>
        ))}</tbody>
      </table>
      {view.length === 0 && <p style={{ fontSize: 13, color: '#94a3b8' }}>No stock yet — post a movement or transfer journal.</p>}
    </div>
  )
}

function TransferTab({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [journals, setJournals] = useState<Journal[]>([])
  const [items, setItems] = useState<Item[]>([])
  const [warehouses, setWarehouses] = useState<Warehouse[]>([])
  const [openId, setOpenId] = useState('')
  const [lines, setLines] = useState<TLine[]>([])
  const [form, setForm] = useState({ description: '', fromWarehouseId: '', toWarehouseId: '' })
  const load = () => {
    api<Journal[]>('/inv/transfers', { entityId }).then(setJournals).catch((e) => setErr(e.message))
    api<Item[]>('/inv/items', { entityId }).then(setItems).catch(() => {})
    api<Warehouse[]>('/inv/warehouses', { entityId }).then(setWarehouses).catch(() => {})
  }
  useEffect(() => { load() }, [entityId])
  const whName = (id?: string) => { const w = warehouses.find((x) => x.id === id); return w ? `${w.warehouse_no} ${w.name}` : '—' }
  const open = journals.find((j) => j.id === openId)
  return (
    <div>
      <div style={box}>
        <b style={{ fontSize: 14 }}>New transfer journal</b>
        <div style={{ display: 'flex', gap: 8, marginTop: 10, flexWrap: 'wrap' }}>
          <select style={inp} value={form.fromWarehouseId} onChange={(e) => setForm({ ...form, fromWarehouseId: e.target.value })}>
            <option value="">From warehouse…</option>{warehouses.map((w) => <option key={w.id} value={w.id}>{w.warehouse_no} {w.name}</option>)}
          </select>
          <select style={inp} value={form.toWarehouseId} onChange={(e) => setForm({ ...form, toWarehouseId: e.target.value })}>
            <option value="">To warehouse…</option>{warehouses.map((w) => <option key={w.id} value={w.id}>{w.warehouse_no} {w.name}</option>)}
          </select>
          <input style={{ ...inp, flex: 1 }} placeholder="Description" value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} />
          <button style={btn} disabled={!form.fromWarehouseId || !form.toWarehouseId || form.fromWarehouseId === form.toWarehouseId}
            onClick={() => api<Journal>('/inv/transfers', { method: 'POST', body: form, entityId }).then((j) => { setForm({ description: '', fromWarehouseId: '', toWarehouseId: '' }); setOpenId(j.id); setLines([]); load() }).catch((e) => setErr(e.message))}>Create draft</button>
        </div>
      </div>
      {open && open.status === 'draft' && (
        <div style={box}>
          <b style={{ fontSize: 14 }}>{open.journal_no} — {whName(open.from_warehouse_id)} → {whName(open.to_warehouse_id)}</b>
          <table style={{ width: '100%', borderCollapse: 'collapse', marginTop: 8 }}>
            <thead><tr><th style={th}>Item</th><th style={th}>Qty</th><th style={th}></th></tr></thead>
            <tbody>{lines.map((l, i) => (
              <tr key={i}>
                <td style={td}><select style={inp} value={l.itemId} onChange={(e) => setLines(lines.map((x, j) => j === i ? { ...x, itemId: e.target.value } : x))}>
                  <option value="">Item…</option>{items.map((it) => <option key={it.id} value={it.id}>{it.item_no} {it.name}</option>)}
                </select></td>
                <td style={td}><input style={{ ...inp, width: 100 }} type="number" value={l.qty || ''} onChange={(e) => setLines(lines.map((x, j) => j === i ? { ...x, qty: +e.target.value } : x))} /></td>
                <td style={td}><button style={{ ...btn, background: '#fee2e2', color: '#b91c1c' }} onClick={() => setLines(lines.filter((_, j) => j !== i))}>×</button></td>
              </tr>
            ))}</tbody>
          </table>
          <div style={{ display: 'flex', gap: 8, marginTop: 10, alignItems: 'center' }}>
            <button style={{ ...btn, background: '#e2e8f0', color: '#334155' }} onClick={() => setLines([...lines, { itemId: '', qty: 0 }])}>+ line</button>
            <button style={btn} onClick={() => api('/inv/transfers/' + open.id + '/lines', { method: 'PUT', body: { lines }, entityId }).then(load).catch((e) => setErr(e.message))}>Save lines</button>
            <button style={{ ...btn, background: '#166534' }} disabled={!lines.length || lines.some((l) => !l.itemId || l.qty <= 0)}
              onClick={() => api('/inv/transfers/' + open.id + '/lines', { method: 'PUT', body: { lines }, entityId })
                .then(() => api('/inv/transfers/' + open.id + '/post', { method: 'POST', body: {}, entityId }))
                .then(() => { setOpenId(''); setLines([]); load() }).catch((e) => setErr(e.message))}>Post</button>
          </div>
        </div>
      )}
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>No</th><th style={th}>Date</th><th style={th}>From</th><th style={th}>To</th><th style={th}>Description</th><th style={th}>Qty</th><th style={th}>Status</th></tr></thead>
        <tbody>{journals.map((j) => (
          <tr key={j.id} onClick={() => { if (j.status === 'draft') { setOpenId(j.id); api<Journal & { lines: { item_id: string; qty: number }[] }>('/inv/transfers/' + j.id, { entityId }).then((d) => setLines((d.lines ?? []).map((l) => ({ itemId: l.item_id, qty: +l.qty })))) } }}
            style={{ cursor: j.status === 'draft' ? 'pointer' : 'default', background: j.id === openId ? '#f8fafc' : undefined }}>
            <td style={td}><b>{j.journal_no}</b></td><td style={td}>{j.journal_date}</td><td style={td}>{whName(j.from_warehouse_id)}</td><td style={td}>{whName(j.to_warehouse_id)}</td>
            <td style={td}>{j.description ?? ''}</td><td style={num}>{fmtQty(j.total_qty)}</td>
            <td style={td}>{j.status === 'posted' ? '✅ posted' : j.status}</td>
          </tr>
        ))}</tbody>
      </table>
    </div>
  )
}

function MovementTab({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [journals, setJournals] = useState<Journal[]>([])
  const [items, setItems] = useState<Item[]>([])
  const [warehouses, setWarehouses] = useState<Warehouse[]>([])
  const [openId, setOpenId] = useState('')
  const [lines, setLines] = useState<MLine[]>([])
  const [desc, setDesc] = useState('')
  const load = () => {
    api<Journal[]>('/inv/movements', { entityId }).then(setJournals).catch((e) => setErr(e.message))
    api<Item[]>('/inv/items', { entityId }).then(setItems).catch(() => {})
    api<Warehouse[]>('/inv/warehouses', { entityId }).then(setWarehouses).catch(() => {})
  }
  useEffect(() => { load() }, [entityId])
  const open = journals.find((j) => j.id === openId)
  return (
    <div>
      <div style={box}>
        <div style={{ display: 'flex', gap: 8 }}>
          <input style={{ ...inp, flex: 1 }} placeholder="New movement journal description (positive qty = in, negative = out)" value={desc} onChange={(e) => setDesc(e.target.value)} />
          <button style={btn} onClick={() => api<Journal>('/inv/movements', { method: 'POST', body: { description: desc }, entityId }).then((j) => { setDesc(''); setOpenId(j.id); setLines([]); load() }).catch((e) => setErr(e.message))}>Create draft</button>
        </div>
      </div>
      {open && open.status === 'draft' && (
        <div style={box}>
          <b style={{ fontSize: 14 }}>{open.journal_no} — lines (signed qty)</b>
          <table style={{ width: '100%', borderCollapse: 'collapse', marginTop: 8 }}>
            <thead><tr><th style={th}>Item</th><th style={th}>Warehouse</th><th style={th}>Qty (±)</th><th style={th}>Reason</th><th style={th}></th></tr></thead>
            <tbody>{lines.map((l, i) => (
              <tr key={i}>
                <td style={td}><select style={inp} value={l.itemId} onChange={(e) => setLines(lines.map((x, j) => j === i ? { ...x, itemId: e.target.value } : x))}>
                  <option value="">Item…</option>{items.map((it) => <option key={it.id} value={it.id}>{it.item_no} {it.name}</option>)}
                </select></td>
                <td style={td}><select style={inp} value={l.warehouseId} onChange={(e) => setLines(lines.map((x, j) => j === i ? { ...x, warehouseId: e.target.value } : x))}>
                  <option value="">Warehouse…</option>{warehouses.map((w) => <option key={w.id} value={w.id}>{w.warehouse_no} {w.name}</option>)}
                </select></td>
                <td style={td}><input style={{ ...inp, width: 100 }} type="number" value={l.qty || ''} onChange={(e) => setLines(lines.map((x, j) => j === i ? { ...x, qty: +e.target.value } : x))} /></td>
                <td style={td}><input style={inp} placeholder="e.g. opening stock, damage" value={l.reason ?? ''} onChange={(e) => setLines(lines.map((x, j) => j === i ? { ...x, reason: e.target.value } : x))} /></td>
                <td style={td}><button style={{ ...btn, background: '#fee2e2', color: '#b91c1c' }} onClick={() => setLines(lines.filter((_, j) => j !== i))}>×</button></td>
              </tr>
            ))}</tbody>
          </table>
          <div style={{ display: 'flex', gap: 8, marginTop: 10, alignItems: 'center' }}>
            <button style={{ ...btn, background: '#e2e8f0', color: '#334155' }} onClick={() => setLines([...lines, { itemId: '', warehouseId: '', qty: 0 }])}>+ line</button>
            <button style={btn} onClick={() => api('/inv/movements/' + open.id + '/lines', { method: 'PUT', body: { lines }, entityId }).then(load).catch((e) => setErr(e.message))}>Save lines</button>
            <button style={{ ...btn, background: '#166534' }} disabled={!lines.length || lines.some((l) => !l.itemId || !l.warehouseId || !l.qty)}
              onClick={() => api('/inv/movements/' + open.id + '/lines', { method: 'PUT', body: { lines }, entityId })
                .then(() => api('/inv/movements/' + open.id + '/post', { method: 'POST', body: {}, entityId }))
                .then(() => { setOpenId(''); setLines([]); load() }).catch((e) => setErr(e.message))}>Post</button>
          </div>
        </div>
      )}
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>No</th><th style={th}>Date</th><th style={th}>Description</th><th style={th}>Net qty</th><th style={th}>Status</th></tr></thead>
        <tbody>{journals.map((j) => (
          <tr key={j.id} onClick={() => { if (j.status === 'draft') { setOpenId(j.id); api<Journal & { lines: { item_id: string; warehouse_id: string; qty: number; reason?: string }[] }>('/inv/movements/' + j.id, { entityId }).then((d) => setLines((d.lines ?? []).map((l) => ({ itemId: l.item_id, warehouseId: l.warehouse_id, qty: +l.qty, reason: l.reason ?? undefined })))) } }}
            style={{ cursor: j.status === 'draft' ? 'pointer' : 'default', background: j.id === openId ? '#f8fafc' : undefined }}>
            <td style={td}><b>{j.journal_no}</b></td><td style={td}>{j.journal_date}</td><td style={td}>{j.description ?? ''}</td>
            <td style={num}>{fmtQty(j.total_qty)}</td>
            <td style={td}>{j.status === 'posted' ? '✅ posted' : j.status}</td>
          </tr>
        ))}</tbody>
      </table>
    </div>
  )
}
