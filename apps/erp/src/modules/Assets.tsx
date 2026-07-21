import { useEffect, useState } from 'react'
import { api } from '../lib/api'

type Asset = {
  id: string; asset_no: string; name: string; category?: string; acquisition_date: string
  cost: number; method: 'straight_line' | 'wdv'; rate_percent: number; useful_life_months: number
  salvage_value: number; accumulated_depreciation: number; status: string
  disposal?: { proceeds: number; gain_loss: number; date: string } | null
}
type ScheduleRow = { monthNo: number; amount: number; accumulatedAfter: number; bookValueAfter: number }
type AssetDetail = Asset & { book_value: number; schedule: ScheduleRow[] }
type Run = { id: string; period_code: string; status: string; total_amount: number; voucher_id?: string }
type RunLine = {
  id: string; amount: number; book_value_before: number; book_value_after: number
  assets?: { asset_no: string; name: string }
}
type RunDetail = Run & { lines: RunLine[] }
type RegisterRow = Asset & { book_value: number }

const TABS = ['Register', 'Depreciation', 'Reports'] as const
const box: React.CSSProperties = { border: '1px solid #e2e8f0', borderRadius: 8, padding: 16, marginBottom: 16 }
const th: React.CSSProperties = { textAlign: 'left', padding: '6px 10px', background: '#f1f5f9', fontSize: 13 }
const td: React.CSSProperties = { padding: '6px 10px', borderTop: '1px solid #e2e8f0', fontSize: 13 }
const num: React.CSSProperties = { ...td, textAlign: 'right', fontVariantNumeric: 'tabular-nums' }
const inp: React.CSSProperties = { padding: '6px 8px', border: '1px solid #cbd5e1', borderRadius: 6, fontSize: 13 }
const btn: React.CSSProperties = { padding: '6px 12px', border: 0, borderRadius: 6, background: '#0b1320', color: '#fff', cursor: 'pointer', fontSize: 13 }
const fmt = (n: number) => Number(n ?? 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })
const bookValue = (a: Asset) => Number(a.cost) - Number(a.accumulated_depreciation)

function downloadCsv(name: string, headers: string[], rows: (string | number)[][]) {
  const esc = (v: string | number) => `"${String(v ?? '').replace(/"/g, '""')}"`
  const csv = [headers.map(esc).join(','), ...rows.map((r) => r.map(esc).join(','))].join('\n')
  const a = document.createElement('a')
  a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv' }))
  a.download = `${name}.csv`
  a.click()
}

export function Assets({ entityId }: { entityId: string }) {
  const [tab, setTab] = useState<(typeof TABS)[number]>('Register')
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
      {tab === 'Register' && <Register entityId={entityId} setErr={setErr} />}
      {tab === 'Depreciation' && <Depreciation entityId={entityId} setErr={setErr} />}
      {tab === 'Reports' && <Reports entityId={entityId} setErr={setErr} />}
    </div>
  )
}

// ------------------------------------------------------------ Register
const emptyForm = { name: '', category: '', acquisitionDate: '', cost: '', method: 'straight_line', ratePercent: '15', usefulLifeMonths: '60', salvageValue: '0' }

function Register({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [rows, setRows] = useState<Asset[]>([])
  const [form, setForm] = useState(emptyForm)
  const [detail, setDetail] = useState<AssetDetail | null>(null)
  const load = () => api<Asset[]>('/assets/assets', { entityId }).then(setRows).catch((e) => setErr(e.message))
  useEffect(() => { load(); setDetail(null) }, [entityId])
  const openAsset = (id: string) =>
    api<AssetDetail>('/assets/assets/' + id, { entityId }).then(setDetail).catch((e) => setErr(e.message))
  const dispose = (a: AssetDetail) => {
    const p = prompt(`Sale proceeds for ${a.asset_no} — ${a.name} (book value ${fmt(a.book_value)})?`, '0')
    if (p === null) return
    if (Number.isNaN(+p) || +p < 0) { setErr('proceeds must be a number >= 0'); return }
    api('/assets/assets/' + a.id + '/dispose', { method: 'POST', body: { proceeds: +p }, entityId })
      .then(() => { load(); openAsset(a.id) }).catch((e) => setErr(e.message))
  }
  return (
    <div>
      <div style={box}>
        <b style={{ fontSize: 14 }}>New asset (asset no is allocated automatically)</b>
        <div style={{ display: 'flex', gap: 8, marginTop: 10, flexWrap: 'wrap', alignItems: 'flex-end' }}>
          <input style={{ ...inp, flex: 1, minWidth: 160 }} placeholder="Name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
          <input style={inp} placeholder="Category" value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })} />
          <input style={inp} type="date" title="Acquisition date" value={form.acquisitionDate} onChange={(e) => setForm({ ...form, acquisitionDate: e.target.value })} />
          <input style={{ ...inp, width: 110 }} type="number" placeholder="Cost" value={form.cost} onChange={(e) => setForm({ ...form, cost: e.target.value })} />
          <select style={inp} value={form.method} onChange={(e) => setForm({ ...form, method: e.target.value })}>
            <option value="straight_line">Straight line</option>
            <option value="wdv">WDV</option>
          </select>
          {form.method === 'wdv'
            ? <input style={{ ...inp, width: 90 }} type="number" title="WDV rate % p.a." placeholder="Rate %" value={form.ratePercent} onChange={(e) => setForm({ ...form, ratePercent: e.target.value })} />
            : <input style={{ ...inp, width: 100 }} type="number" title="Useful life (months)" placeholder="Life (months)" value={form.usefulLifeMonths} onChange={(e) => setForm({ ...form, usefulLifeMonths: e.target.value })} />}
          <input style={{ ...inp, width: 100 }} type="number" title="Salvage value" placeholder="Salvage" value={form.salvageValue} onChange={(e) => setForm({ ...form, salvageValue: e.target.value })} />
          <button style={btn} disabled={!form.name || !form.cost}
            onClick={() => api<Asset>('/assets/assets', {
              method: 'POST', entityId,
              body: {
                name: form.name, category: form.category || null, acquisitionDate: form.acquisitionDate || undefined,
                cost: +form.cost, method: form.method, ratePercent: +form.ratePercent || 15,
                usefulLifeMonths: +form.usefulLifeMonths || 60, salvageValue: +form.salvageValue || 0,
              },
            }).then((a) => { setForm(emptyForm); load(); openAsset(a.id) }).catch((e) => setErr(e.message))}>Create</button>
        </div>
      </div>
      {detail && (
        <div style={box}>
          <div style={{ display: 'flex', gap: 12, alignItems: 'center', flexWrap: 'wrap' }}>
            <b style={{ fontSize: 14 }}>{detail.asset_no} — {detail.name} ({detail.status})</b>
            <span style={{ fontSize: 13 }}>
              Cost <b>{fmt(+detail.cost)}</b> · Accum. dep. <b>{fmt(+detail.accumulated_depreciation)}</b> · Book value <b>{fmt(+detail.book_value)}</b> ·
              {detail.method === 'straight_line' ? ` SL over ${detail.useful_life_months} months` : ` WDV ${detail.rate_percent}% p.a.`}
            </span>
            {detail.status === 'active' && <button style={{ ...btn, background: '#991b1b' }} onClick={() => dispose(detail)}>Dispose…</button>}
            <button style={{ ...btn, background: '#e2e8f0', color: '#334155' }} onClick={() => setDetail(null)}>Close</button>
          </div>
          {detail.disposal && (
            <p style={{ fontSize: 13, marginBottom: 0 }}>
              Disposed {detail.disposal.date} — proceeds {fmt(+detail.disposal.proceeds)},{' '}
              {+detail.disposal.gain_loss >= 0 ? `gain ${fmt(+detail.disposal.gain_loss)}` : `loss ${fmt(-detail.disposal.gain_loss)}`}
            </p>
          )}
          {detail.status === 'active' && (
            <div style={{ marginTop: 12 }}>
              <b style={{ fontSize: 13 }}>Depreciation schedule preview (from current book value, max 120 months)</b>
              <table style={{ width: '100%', borderCollapse: 'collapse', marginTop: 6 }}>
                <thead><tr><th style={th}>Month</th><th style={th}>Depreciation</th><th style={th}>Accumulated</th><th style={th}>Book value</th></tr></thead>
                <tbody>{detail.schedule.slice(0, 24).map((s) => (
                  <tr key={s.monthNo}>
                    <td style={td}>{s.monthNo}</td><td style={num}>{fmt(s.amount)}</td>
                    <td style={num}>{fmt(s.accumulatedAfter)}</td><td style={num}>{fmt(s.bookValueAfter)}</td>
                  </tr>
                ))}</tbody>
              </table>
              {detail.schedule.length > 24 && <p style={{ fontSize: 12, color: '#94a3b8' }}>… {detail.schedule.length - 24} more months until fully depreciated.</p>}
              {detail.schedule.length === 0 && <p style={{ fontSize: 13, color: '#94a3b8' }}>Fully depreciated — no future depreciation.</p>}
            </div>
          )}
        </div>
      )}
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>No</th><th style={th}>Name</th><th style={th}>Category</th><th style={th}>Acquired</th><th style={th}>Method</th><th style={th}>Cost</th><th style={th}>Accum. dep.</th><th style={th}>Book value</th><th style={th}>Status</th></tr></thead>
        <tbody>{rows.map((r) => (
          <tr key={r.id} onClick={() => openAsset(r.id)} style={{ cursor: 'pointer', background: detail?.id === r.id ? '#f8fafc' : undefined }}>
            <td style={td}><b>{r.asset_no}</b></td><td style={td}>{r.name}</td><td style={td}>{r.category ?? ''}</td>
            <td style={td}>{r.acquisition_date}</td><td style={td}>{r.method === 'wdv' ? `WDV ${+r.rate_percent}%` : 'SL'}</td>
            <td style={num}>{fmt(+r.cost)}</td><td style={num}>{fmt(+r.accumulated_depreciation)}</td>
            <td style={num}><b>{fmt(bookValue(r))}</b></td>
            <td style={td}>{r.status === 'disposed' ? '🏷️ disposed' : r.status}</td>
          </tr>
        ))}</tbody>
      </table>
      {rows.length === 0 && <p style={{ fontSize: 13, color: '#94a3b8' }}>No assets yet — create the first one above.</p>}
    </div>
  )
}

// ------------------------------------------------------------ Depreciation
function Depreciation({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [runs, setRuns] = useState<Run[]>([])
  const [period, setPeriod] = useState('')
  const [open, setOpen] = useState<RunDetail | null>(null)
  const load = () => api<Run[]>('/assets/runs', { entityId }).then(setRuns).catch((e) => setErr(e.message))
  useEffect(() => { load(); setOpen(null) }, [entityId])
  const openRun = (id: string) =>
    api<RunDetail>('/assets/runs/' + id, { entityId }).then(setOpen).catch((e) => setErr(e.message))
  const act = (path: string) =>
    api('/assets/runs/' + open!.id + path, { method: 'POST', body: {}, entityId })
      .then(() => { load(); openRun(open!.id) }).catch((e) => setErr(e.message))
  return (
    <div>
      <div style={box}>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <input style={inp} type="month" value={period} onChange={(e) => setPeriod(e.target.value)} />
          <button style={btn} disabled={!period}
            onClick={() => api<Run>('/assets/runs', { method: 'POST', body: { periodCode: period }, entityId })
              .then((r) => { setPeriod(''); load(); openRun(r.id) }).catch((e) => setErr(e.message))}>Create run</button>
          <span style={{ fontSize: 13, color: '#64748b' }}>One run per entity per month. Generate computes SL/WDV per active asset; Post writes Dr 5400 / Cr 1510.</span>
        </div>
      </div>
      {open && (
        <div style={box}>
          <div style={{ display: 'flex', gap: 12, alignItems: 'center', flexWrap: 'wrap' }}>
            <b style={{ fontSize: 14 }}>Depreciation {open.period_code} ({open.status})</b>
            {open.status === 'draft' && <button style={btn} onClick={() => act('/generate')}>Generate</button>}
            {open.status === 'draft' && <button style={{ ...btn, background: '#166534' }} disabled={!open.lines.length} onClick={() => act('/post')}>Post to GL</button>}
            <span style={{ fontSize: 13 }}>Total <b>{fmt(+open.total_amount)}</b></span>
            <button style={{ ...btn, background: '#e2e8f0', color: '#334155' }} onClick={() => setOpen(null)}>Close</button>
          </div>
          <table style={{ width: '100%', borderCollapse: 'collapse', marginTop: 10 }}>
            <thead><tr><th style={th}>Asset</th><th style={th}>Book value before</th><th style={th}>Depreciation</th><th style={th}>Book value after</th></tr></thead>
            <tbody>{open.lines.map((l) => (
              <tr key={l.id}>
                <td style={td}><b>{l.assets?.asset_no}</b> {l.assets?.name}</td>
                <td style={num}>{fmt(+l.book_value_before)}</td>
                <td style={num}>{fmt(+l.amount)}</td>
                <td style={num}>{fmt(+l.book_value_after)}</td>
              </tr>
            ))}</tbody>
          </table>
          {open.lines.length === 0 && <p style={{ fontSize: 13, color: '#94a3b8' }}>No lines yet — hit Generate (needs active assets acquired on or before the period end).</p>}
        </div>
      )}
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>Period</th><th style={th}>Status</th><th style={th}>Total</th></tr></thead>
        <tbody>{runs.map((r) => (
          <tr key={r.id} onClick={() => openRun(r.id)} style={{ cursor: 'pointer', background: open?.id === r.id ? '#f8fafc' : undefined }}>
            <td style={td}><b>{r.period_code}</b></td>
            <td style={td}>{r.status === 'posted' ? '✅ posted' : r.status}</td>
            <td style={num}>{fmt(+r.total_amount)}</td>
          </tr>
        ))}</tbody>
      </table>
    </div>
  )
}

// ------------------------------------------------------------ Reports
function Reports({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [rows, setRows] = useState<RegisterRow[]>([])
  const run = () => api<RegisterRow[]>('/assets/reports/register', { entityId }).then(setRows).catch((e) => setErr(e.message))
  useEffect(() => { run() }, [entityId])
  const tot = (k: 'cost' | 'accumulated_depreciation' | 'book_value') => rows.reduce((s, r) => s + Number(r[k] ?? 0), 0)
  return (
    <div>
      <div style={{ display: 'flex', gap: 8, marginBottom: 12, alignItems: 'center' }}>
        <b style={{ fontSize: 14 }}>Fixed asset register</b>
        <button style={btn} onClick={run}>Refresh</button>
        <button style={{ ...btn, background: '#e2e8f0', color: '#334155' }} disabled={!rows.length}
          onClick={() => downloadCsv('asset-register',
            ['Asset no', 'Name', 'Category', 'Acquired', 'Method', 'Rate %', 'Life (months)', 'Cost', 'Salvage', 'Accumulated depreciation', 'Book value', 'Status'],
            rows.map((r) => [r.asset_no, r.name, r.category ?? '', r.acquisition_date, r.method, r.rate_percent, r.useful_life_months, r.cost, r.salvage_value, r.accumulated_depreciation, r.book_value, r.status]))}>
          Download CSV</button>
        <span style={{ fontSize: 13 }}>Assets <b>{rows.length}</b> · Cost <b>{fmt(tot('cost'))}</b> · Book value <b>{fmt(tot('book_value'))}</b></span>
      </div>
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>No</th><th style={th}>Name</th><th style={th}>Category</th><th style={th}>Acquired</th><th style={th}>Method</th><th style={th}>Cost</th><th style={th}>Accum. dep.</th><th style={th}>Book value</th><th style={th}>Status</th></tr></thead>
        <tbody>{rows.map((r) => (
          <tr key={r.id}>
            <td style={td}><b>{r.asset_no}</b></td><td style={td}>{r.name}</td><td style={td}>{r.category ?? ''}</td>
            <td style={td}>{r.acquisition_date}</td><td style={td}>{r.method === 'wdv' ? `WDV ${+r.rate_percent}%` : 'SL'}</td>
            <td style={num}>{fmt(+r.cost)}</td><td style={num}>{fmt(+r.accumulated_depreciation)}</td>
            <td style={num}><b>{fmt(+r.book_value)}</b></td><td style={td}>{r.status}</td>
          </tr>
        ))}</tbody>
      </table>
      {rows.length === 0 && <p style={{ fontSize: 13, color: '#94a3b8' }}>No assets in the register.</p>}
    </div>
  )
}
