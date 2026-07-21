import { useState } from 'react'

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

export function App() {
  const [active, setActive] = useState<string>(MODULES[0])
  // Entity picker is a placeholder until Phase 1 wires legal_entities.
  const [entity] = useState('PROFIX')

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
      </nav>
      <main style={{ display: 'flex', flexDirection: 'column' }}>
        <header style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '12px 20px', borderBottom: '1px solid #e5e7eb' }}>
          <h1 style={{ fontSize: 18, margin: 0 }}>{active}</h1>
          <div style={{ fontSize: 13, color: '#475569' }}>Legal entity: <strong>{entity}</strong></div>
        </header>
        <section style={{ padding: 24, color: '#334155' }}>
          <p>Shell scaffold (Phase 0). This module screen is built in its phase — see CLAUDE.md and the phase prompts.</p>
        </section>
      </main>
    </div>
  )
}
