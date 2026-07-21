import { Hono } from 'hono'
import type { SupabaseClient } from '@supabase/supabase-js'
import { db } from '../db'
import { requirePriv } from '../privileges'
import type { Bindings, Variables } from '../index'

type Env = { Bindings: Bindings; Variables: Variables }

export const dms = new Hono<Env>()

const BUCKET = 'erp-documents'

type LinkIn = { tableName: string; recordId: string }
type VersionEntry = { version: number; storage_path: string; mime_type: string | null; size_bytes: number | null; replaced_at: string }

/** Base64 (optionally a data: URL) → bytes. */
function fromBase64(b64: string): Uint8Array {
  const bin = atob(b64.replace(/^data:[^;]*;base64,/, ''))
  const bytes = new Uint8Array(bin.length)
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i)
  return bytes
}

/** Buckets can't be created reliably from SQL migrations — create lazily before each upload. */
async function ensureBucket(sb: SupabaseClient): Promise<string | null> {
  const { error } = await sb.storage.createBucket(BUCKET, { public: false })
  if (error && !/already exists|duplicate/i.test(error.message)) return error.message
  return null
}

// Keep object keys tame: no path separators or exotic characters in file names.
const safeName = (name: string) => name.replace(/[^\w.\- ()]/g, '_')

// ------------------------------------------------------------ upload (allocates DOC, stores bytes, links records)
dms.post('/documents/upload', requirePriv('dms.documents.write'), async (c) => {
  const b = await c.req.json() as { title?: string; category?: string; fileName?: string; contentBase64?: string; mimeType?: string; links?: LinkIn[] }
  if (!b.title || !b.fileName || !b.contentBase64) {
    return c.json({ error: 'title, fileName and contentBase64 required' }, 400)
  }
  let bytes: Uint8Array
  try { bytes = fromBase64(b.contentBase64) } catch { return c.json({ error: 'contentBase64 is not valid base64' }, 400) }
  if (!bytes.length) return c.json({ error: 'file is empty' }, 400)

  const sb = db(c.env)
  const bucketErr = await ensureBucket(sb)
  if (bucketErr) return c.json({ error: bucketErr }, 500)

  const { data: no, error: seqErr } = await sb.rpc('allocate_number', { p_entity: c.get('entityId'), p_code: 'DOC' })
  if (seqErr) return c.json({ error: seqErr.message }, 400)

  const path = `${c.get('entityId')}/${no}/${safeName(b.fileName)}`
  const { error: upErr } = await sb.storage.from(BUCKET)
    .upload(path, bytes.buffer as ArrayBuffer, { contentType: b.mimeType ?? 'application/octet-stream', upsert: false })
  if (upErr) return c.json({ error: upErr.message }, 400)

  const { data: doc, error } = await sb.from('erp_documents')
    .insert({
      entity_id: c.get('entityId'), doc_no: no, title: b.title, category: b.category || 'general',
      storage_path: path, mime_type: b.mimeType ?? null, size_bytes: bytes.length,
      uploaded_by: c.get('user').id,
    })
    .select().single()
  if (error) return c.json({ error: error.message }, 400)

  if (Array.isArray(b.links) && b.links.length) {
    const { error: lErr } = await sb.from('erp_document_links')
      .insert(b.links.map((l) => ({ document_id: doc.id, table_name: l.tableName, record_id: l.recordId })))
    if (lErr) return c.json({ error: lErr.message }, 400)
  }
  return c.json(doc, 201)
})

// ------------------------------------------------------------ list (latest 100, or filtered by linked record)
dms.get('/documents', requirePriv('dms.documents.read'), async (c) => {
  const sb = db(c.env)
  const table = c.req.query('table')
  const record = c.req.query('record')
  let ids: string[] | null = null
  if (table && record) {
    const { data: links, error: lErr } = await sb.from('erp_document_links')
      .select('document_id').eq('table_name', table).eq('record_id', record)
    if (lErr) return c.json({ error: lErr.message }, 500)
    ids = (links ?? []).map((l) => l.document_id)
    if (!ids.length) return c.json([])
  }
  let q = sb.from('erp_documents').select('*, erp_document_links(table_name, record_id)')
    .eq('entity_id', c.get('entityId')).order('created_at', { ascending: false }).limit(100)
  if (ids) q = q.in('id', ids)
  const { data, error } = await q
  if (error) return c.json({ error: error.message }, 500)
  return c.json(data)
})

// ------------------------------------------------------------ signed download URL (1 hour)
dms.get('/documents/:id/url', requirePriv('dms.documents.read'), async (c) => {
  const sb = db(c.env)
  const { data: doc, error } = await sb.from('erp_documents').select('storage_path')
    .eq('id', c.req.param('id')).eq('entity_id', c.get('entityId')).single()
  if (error) return c.json({ error: error.message }, 404)
  if (!doc.storage_path) return c.json({ error: 'document has no stored file' }, 400)
  const { data, error: sErr } = await sb.storage.from(BUCKET).createSignedUrl(doc.storage_path, 3600)
  if (sErr) return c.json({ error: sErr.message }, 500)
  return c.json({ url: data.signedUrl })
})

// ------------------------------------------------------------ link to any record
dms.post('/documents/:id/links', requirePriv('dms.documents.write'), async (c) => {
  const b = await c.req.json() as LinkIn
  if (!b.tableName || !b.recordId) return c.json({ error: 'tableName and recordId required' }, 400)
  const sb = db(c.env)
  const { data: doc, error: dErr } = await sb.from('erp_documents').select('id')
    .eq('id', c.req.param('id')).eq('entity_id', c.get('entityId')).single()
  if (dErr) return c.json({ error: dErr.message }, 404)
  const { data, error } = await sb.from('erp_document_links')
    .upsert({ document_id: doc.id, table_name: b.tableName, record_id: b.recordId })
    .select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data, 201)
})

// ------------------------------------------------------------ new version (keeps prior paths in versions jsonb)
dms.post('/documents/:id/version', requirePriv('dms.documents.write'), async (c) => {
  const b = await c.req.json() as { fileName?: string; contentBase64?: string; mimeType?: string }
  if (!b.fileName || !b.contentBase64) return c.json({ error: 'fileName and contentBase64 required' }, 400)
  let bytes: Uint8Array
  try { bytes = fromBase64(b.contentBase64) } catch { return c.json({ error: 'contentBase64 is not valid base64' }, 400) }
  if (!bytes.length) return c.json({ error: 'file is empty' }, 400)

  const sb = db(c.env)
  const { data: doc, error: dErr } = await sb.from('erp_documents').select('*')
    .eq('id', c.req.param('id')).eq('entity_id', c.get('entityId')).single()
  if (dErr) return c.json({ error: dErr.message }, 404)

  const bucketErr = await ensureBucket(sb)
  if (bucketErr) return c.json({ error: bucketErr }, 500)

  const nextVersion = Number(doc.version) + 1
  const path = `${c.get('entityId')}/${doc.doc_no}/v${nextVersion}/${safeName(b.fileName)}`
  const { error: upErr } = await sb.storage.from(BUCKET)
    .upload(path, bytes.buffer as ArrayBuffer, { contentType: b.mimeType ?? 'application/octet-stream', upsert: false })
  if (upErr) return c.json({ error: upErr.message }, 400)

  const history: VersionEntry[] = Array.isArray(doc.versions) ? doc.versions : []
  history.push({
    version: Number(doc.version), storage_path: doc.storage_path,
    mime_type: doc.mime_type ?? null, size_bytes: doc.size_bytes != null ? Number(doc.size_bytes) : null,
    replaced_at: new Date().toISOString(),
  })
  const { data, error } = await sb.from('erp_documents')
    .update({ storage_path: path, mime_type: b.mimeType ?? null, size_bytes: bytes.length, version: nextVersion, versions: history })
    .eq('id', doc.id).select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data)
})

// ------------------------------------------------------------ delete (row + stored objects, all versions)
dms.delete('/documents/:id', requirePriv('dms.documents.write'), async (c) => {
  const sb = db(c.env)
  const { data: doc, error: dErr } = await sb.from('erp_documents').select('*')
    .eq('id', c.req.param('id')).eq('entity_id', c.get('entityId')).single()
  if (dErr) return c.json({ error: dErr.message }, 404)
  const paths = [doc.storage_path, ...(Array.isArray(doc.versions) ? doc.versions : []).map((v: VersionEntry) => v.storage_path)]
    .filter((p): p is string => !!p)
  if (paths.length) await sb.storage.from(BUCKET).remove(paths) // best-effort; row delete is authoritative
  const { error } = await sb.from('erp_documents').delete().eq('id', doc.id) // links cascade
  if (error) return c.json({ error: error.message }, 400)
  return c.json({ ok: true })
})
