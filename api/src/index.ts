import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { requireAuth, type AuthUser } from './auth'

export type Bindings = {
  SUPABASE_URL: string
  SUPABASE_SERVICE_ROLE_KEY: string
  SUPABASE_JWKS_URL: string
  SUPABASE_JWT_ISSUER: string
}
export type Variables = { user: AuthUser; entityId: string }

const app = new Hono<{ Bindings: Bindings; Variables: Variables }>()

app.use('*', cors())

app.get('/health', (c) => c.json({ ok: true, service: 'profixworld-erp-api', ts: new Date().toISOString() }))
app.get('/', (c) => c.json({ hello: 'ProFixWorld ERP API', docs: 'see CLAUDE.md' }))

// Example protected route — proves JWT validation works end-to-end.
app.get('/me', requireAuth, (c) => c.json({ user: c.get('user') }))

// Phase 1: System Administration module
import { entities, sequences, users, roles, audit } from './routes/sysadmin'
// Phase 2: General Ledger module
import { gl } from './routes/gl'
// Phase 3: Inventory + Warehouse module
import { inventory } from './routes/inventory'
// Phase 4: Sales & Marketing module
import { sales } from './routes/sales'

for (const p of ['/entities', '/sequences', '/users', '/roles', '/audit', '/gl', '/inv', '/sales']) {
  app.use(p, requireAuth)
  app.use(`${p}/*`, requireAuth)
}
app.route('/entities', entities)
app.route('/sequences', sequences)
app.route('/users', users)
app.route('/roles', roles)
app.route('/audit', audit)
app.route('/gl', gl)
app.route('/inv', inventory)
app.route('/sales', sales)

export default app
