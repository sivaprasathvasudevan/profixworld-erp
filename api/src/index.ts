import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { requireAuth, type AuthUser } from './auth'

export type Bindings = {
  SUPABASE_URL: string
  SUPABASE_SERVICE_ROLE_KEY: string
  SUPABASE_JWKS_URL: string
  SUPABASE_JWT_ISSUER: string
}
export type Variables = { user: AuthUser }

const app = new Hono<{ Bindings: Bindings; Variables: Variables }>()

app.use('*', cors())

app.get('/health', (c) => c.json({ ok: true, service: 'profixworld-erp-api', ts: new Date().toISOString() }))
app.get('/', (c) => c.json({ hello: 'ProFixWorld ERP API', docs: 'see CLAUDE.md' }))

// Example protected route — proves JWT validation works end-to-end.
app.get('/me', requireAuth, (c) => c.json({ user: c.get('user') }))

// Phase 1+ mounts module routers here, each behind requireAuth + privilege checks:
//   app.route('/entities', entitiesRouter)
//   app.route('/sequences', sequencesRouter)
//   ...

export default app
