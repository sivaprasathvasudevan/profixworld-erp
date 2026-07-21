import { useEffect, useMemo, useState } from 'react'
import { api } from '../lib/api'

type Entity = { id: string; code: string; name: string; gstin?: string; base_currency: string; active: boolean }
type Seq = { id: string; code: string; prefix: string; suffix: string; next_no: number; padding: number; reset_policy: string }
type UserRow = { id: string; email?: string; lastSignIn?: string; roles: { role_id: string; entity_id: string; erp_roles?: { name: string } }[] }
type Role = { id: string; name: string; description?: string }
type Priv = { code: string; module: string; description?: string }
type RolePriv = { role_id: string; privilege_code: string }
type AuditRow = { id: number; table_name: string; record_id: string; action: string; actor_email?: string; at: string; diff: unknown }

const TABS = ['Entities', 'Number sequences', 'Users', 'Roles', 'Audit log', 'Data import/export'] as const

const box: React.CSSProperties = { border: '1px solid #e2e8f0', borderRadius: 8, padding: 16, marginBottom: 16 }
const th: React.CSSProperties = { textAlign: 'left', padding: '6px 10px', background: '#f1f5f9', fontSize: 13 }
const td: React.CSSProperties = { padding: '6px 10px', borderTop: '1px solid #e2e8f0', fontSize: 13 }
const inp: React.CSSProperties = { padding: '6px 8px', border: '1px solid #cbd5e1', borderRadius: 6, fontSize: 13 }
const btn: React.CSSProperties = { padding: '6px 12px', border: 0, borderRadius: 6, background: '#0b1320', color: '#fff', cursor: 'pointer', fontSize: 13 }

export function SystemAdministration({ entityId, onEntitiesChanged }: { entityId: string; onEntitiesChanged: () => void }) {
  const [tab, setTab] = useState<(typeof TABS)[number]>('Entities')
  const [err, setErr] = useState('')
  return (
    <div>
      <div style={{ display: 'flex', gap: 8, marginBottom: 16, flexWrap: 'wrap' }}>
        {TABS.map((t) => (
          <button key={t} onClick={() => { setTab(t); setErr('') }}
            style={{ ...btn, background: tab === t ? '#0b1320' : '#e2e8f0', color: tab === t ? '#fff' : '#334155' }}>
            {t}
          </button>
        ))}
      </div>
      {err && <div style={{ color: '#b91c1c', marginBottom: 12, fontSize: 13 }}>{err}</div>}
      {tab === 'Entities' && <Entities entityId={entityId} setErr={setErr} onChanged={onEntitiesChanged} />}
      {tab === 'Number sequences' && <Sequences entityId={entityId} setErr={setErr} />}
      {tab === 'Users' && <Users entityId={entityId} setErr={setErr} />}
      {tab === 'Roles' && <Roles entityId={entityId} setErr={setErr} />}
      {tab === 'Audit log' && <Audit entityId={entityId} setErr={setErr} />}
      {tab === 'Data import/export' && <DataIO entityId={entityId} setErr={setErr} />}
    </div>
  )
}

function Entities({ entityId, setErr, onChanged }: { entityId: string; setErr: (s: string) => void; onChanged: () => void }) {
  const [rows, setRows] = useState<Entity[]>([])
  const [form, setForm] = useState({ code: '', name: '', gstin: '' })
  const load = () => api<Entity[]>('/entities').then(setRows).catch((e) => setErr(e.message))
  useEffect(() => { load() }, [])
  return (
    <div>
      <div style={box}>
        <b style={{ fontSize: 14 }}>New legal entity</b>
        <div style={{ display: 'flex', gap: 8, marginTop: 10 }}>
          <input style={inp} placeholder="Code (e.g. PROFIX2)" value={form.code} onChange={(e) => setForm({ ...form, code: e.target.value.toUpperCase() })} />
          <input style={{ ...inp, flex: 1 }} placeholder="Name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
          <input style={inp} placeholder="GSTIN (optional)" value={form.gstin} onChange={(e) => setForm({ ...form, gstin: e.target.value })} />
          <button style={btn} onClick={() =>
            api('/entities', { method: 'POST', body: form, entityId }).then(() => { setForm({ code: '', name: '', gstin: '' }); load(); onChanged() }).catch((e) => setErr(e.message))
          }>Create</button>
        </div>
      </div>
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>Code</th><th style={th}>Name</th><th style={th}>GSTIN</th><th style={th}>Currency</th><th style={th}>Active</th></tr></thead>
        <tbody>{rows.map((r) => (
          <tr key={r.id}><td style={td}><b>{r.code}</b></td><td style={td}>{r.name}</td><td style={td}>{r.gstin ?? '—'}</td><td style={td}>{r.base_currency}</td><td style={td}>{r.active ? 'Yes' : 'No'}</td></tr>
        ))}</tbody>
      </table>
    </div>
  )
}

function Sequences({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [rows, setRows] = useState<Seq[]>([])
  const [form, setForm] = useState({ code: '', prefix: '', padding: 5 })
  const [preview, setPreview] = useState('')
  const load = () => api<Seq[]>('/sequences', { entityId }).then(setRows).catch((e) => setErr(e.message))
  useEffect(() => { load() }, [entityId])
  return (
    <div>
      <div style={box}>
        <b style={{ fontSize: 14 }}>Add / update sequence</b>
        <div style={{ display: 'flex', gap: 8, marginTop: 10 }}>
          <input style={inp} placeholder="Code (e.g. SINV)" value={form.code} onChange={(e) => setForm({ ...form, code: e.target.value.toUpperCase() })} />
          <input style={inp} placeholder="Prefix (e.g. INV-)" value={form.prefix} onChange={(e) => setForm({ ...form, prefix: e.target.value })} />
          <input style={{ ...inp, width: 70 }} type="number" value={form.padding} onChange={(e) => setForm({ ...form, padding: +e.target.value })} />
          <button style={btn} onClick={() => api('/sequences', { method: 'POST', body: form, entityId }).then(load).catch((e) => setErr(e.message))}>Save</button>
        </div>
        {preview && <div style={{ marginTop: 8, fontSize: 13 }}>Allocated test number: <b>{preview}</b></div>}
      </div>
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>Code</th><th style={th}>Prefix</th><th style={th}>Next no</th><th style={th}>Padding</th><th style={th}>Reset</th><th style={th}></th></tr></thead>
        <tbody>{rows.map((r) => (
          <tr key={r.id}>
            <td style={td}><b>{r.code}</b></td><td style={td}>{r.prefix}</td><td style={td}>{r.next_no}</td><td style={td}>{r.padding}</td><td style={td}>{r.reset_policy}</td>
            <td style={td}><button style={{ ...btn, background: '#e2e8f0', color: '#334155' }}
              onClick={() => api<{ number: string }>('/sequences/allocate', { method: 'POST', body: { code: r.code }, entityId }).then((x) => { setPreview(x.number); load() }).catch((e) => setErr(e.message))}>
              Test allocate</button></td>
          </tr>
        ))}</tbody>
      </table>
    </div>
  )
}

function Users({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [rows, setRows] = useState<UserRow[]>([])
  const [roles, setRoles] = useState<Role[]>([])
  const [copy, setCopy] = useState({ from: '', to: '' })
  const load = () => {
    api<UserRow[]>('/users', { entityId }).then(setRows).catch((e) => setErr(e.message))
    api<{ roles: Role[] }>('/roles', { entityId }).then((d) => setRoles(d.roles)).catch(() => {})
  }
  useEffect(() => { load() }, [entityId])
  return (
    <div>
      <div style={box}>
        <b style={{ fontSize: 14 }}>Copy roles (this entity)</b>
        <div style={{ display: 'flex', gap: 8, marginTop: 10 }}>
          <select style={inp} value={copy.from} onChange={(e) => setCopy({ ...copy, from: e.target.value })}>
            <option value="">From user…</option>{rows.map((u) => <option key={u.id} value={u.id}>{u.email}</option>)}
          </select>
          <select style={inp} value={copy.to} onChange={(e) => setCopy({ ...copy, to: e.target.value })}>
            <option value="">To user…</option>{rows.map((u) => <option key={u.id} value={u.id}>{u.email}</option>)}
          </select>
          <button style={btn} disabled={!copy.from || !copy.to}
            onClick={() => api('/users/copy-roles', { method: 'POST', body: { fromUserId: copy.from, toUserId: copy.to }, entityId }).then(load).catch((e) => setErr(e.message))}>
            Copy</button>
        </div>
      </div>
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>Email</th><th style={th}>Roles (this entity)</th><th style={th}>Assign</th></tr></thead>
        <tbody>{rows.map((u) => {
          const mine = u.roles.filter((r) => r.entity_id === entityId)
          return (
            <tr key={u.id}>
              <td style={td}>{u.email}</td>
              <td style={td}>{mine.length ? mine.map((r) => (
                <span key={r.role_id} style={{ marginRight: 8 }}>
                  {r.erp_roles?.name ?? r.role_id}
                  <button style={{ border: 0, background: 'none', color: '#b91c1c', cursor: 'pointer' }}
                    onClick={() => api(`/users/${u.id}/roles/${r.role_id}`, { method: 'DELETE', entityId }).then(load).catch((e) => setErr(e.message))}>×</button>
                </span>
              )) : <i style={{ color: '#94a3b8' }}>none</i>}</td>
              <td style={td}>
                <select style={inp} defaultValue="" onChange={(e) => {
                  if (e.target.value) api(`/users/${u.id}/roles`, { method: 'POST', body: { roleId: e.target.value }, entityId }).then(load).catch((er) => setErr(er.message))
                  e.target.value = ''
                }}>
                  <option value="">+ role…</option>{roles.map((r) => <option key={r.id} value={r.id}>{r.name}</option>)}
                </select>
              </td>
            </tr>
          )
        })}</tbody>
      </table>
    </div>
  )
}

function Roles({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [data, setData] = useState<{ roles: Role[]; privileges: Priv[]; rolePrivileges: RolePriv[] } | null>(null)
  const [sel, setSel] = useState<string>('')
  const [checked, setChecked] = useState<Set<string>>(new Set())
  const [newRole, setNewRole] = useState('')
  const load = () => api<{ roles: Role[]; privileges: Priv[]; rolePrivileges: RolePriv[] }>('/roles', { entityId }).then(setData).catch((e) => setErr(e.message))
  useEffect(() => { load() }, [entityId])
  useEffect(() => {
    if (data && sel) setChecked(new Set(data.rolePrivileges.filter((rp) => rp.role_id === sel).map((rp) => rp.privilege_code)))
  }, [data, sel])
  const byModule = useMemo(() => {
    const m = new Map<string, Priv[]>()
    data?.privileges.forEach((p) => { m.set(p.module, [...(m.get(p.module) ?? []), p]) })
    return m
  }, [data])
  if (!data) return <p style={{ fontSize: 13 }}>Loading…</p>
  return (
    <div style={{ display: 'grid', gridTemplateColumns: '220px 1fr', gap: 16 }}>
      <div>
        <div style={{ display: 'flex', gap: 6, marginBottom: 10 }}>
          <input style={{ ...inp, flex: 1 }} placeholder="New role name" value={newRole} onChange={(e) => setNewRole(e.target.value)} />
          <button style={btn} onClick={() => api('/roles', { method: 'POST', body: { name: newRole }, entityId }).then(() => { setNewRole(''); load() }).catch((e) => setErr(e.message))}>+</button>
        </div>
        {data.roles.map((r) => (
          <button key={r.id} onClick={() => setSel(r.id)}
            style={{ ...btn, display: 'block', width: '100%', textAlign: 'left', marginBottom: 4, background: sel === r.id ? '#0b1320' : '#f1f5f9', color: sel === r.id ? '#fff' : '#334155' }}>
            {r.name}</button>
        ))}
      </div>
      <div>
        {!sel ? <p style={{ fontSize: 13, color: '#64748b' }}>Select a role to edit its privilege matrix.</p> : (
          <div style={box}>
            {[...byModule.entries()].map(([mod, privs]) => (
              <div key={mod} style={{ marginBottom: 12 }}>
                <b style={{ fontSize: 13, textTransform: 'uppercase', color: '#475569' }}>{mod}</b>
                {privs.map((p) => (
                  <label key={p.code} style={{ display: 'block', fontSize: 13, marginTop: 4 }}>
                    <input type="checkbox" checked={checked.has(p.code)} onChange={(e) => {
                      const next = new Set(checked)
                      e.target.checked ? next.add(p.code) : next.delete(p.code)
                      setChecked(next)
                    }} /> {p.code} <span style={{ color: '#94a3b8' }}>— {p.description}</span>
                  </label>
                ))}
              </div>
            ))}
            <button style={btn} onClick={() => api(`/roles/${sel}/privileges`, { method: 'PUT', body: { privilegeCodes: [...checked] }, entityId }).then(load).catch((e) => setErr(e.message))}>
              Save privileges</button>
          </div>
        )}
      </div>
    </div>
  )
}

// ---------------------------------------------------------------- data import/export (Phase 9)
const IO_TABLES = ['erp_customers', 'vendors', 'items', 'employees', 'ledger_accounts'] as const
type IoResult = { row: number; ok: boolean; error?: string; no?: string }

/** Minimal CSV parser with quoted-field handling ("" escapes a quote). First line = headers. */
function parseCsv(text: string): Record<string, string>[] {
  const grid: string[][] = []
  let cell = ''
  let row: string[] = []
  let inQuotes = false
  for (let i = 0; i < text.length; i++) {
    const ch = text[i]
    if (inQuotes) {
      if (ch === '"') { if (text[i + 1] === '"') { cell += '"'; i++ } else inQuotes = false }
      else cell += ch
    } else if (ch === '"') inQuotes = true
    else if (ch === ',') { row.push(cell); cell = '' }
    else if (ch === '\n') { row.push(cell); grid.push(row); row = []; cell = '' }
    else if (ch !== '\r') cell += ch
  }
  if (cell !== '' || row.length) { row.push(cell); grid.push(row) }
  const [headers, ...data] = grid
  if (!headers) return []
  return data
    .filter((r) => r.some((c) => c.trim() !== ''))
    .map((r) => Object.fromEntries(headers.map((h, i) => [h.trim(), r[i] ?? ''])))
}

function DataIO({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [table, setTable] = useState<string>(IO_TABLES[0])
  const [csvText, setCsvText] = useState('')
  const [results, setResults] = useState<IoResult[]>([])
  const [summary, setSummary] = useState('')
  const [busy, setBusy] = useState(false)

  const doExport = () =>
    api<{ csv: string; rows: number }>(`/dataio/export/${table}`, { entityId }).then((d) => {
      const a = document.createElement('a')
      a.href = URL.createObjectURL(new Blob([d.csv], { type: 'text/csv' }))
      a.download = `${table}.csv`
      a.click()
    }).catch((e) => setErr(e.message))

  const runImport = (dryRun: boolean) => {
    const rows = parseCsv(csvText)
    if (!rows.length) { setErr('Paste CSV with a header row first (tip: Export CSV gives you the template).'); return }
    setBusy(true); setErr(''); setResults([]); setSummary('')
    api<{ inserted: number; results: IoResult[] }>(`/dataio/import/${table}`, { method: 'POST', body: { rows, dryRun }, entityId })
      .then((d) => {
        setResults(d.results)
        const ok = d.results.filter((r) => r.ok).length
        setSummary(dryRun
          ? `Dry run: ${ok}/${d.results.length} rows valid — nothing was written.`
          : `Imported ${d.inserted}/${d.results.length} rows.`)
      })
      .catch((e) => setErr(e.message))
      .finally(() => setBusy(false))
  }

  return (
    <div>
      <div style={box}>
        <b style={{ fontSize: 14 }}>Export</b>
        <div style={{ display: 'flex', gap: 8, marginTop: 10, alignItems: 'center' }}>
          <select style={inp} value={table} onChange={(e) => { setTable(e.target.value); setResults([]); setSummary('') }}>
            {IO_TABLES.map((t) => <option key={t} value={t}>{t}</option>)}
          </select>
          <button style={btn} onClick={doExport}>Export CSV</button>
          <span style={{ fontSize: 13, color: '#64748b' }}>Entity-filtered. The exported header row doubles as the import template.</span>
        </div>
      </div>
      <div style={box}>
        <b style={{ fontSize: 14 }}>Import into {table}</b>
        <p style={{ fontSize: 13, color: '#64748b', margin: '6px 0' }}>
          Paste CSV below (first line = column headers, quoted fields supported). Numbers like customer/vendor/item/employee no
          are allocated by the sequence engine — ledger accounts use the provided account_no. Always dry-run first.
        </p>
        <textarea style={{ ...inp, width: '100%', boxSizing: 'border-box', minHeight: 140, fontFamily: 'monospace' }}
          placeholder={'name,phone\n"Sharma Electronics","9876543210"'}
          value={csvText} onChange={(e) => setCsvText(e.target.value)} />
        <div style={{ display: 'flex', gap: 8, marginTop: 8, alignItems: 'center' }}>
          <button style={{ ...btn, background: '#854d0e' }} disabled={busy || !csvText.trim()} onClick={() => runImport(true)}>Dry run</button>
          <button style={{ ...btn, background: '#166534' }} disabled={busy || !csvText.trim()} onClick={() => runImport(false)}>Import</button>
          {summary && <span style={{ fontSize: 13 }}><b>{summary}</b></span>}
        </div>
        {results.length > 0 && (
          <table style={{ width: '100%', borderCollapse: 'collapse', marginTop: 10 }}>
            <thead><tr><th style={th}>Row</th><th style={th}>Result</th><th style={th}>Allocated no</th><th style={th}>Error</th></tr></thead>
            <tbody>{results.map((r) => (
              <tr key={r.row}>
                <td style={td}>{r.row}</td>
                <td style={{ ...td, color: r.ok ? '#166534' : '#b91c1c' }}>{r.ok ? 'OK' : 'Failed'}</td>
                <td style={td}>{r.no ?? ''}</td>
                <td style={td}>{r.error ?? ''}</td>
              </tr>
            ))}</tbody>
          </table>
        )}
      </div>
    </div>
  )
}

function Audit({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [rows, setRows] = useState<AuditRow[]>([])
  useEffect(() => { api<AuditRow[]>('/audit', { entityId }).then(setRows).catch((e) => setErr(e.message)) }, [entityId])
  return (
    <table style={{ width: '100%', borderCollapse: 'collapse' }}>
      <thead><tr><th style={th}>When</th><th style={th}>Who</th><th style={th}>Table</th><th style={th}>Action</th><th style={th}>Change</th></tr></thead>
      <tbody>{rows.map((r) => (
        <tr key={r.id}>
          <td style={td}>{new Date(r.at).toLocaleString()}</td>
          <td style={td}>{r.actor_email ?? 'system'}</td>
          <td style={td}>{r.table_name}</td>
          <td style={td}>{r.action}</td>
          <td style={{ ...td, maxWidth: 420, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{JSON.stringify(r.diff)}</td>
        </tr>
      ))}</tbody>
    </table>
  )
}
