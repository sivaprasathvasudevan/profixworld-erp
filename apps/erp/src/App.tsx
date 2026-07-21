import { useEffect, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { supabase } from './lib/supabase'
import { api } from './lib/api'
import { SystemAdministration } from './modules/SystemAdministration'

// The 12 ERP modules. Phase 1 fills in System Administration; later phases fill the rest.
const MODULES = [
  'System Administration',
  'General Ledger',
  'Inventory',
  'Warehouse',
  'Sales & Marketing',
  'Procurement & Sourcing',
  'HR & Payroll',
  'Service Management',
  'Asset Management',
  'Document Management',
  'Reporting & Analytics',
  'Integrations',
] as const

type Entity = { id: string; code: string; name: string }

export function App() {
  const [session, setSession] = useState<Session | null>(null)
  const [booted, setBooted] = useState(false)
  const [active, setActive] = useState<string>(MODULES[0])
  const [entities, setEntities] = useState<Entity[]>([])
  const [entityId, setEntityId] = useState<string>(() => localStorage.getItem('erp-entity') ?? '')

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => { setSession(data.session); setBooted(true) })
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) => setSession(s))
    return () => sub.subscription.unsubscribe()
  }, [])

  const loadEntities = () => api<Entity[]>('/entities').then((list) => {
    setEntities(list)
    if (list.length && !list.some((e) => e.id === entityId)) {
      setEntityId(list[0].id)
      localStorage.setItem('erp-entity', list[0].id)
    }
  }).catch(() => setEntities([]))

  useEffect(() => { if (session) loadEntities() }, [session])

  if (!booted) return null
  if (!session) return <Login />

  return (
    <div style={{ display: 'grid', gridTemplateColumns: '240px 1fr', height: '100vh', fontFamily: 'system-ui' }}>
      <nav style={{ background: '#0b1320', color: '#cbd5e1', padding: 16, overflowY: 'auto' }}>
        <div style={{ fontWeight: 700, color: '#fff', marginBottom: 16 }}>ProFixWorld ERP</div>
        {MODULES.map((m) => (
          <button
            key={m}
            onClick={() => setActive(m)}
            style={{
              display: 'block', width: '100%', textAlign: 'left', padding: '8px 10px',
              margin: '2px 0', borderRadius: 6, border: 0, cursor: 'pointer',
              background: active === m ? '#1e293b' : 'transparent',
              color: active === m ? '#fff' : '#cbd5e1',
            }}
          >
            {m}
          </button>
        ))}
        <button onClick={() => supabase.auth.signOut()}
          style={{ display: 'block', width: '100%', textAlign: 'left', padding: '8px 10px', marginTop: 24, borderRadius: 6, border: 0, cursor: 'pointer', background: 'transparent', color: '#f87171' }}>
          Sign out
        </button>
      </nav>
      <main style={{ display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
        <header style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '12px 20px', borderBottom: '1px solid #e5e7eb' }}>
          <h1 style={{ fontSize: 18, margin: 0 }}>{active}</h1>
          <div style={{ fontSize: 13, color: '#475569', display: 'flex', gap: 8, alignItems: 'center' }}>
            <span>Legal entity:</span>
            <select value={entityId} onChange={(e) => { setEntityId(e.target.value); localStorage.setItem('erp-entity', e.target.value) }}
              style={{ padding: '4px 8px', border: '1px solid #cbd5e1', borderRadius: 6 }}>
              {entities.length === 0 && <option value="">— no access —</option>}
              {entities.map((e) => <option key={e.id} value={e.id}>{e.code} — {e.name}</option>)}
            </select>
            <span style={{ color: '#94a3b8' }}>{session.user.email}</span>
          </div>
        </header>
        <section style={{ padding: 24, color: '#334155', overflowY: 'auto' }}>
          {active === 'System Administration'
            ? <SystemAdministration entityId={entityId} onEntitiesChanged={loadEntities} />
            : <p>This module is built in its phase — see CLAUDE.md and the phase prompts.</p>}
        </section>
      </main>
    </div>
  )
}

function Login() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [err, setErr] = useState('')
  const [busy, setBusy] = useState(false)
  const submit = async (e: React.FormEvent) => {
    e.preventDefault()
    setBusy(true); setErr('')
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) setErr(error.message)
    setBusy(false)
  }
  return (
    <div style={{ display: 'grid', placeItems: 'center', height: '100vh', fontFamily: 'system-ui', background: '#0b1320' }}>
      <form onSubmit={submit} style={{ background: '#fff', padding: 32, borderRadius: 12, width: 320 }}>
        <h1 style={{ fontSize: 20, marginTop: 0 }}>ProFixWorld ERP</h1>
        <input value={email} onChange={(e) => setEmail(e.target.value)} placeholder="Email" type="email" required
          style={{ width: '100%', boxSizing: 'border-box', padding: 10, marginBottom: 8, border: '1px solid #cbd5e1', borderRadius: 6 }} />
        <input value={password} onChange={(e) => setPassword(e.target.value)} placeholder="Password" type="password" required
          style={{ width: '100%', boxSizing: 'border-box', padding: 10, marginBottom: 8, border: '1px solid #cbd5e1', borderRadius: 6 }} />
        {err && <div style={{ color: '#b91c1c', fontSize: 13, marginBottom: 8 }}>{err}</div>}
        <button disabled={busy} style={{ width: '100%', padding: 10, border: 0, borderRadius: 6, background: '#0b1320', color: '#fff', cursor: 'pointer' }}>
          {busy ? 'Signing in…' : 'Sign in'}
        </button>
      </form>
    </div>
  )
}
