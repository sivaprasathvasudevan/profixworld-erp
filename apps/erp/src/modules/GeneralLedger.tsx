import { useEffect, useState } from 'react'
import { api } from '../lib/api'

type Group = { id: string; code: string; name: string; kind: string }
type Account = { id: string; account_no: string; name: string; active: boolean; ledger_groups?: { code: string; name: string; kind: string } }
type Journal = { id: string; journal_no: string; journal_date: string; description?: string; status: string; total_debit: number; total_credit: number }
type JLine = { accountId: string; debit: number; credit: number; memo?: string }
type Voucher = { id: string; voucher_no: string; voucher_date: string; source_module: string; description?: string }
type VLine = { line_no: number; debit: number; credit: number; memo?: string; ledger_accounts?: { account_no: string; name: string } }
type TBRow = { account_no: string; account_name: string; group_name: string; kind: string; debit: number; credit: number }
type Profile = { id: string; module: string; event: string; debit_account_id?: string; credit_account_id?: string }

const TABS = ['Chart of accounts', 'Journal', 'Vouchers', 'Posting profiles', 'Reports'] as const
const box: React.CSSProperties = { border: '1px solid #e2e8f0', borderRadius: 8, padding: 16, marginBottom: 16 }
const th: React.CSSProperties = { textAlign: 'left', padding: '6px 10px', background: '#f1f5f9', fontSize: 13 }
const td: React.CSSProperties = { padding: '6px 10px', borderTop: '1px solid #e2e8f0', fontSize: 13 }
const num: React.CSSProperties = { ...td, textAlign: 'right', fontVariantNumeric: 'tabular-nums' }
const inp: React.CSSProperties = { padding: '6px 8px', border: '1px solid #cbd5e1', borderRadius: 6, fontSize: 13 }
const btn: React.CSSProperties = { padding: '6px 12px', border: 0, borderRadius: 6, background: '#0b1320', color: '#fff', cursor: 'pointer', fontSize: 13 }
const fmt = (n: number) => Number(n ?? 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })

function downloadCsv(name: string, headers: string[], rows: (string | number)[][]) {
  const esc = (v: string | number) => `"${String(v ?? '').replace(/"/g, '""')}"`
  const csv = [headers.map(esc).join(','), ...rows.map((r) => r.map(esc).join(','))].join('\n')
  const a = document.createElement('a')
  a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv' }))
  a.download = `${name}.csv`
  a.click()
}

export function GeneralLedger({ entityId }: { entityId: string }) {
  const [tab, setTab] = useState<(typeof TABS)[number]>('Chart of accounts')
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
      {tab === 'Chart of accounts' && <Accounts entityId={entityId} setErr={setErr} />}
      {tab === 'Journal' && <JournalTab entityId={entityId} setErr={setErr} />}
      {tab === 'Vouchers' && <Vouchers entityId={entityId} setErr={setErr} />}
      {tab === 'Posting profiles' && <Profiles entityId={entityId} setErr={setErr} />}
      {tab === 'Reports' && <Reports entityId={entityId} setErr={setErr} />}
    </div>
  )
}

function Accounts({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [rows, setRows] = useState<Account[]>([])
  const [groups, setGroups] = useState<Group[]>([])
  const [form, setForm] = useState({ accountNo: '', name: '', groupId: '' })
  const load = () => {
    api<Account[]>('/gl/accounts', { entityId }).then(setRows).catch((e) => setErr(e.message))
    api<Group[]>('/gl/groups', { entityId }).then(setGroups).catch(() => {})
  }
  useEffect(() => { load() }, [entityId])
  return (
    <div>
      <div style={box}>
        <b style={{ fontSize: 14 }}>New ledger account</b>
        <div style={{ display: 'flex', gap: 8, marginTop: 10 }}>
          <input style={inp} placeholder="Account no (e.g. 5310)" value={form.accountNo} onChange={(e) => setForm({ ...form, accountNo: e.target.value })} />
          <input style={{ ...inp, flex: 1 }} placeholder="Name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
          <select style={inp} value={form.groupId} onChange={(e) => setForm({ ...form, groupId: e.target.value })}>
            <option value="">Group…</option>{groups.map((g) => <option key={g.id} value={g.id}>{g.code} {g.name}</option>)}
          </select>
          <button style={btn} onClick={() => api('/gl/accounts', { method: 'POST', body: form, entityId }).then(() => { setForm({ accountNo: '', name: '', groupId: '' }); load() }).catch((e) => setErr(e.message))}>Create</button>
        </div>
      </div>
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>No</th><th style={th}>Name</th><th style={th}>Group</th><th style={th}>Kind</th><th style={th}>Active</th></tr></thead>
        <tbody>{rows.map((r) => (
          <tr key={r.id}><td style={td}><b>{r.account_no}</b></td><td style={td}>{r.name}</td><td style={td}>{r.ledger_groups?.code} {r.ledger_groups?.name}</td><td style={td}>{r.ledger_groups?.kind}</td><td style={td}>{r.active ? 'Yes' : 'No'}</td></tr>
        ))}</tbody>
      </table>
    </div>
  )
}

function JournalTab({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [journals, setJournals] = useState<Journal[]>([])
  const [accounts, setAccounts] = useState<Account[]>([])
  const [openId, setOpenId] = useState<string>('')
  const [lines, setLines] = useState<JLine[]>([])
  const [desc, setDesc] = useState('')
  const load = () => {
    api<Journal[]>('/gl/journals', { entityId }).then(setJournals).catch((e) => setErr(e.message))
    api<Account[]>('/gl/accounts', { entityId }).then(setAccounts).catch(() => {})
  }
  useEffect(() => { load() }, [entityId])
  const dr = lines.reduce((s, l) => s + (+l.debit || 0), 0)
  const cr = lines.reduce((s, l) => s + (+l.credit || 0), 0)
  const open = journals.find((j) => j.id === openId)
  return (
    <div>
      <div style={box}>
        <div style={{ display: 'flex', gap: 8 }}>
          <input style={{ ...inp, flex: 1 }} placeholder="New journal description" value={desc} onChange={(e) => setDesc(e.target.value)} />
          <button style={btn} onClick={() => api<Journal>('/gl/journals', { method: 'POST', body: { description: desc }, entityId }).then((j) => { setDesc(''); setOpenId(j.id); setLines([]); load() }).catch((e) => setErr(e.message))}>Create draft</button>
        </div>
      </div>
      {open && open.status === 'draft' && (
        <div style={box}>
          <b style={{ fontSize: 14 }}>{open.journal_no} — lines</b>
          <table style={{ width: '100%', borderCollapse: 'collapse', marginTop: 8 }}>
            <thead><tr><th style={th}>Account</th><th style={th}>Debit</th><th style={th}>Credit</th><th style={th}>Memo</th><th style={th}></th></tr></thead>
            <tbody>{lines.map((l, i) => (
              <tr key={i}>
                <td style={td}><select style={inp} value={l.accountId} onChange={(e) => setLines(lines.map((x, j) => j === i ? { ...x, accountId: e.target.value } : x))}>
                  <option value="">Account…</option>{accounts.map((a) => <option key={a.id} value={a.id}>{a.account_no} {a.name}</option>)}
                </select></td>
                <td style={td}><input style={{ ...inp, width: 100 }} type="number" value={l.debit || ''} onChange={(e) => setLines(lines.map((x, j) => j === i ? { ...x, debit: +e.target.value, credit: 0 } : x))} /></td>
                <td style={td}><input style={{ ...inp, width: 100 }} type="number" value={l.credit || ''} onChange={(e) => setLines(lines.map((x, j) => j === i ? { ...x, credit: +e.target.value, debit: 0 } : x))} /></td>
                <td style={td}><input style={inp} value={l.memo ?? ''} onChange={(e) => setLines(lines.map((x, j) => j === i ? { ...x, memo: e.target.value } : x))} /></td>
                <td style={td}><button style={{ ...btn, background: '#fee2e2', color: '#b91c1c' }} onClick={() => setLines(lines.filter((_, j) => j !== i))}>×</button></td>
              </tr>
            ))}</tbody>
          </table>
          <div style={{ display: 'flex', gap: 8, marginTop: 10, alignItems: 'center' }}>
            <button style={{ ...btn, background: '#e2e8f0', color: '#334155' }} onClick={() => setLines([...lines, { accountId: '', debit: 0, credit: 0 }])}>+ line</button>
            <span style={{ fontSize: 13 }}>Dr <b>{fmt(dr)}</b> / Cr <b>{fmt(cr)}</b> {Math.round(dr * 100) !== Math.round(cr * 100) && <span style={{ color: '#b91c1c' }}>— not balanced</span>}</span>
            <button style={btn} onClick={() => api('/gl/journals/' + open.id + '/lines', { method: 'PUT', body: { lines }, entityId }).then(load).catch((e) => setErr(e.message))}>Save lines</button>
            <button style={{ ...btn, background: '#166534' }} disabled={Math.round(dr * 100) !== Math.round(cr * 100) || dr === 0}
              onClick={() => api('/gl/journals/' + open.id + '/lines', { method: 'PUT', body: { lines }, entityId })
                .then(() => api('/gl/journals/' + open.id + '/post', { method: 'POST', body: {}, entityId }))
                .then(() => { setOpenId(''); setLines([]); load() }).catch((e) => setErr(e.message))}>Post</button>
          </div>
        </div>
      )}
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>No</th><th style={th}>Date</th><th style={th}>Description</th><th style={th}>Debit</th><th style={th}>Credit</th><th style={th}>Status</th></tr></thead>
        <tbody>{journals.map((j) => (
          <tr key={j.id} onClick={() => { if (j.status === 'draft') { setOpenId(j.id); api<Journal & { lines: { account_id: string; debit: number; credit: number; memo?: string }[] }>('/gl/journals/' + j.id, { entityId }).then((d) => setLines((d.lines ?? []).map((l) => ({ accountId: l.account_id, debit: +l.debit, credit: +l.credit, memo: l.memo ?? undefined })))) } }}
            style={{ cursor: j.status === 'draft' ? 'pointer' : 'default', background: j.id === openId ? '#f8fafc' : undefined }}>
            <td style={td}><b>{j.journal_no}</b></td><td style={td}>{j.journal_date}</td><td style={td}>{j.description ?? ''}</td>
            <td style={num}>{fmt(j.total_debit)}</td><td style={num}>{fmt(j.total_credit)}</td>
            <td style={td}>{j.status === 'posted' ? '✅ posted' : j.status}</td>
          </tr>
        ))}</tbody>
      </table>
    </div>
  )
}

function Vouchers({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [rows, setRows] = useState<Voucher[]>([])
  const [openV, setOpenV] = useState<(Voucher & { lines: VLine[] }) | null>(null)
  useEffect(() => { api<Voucher[]>('/gl/vouchers', { entityId }).then(setRows).catch((e) => setErr(e.message)) }, [entityId])
  return (
    <div>
      {openV && (
        <div style={box}>
          <b style={{ fontSize: 14 }}>{openV.voucher_no} — {openV.voucher_date} ({openV.source_module})</b>
          <table style={{ width: '100%', borderCollapse: 'collapse', marginTop: 8 }}>
            <thead><tr><th style={th}>#</th><th style={th}>Account</th><th style={th}>Debit</th><th style={th}>Credit</th><th style={th}>Memo</th></tr></thead>
            <tbody>{openV.lines.map((l) => (
              <tr key={l.line_no}><td style={td}>{l.line_no}</td><td style={td}>{l.ledger_accounts?.account_no} {l.ledger_accounts?.name}</td><td style={num}>{fmt(l.debit)}</td><td style={num}>{fmt(l.credit)}</td><td style={td}>{l.memo ?? ''}</td></tr>
            ))}</tbody>
          </table>
          <button style={{ ...btn, marginTop: 8, background: '#e2e8f0', color: '#334155' }} onClick={() => setOpenV(null)}>Close</button>
        </div>
      )}
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>No</th><th style={th}>Date</th><th style={th}>Source</th><th style={th}>Description</th></tr></thead>
        <tbody>{rows.map((v) => (
          <tr key={v.id} onClick={() => api<Voucher & { lines: VLine[] }>('/gl/vouchers/' + v.id, { entityId }).then(setOpenV).catch((e) => setErr(e.message))} style={{ cursor: 'pointer' }}>
            <td style={td}><b>{v.voucher_no}</b></td><td style={td}>{v.voucher_date}</td><td style={td}>{v.source_module}</td><td style={td}>{v.description ?? ''}</td>
          </tr>
        ))}</tbody>
      </table>
    </div>
  )
}

function Profiles({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [rows, setRows] = useState<Profile[]>([])
  const [accounts, setAccounts] = useState<Account[]>([])
  const [form, setForm] = useState({ module: 'sales', event: 'invoice', debitAccountId: '', creditAccountId: '' })
  const load = () => {
    api<Profile[]>('/gl/profiles', { entityId }).then(setRows).catch((e) => setErr(e.message))
    api<Account[]>('/gl/accounts', { entityId }).then(setAccounts).catch(() => {})
  }
  useEffect(() => { load() }, [entityId])
  const accName = (id?: string) => { const a = accounts.find((x) => x.id === id); return a ? `${a.account_no} ${a.name}` : '—' }
  return (
    <div>
      <div style={box}>
        <b style={{ fontSize: 14 }}>Set posting profile</b>
        <div style={{ display: 'flex', gap: 8, marginTop: 10, flexWrap: 'wrap' }}>
          <select style={inp} value={form.module} onChange={(e) => setForm({ ...form, module: e.target.value })}>
            {['sales', 'purchase', 'inventory', 'payroll', 'asset', 'service'].map((m) => <option key={m}>{m}</option>)}
          </select>
          <input style={inp} placeholder="Event (e.g. invoice)" value={form.event} onChange={(e) => setForm({ ...form, event: e.target.value })} />
          <select style={inp} value={form.debitAccountId} onChange={(e) => setForm({ ...form, debitAccountId: e.target.value })}>
            <option value="">Debit account…</option>{accounts.map((a) => <option key={a.id} value={a.id}>{a.account_no} {a.name}</option>)}
          </select>
          <select style={inp} value={form.creditAccountId} onChange={(e) => setForm({ ...form, creditAccountId: e.target.value })}>
            <option value="">Credit account…</option>{accounts.map((a) => <option key={a.id} value={a.id}>{a.account_no} {a.name}</option>)}
          </select>
          <button style={btn} onClick={() => api('/gl/profiles', { method: 'POST', body: form, entityId }).then(load).catch((e) => setErr(e.message))}>Save</button>
        </div>
      </div>
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>Module</th><th style={th}>Event</th><th style={th}>Debit</th><th style={th}>Credit</th></tr></thead>
        <tbody>{rows.map((p) => (
          <tr key={p.id}><td style={td}>{p.module}</td><td style={td}>{p.event}</td><td style={td}>{accName(p.debit_account_id)}</td><td style={td}>{accName(p.credit_account_id)}</td></tr>
        ))}</tbody>
      </table>
    </div>
  )
}

function Reports({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const today = new Date().toISOString().slice(0, 10)
  const [from, setFrom] = useState('2026-04-01')
  const [to, setTo] = useState(today)
  const [tb, setTb] = useState<TBRow[]>([])
  const run = () => api<TBRow[]>(`/gl/reports/trial-balance?from=${from}&to=${to}`, { entityId }).then(setTb).catch((e) => setErr(e.message))
  useEffect(() => { run() }, [entityId])
  const totDr = tb.reduce((s, r) => s + +r.debit, 0)
  const totCr = tb.reduce((s, r) => s + +r.credit, 0)
  const pnl = tb.filter((r) => r.kind === 'income' || r.kind === 'expense')
  const income = pnl.filter((r) => r.kind === 'income').reduce((s, r) => s + (+r.credit - +r.debit), 0)
  const expense = pnl.filter((r) => r.kind === 'expense').reduce((s, r) => s + (+r.debit - +r.credit), 0)
  return (
    <div>
      <div style={{ display: 'flex', gap: 8, marginBottom: 12, alignItems: 'center' }}>
        <input style={inp} type="date" value={from} onChange={(e) => setFrom(e.target.value)} />
        <input style={inp} type="date" value={to} onChange={(e) => setTo(e.target.value)} />
        <button style={btn} onClick={run}>Run</button>
        <button style={{ ...btn, background: '#e2e8f0', color: '#334155' }}
          onClick={() => downloadCsv(`trial-balance-${from}-${to}`, ['Account', 'Name', 'Group', 'Kind', 'Debit', 'Credit'], tb.map((r) => [r.account_no, r.account_name, r.group_name, r.kind, r.debit, r.credit]))}>
          Download CSV</button>
      </div>
      <div style={{ display: 'flex', gap: 16, marginBottom: 12, fontSize: 13 }}>
        <div style={box}><b>Trial balance</b><br />Dr {fmt(totDr)} / Cr {fmt(totCr)} {Math.round(totDr * 100) !== Math.round(totCr * 100) && <span style={{ color: '#b91c1c' }}>⚠ unbalanced</span>}</div>
        <div style={box}><b>P&L (period)</b><br />Income {fmt(income)} − Expenses {fmt(expense)} = <b>{fmt(income - expense)}</b></div>
      </div>
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>Account</th><th style={th}>Name</th><th style={th}>Group</th><th style={th}>Debit</th><th style={th}>Credit</th></tr></thead>
        <tbody>{tb.map((r) => (
          <tr key={r.account_no}><td style={td}><b>{r.account_no}</b></td><td style={td}>{r.account_name}</td><td style={td}>{r.group_name}</td><td style={num}>{fmt(+r.debit)}</td><td style={num}>{fmt(+r.credit)}</td></tr>
        ))}</tbody>
      </table>
    </div>
  )
}
