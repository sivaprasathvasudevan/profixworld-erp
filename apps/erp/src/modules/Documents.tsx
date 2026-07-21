import { useEffect, useRef, useState } from 'react'
import { api } from '../lib/api'

type DocLink = { table_name: string; record_id: string }
type Doc = {
  id: string; doc_no: string; title: string; category: string; storage_path?: string
  mime_type?: string; size_bytes?: number; version: number; created_at: string
  versions?: { version: number; storage_path: string }[]
  erp_document_links?: DocLink[]
}

// Masters/transactions that commonly carry attachments (backbone: any table works via the API).
const LINK_TABLES = ['erp_customers', 'vendors', 'employees', 'items', 'assets', 'service_orders'] as const

const box: React.CSSProperties = { border: '1px solid #e2e8f0', borderRadius: 8, padding: 16, marginBottom: 16 }
const th: React.CSSProperties = { textAlign: 'left', padding: '6px 10px', background: '#f1f5f9', fontSize: 13 }
const td: React.CSSProperties = { padding: '6px 10px', borderTop: '1px solid #e2e8f0', fontSize: 13 }
const inp: React.CSSProperties = { padding: '6px 8px', border: '1px solid #cbd5e1', borderRadius: 6, fontSize: 13 }
const btn: React.CSSProperties = { padding: '6px 12px', border: 0, borderRadius: 6, background: '#0b1320', color: '#fff', cursor: 'pointer', fontSize: 13 }
const btn2: React.CSSProperties = { ...btn, background: '#e2e8f0', color: '#334155' }

const fmtSize = (n?: number) => (n == null ? '' : n < 1024 ? `${n} B` : n < 1048576 ? `${(n / 1024).toFixed(1)} KB` : `${(n / 1048576).toFixed(1)} MB`)

/** File → raw base64 (data-URL prefix stripped). */
const readBase64 = (f: File) => new Promise<string>((resolve, reject) => {
  const r = new FileReader()
  r.onload = () => resolve(String(r.result).split(',')[1] ?? '')
  r.onerror = () => reject(new Error('could not read file'))
  r.readAsDataURL(f)
})

export function Documents({ entityId }: { entityId: string }) {
  const [err, setErr] = useState('')
  const [rows, setRows] = useState<Doc[]>([])
  const [form, setForm] = useState({ title: '', category: 'general', linkTable: '', linkRecord: '' })
  const [file, setFile] = useState<File | null>(null)
  const fileRef = useRef<HTMLInputElement>(null)
  const [filter, setFilter] = useState({ table: '', record: '' })
  const [selId, setSelId] = useState('')
  const [linkForm, setLinkForm] = useState({ tableName: '', recordId: '' })
  const [busy, setBusy] = useState(false)

  const load = (f = filter) => {
    const q = f.table && f.record ? `?table=${encodeURIComponent(f.table)}&record=${encodeURIComponent(f.record)}` : ''
    api<Doc[]>('/dms/documents' + q, { entityId }).then(setRows).catch((e) => setErr(e.message))
  }
  useEffect(() => { load({ table: '', record: '' }); setSelId('') }, [entityId])

  const upload = async () => {
    if (!file || !form.title) return
    setBusy(true); setErr('')
    try {
      const contentBase64 = await readBase64(file)
      await api('/dms/documents/upload', {
        method: 'POST', entityId,
        body: {
          title: form.title, category: form.category || 'general',
          fileName: file.name, contentBase64, mimeType: file.type || 'application/octet-stream',
          links: form.linkTable && form.linkRecord ? [{ tableName: form.linkTable, recordId: form.linkRecord }] : undefined,
        },
      })
      setForm({ title: '', category: 'general', linkTable: '', linkRecord: '' })
      setFile(null)
      if (fileRef.current) fileRef.current.value = ''
      load()
    } catch (e) { setErr((e as Error).message) }
    setBusy(false)
  }

  const download = (d: Doc) =>
    api<{ url: string }>('/dms/documents/' + d.id + '/url', { entityId })
      .then(({ url }) => window.open(url, '_blank')).catch((e) => setErr(e.message))

  const remove = (d: Doc) => {
    if (!confirm(`Delete ${d.doc_no} — ${d.title} (all versions)?`)) return
    api('/dms/documents/' + d.id, { method: 'DELETE', entityId })
      .then(() => { if (selId === d.id) setSelId(''); load() }).catch((e) => setErr(e.message))
  }

  const addLink = (d: Doc) =>
    api('/dms/documents/' + d.id + '/links', { method: 'POST', body: linkForm, entityId })
      .then(() => { setLinkForm({ tableName: '', recordId: '' }); load() }).catch((e) => setErr(e.message))

  const uploadVersion = async (d: Doc, f: File) => {
    setBusy(true); setErr('')
    try {
      const contentBase64 = await readBase64(f)
      await api('/dms/documents/' + d.id + '/version', {
        method: 'POST', entityId,
        body: { fileName: f.name, contentBase64, mimeType: f.type || 'application/octet-stream' },
      })
      load()
    } catch (e) { setErr((e as Error).message) }
    setBusy(false)
  }

  const sel = rows.find((r) => r.id === selId)

  return (
    <div>
      {err && <div style={{ color: '#b91c1c', marginBottom: 12, fontSize: 13 }}>{err}</div>}

      <div style={box}>
        <b style={{ fontSize: 14 }}>Upload document (doc no is allocated automatically; stored in Supabase Storage)</b>
        <div style={{ display: 'flex', gap: 8, marginTop: 10, flexWrap: 'wrap', alignItems: 'center' }}>
          <input ref={fileRef} style={{ fontSize: 13 }} type="file" onChange={(e) => setFile(e.target.files?.[0] ?? null)} />
          <input style={{ ...inp, minWidth: 180 }} placeholder="Title" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
          <input style={inp} placeholder="Category" value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })} />
          <select style={inp} value={form.linkTable} onChange={(e) => setForm({ ...form, linkTable: e.target.value })}>
            <option value="">Link to record (optional)…</option>
            {LINK_TABLES.map((t) => <option key={t} value={t}>{t}</option>)}
          </select>
          {form.linkTable && (
            <input style={{ ...inp, width: 280 }} placeholder="Record id (uuid)" value={form.linkRecord} onChange={(e) => setForm({ ...form, linkRecord: e.target.value })} />
          )}
          <button style={btn} disabled={busy || !file || !form.title} onClick={upload}>{busy ? 'Uploading…' : 'Upload'}</button>
        </div>
      </div>

      <div style={{ display: 'flex', gap: 8, marginBottom: 12, alignItems: 'center' }}>
        <span style={{ fontSize: 13, color: '#64748b' }}>Filter by linked record:</span>
        <select style={inp} value={filter.table} onChange={(e) => setFilter({ ...filter, table: e.target.value })}>
          <option value="">— any —</option>
          {LINK_TABLES.map((t) => <option key={t} value={t}>{t}</option>)}
        </select>
        <input style={{ ...inp, width: 280 }} placeholder="Record id (uuid)" value={filter.record} onChange={(e) => setFilter({ ...filter, record: e.target.value })} />
        <button style={btn2} onClick={() => load()}>Apply</button>
        <button style={btn2} onClick={() => { const f = { table: '', record: '' }; setFilter(f); load(f) }}>Clear</button>
      </div>

      {sel && (
        <div style={box}>
          <div style={{ display: 'flex', gap: 12, alignItems: 'center', flexWrap: 'wrap' }}>
            <b style={{ fontSize: 14 }}>{sel.doc_no} — {sel.title} (v{sel.version})</b>
            <button style={btn} onClick={() => download(sel)}>Download</button>
            <label style={{ ...btn2, display: 'inline-block' }}>
              Upload new version…
              <input type="file" style={{ display: 'none' }}
                onChange={(e) => { const f = e.target.files?.[0]; if (f) uploadVersion(sel, f); e.target.value = '' }} />
            </label>
            <button style={{ ...btn, background: '#991b1b' }} onClick={() => remove(sel)}>Delete</button>
            <button style={btn2} onClick={() => setSelId('')}>Close</button>
          </div>
          <div style={{ marginTop: 10, fontSize: 13 }}>
            <b>Links:</b>{' '}
            {(sel.erp_document_links ?? []).length
              ? (sel.erp_document_links ?? []).map((l) => <code key={l.table_name + l.record_id} style={{ marginRight: 8 }}>{l.table_name} / {l.record_id}</code>)
              : <i style={{ color: '#94a3b8' }}>none</i>}
          </div>
          <div style={{ display: 'flex', gap: 8, marginTop: 8, alignItems: 'center' }}>
            <select style={inp} value={linkForm.tableName} onChange={(e) => setLinkForm({ ...linkForm, tableName: e.target.value })}>
              <option value="">Link to table…</option>
              {LINK_TABLES.map((t) => <option key={t} value={t}>{t}</option>)}
            </select>
            <input style={{ ...inp, width: 280 }} placeholder="Record id (uuid)" value={linkForm.recordId} onChange={(e) => setLinkForm({ ...linkForm, recordId: e.target.value })} />
            <button style={btn} disabled={!linkForm.tableName || !linkForm.recordId} onClick={() => addLink(sel)}>Add link</button>
          </div>
          {(sel.versions ?? []).length > 0 && (
            <p style={{ fontSize: 12, color: '#64748b', marginBottom: 0 }}>
              {sel.versions!.length} prior version(s) kept in storage: {sel.versions!.map((v) => `v${v.version}`).join(', ')}
            </p>
          )}
        </div>
      )}

      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>Doc no</th><th style={th}>Title</th><th style={th}>Category</th><th style={th}>Type</th><th style={th}>Size</th><th style={th}>Ver</th><th style={th}>Links</th><th style={th}>Uploaded</th><th style={th}></th></tr></thead>
        <tbody>{rows.map((r) => (
          <tr key={r.id} onClick={() => setSelId(r.id)} style={{ cursor: 'pointer', background: r.id === selId ? '#f8fafc' : undefined }}>
            <td style={td}><b>{r.doc_no}</b></td><td style={td}>{r.title}</td><td style={td}>{r.category}</td>
            <td style={td}>{r.mime_type ?? ''}</td><td style={td}>{fmtSize(r.size_bytes)}</td><td style={td}>v{r.version}</td>
            <td style={td}>{(r.erp_document_links ?? []).length || '—'}</td>
            <td style={td}>{new Date(r.created_at).toLocaleString()}</td>
            <td style={td}>
              <button style={btn2} onClick={(e) => { e.stopPropagation(); download(r) }}>Download</button>{' '}
              <button style={{ ...btn2, color: '#b91c1c' }} onClick={(e) => { e.stopPropagation(); remove(r) }}>Delete</button>
            </td>
          </tr>
        ))}</tbody>
      </table>
      {rows.length === 0 && <p style={{ fontSize: 13, color: '#94a3b8' }}>No documents{filter.table ? ' for this record' : ''} — upload the first one above.</p>}
    </div>
  )
}
