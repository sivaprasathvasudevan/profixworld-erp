import type { MiddlewareHandler } from 'hono'
import { db } from './db'

/**
 * Backbone rule 5: every route checks module.function.action per entity.
 * Client sends the selected legal entity in the X-Entity-Id header.
 * Sets c.var.entityId for downstream handlers.
 */
export const requirePriv = (priv: string): MiddlewareHandler => async (c, next) => {
  const user = c.get('user')
  const entityId = c.req.header('X-Entity-Id')
  if (!entityId) return c.json({ error: 'missing X-Entity-Id header' }, 400)

  const sb = db(c.env)
  const { data: roles, error } = await sb
    .from('erp_user_roles')
    .select('role_id')
    .eq('user_id', user.id)
    .eq('entity_id', entityId)
  if (error) return c.json({ error: error.message }, 500)
  if (!roles?.length) return c.json({ error: 'no roles for this entity' }, 403)

  const { data: privs } = await sb
    .from('erp_role_privileges')
    .select('privilege_code')
    .in('role_id', roles.map((r) => r.role_id))
  const granted = new Set((privs ?? []).map((p) => p.privilege_code))
  if (!granted.has(priv)) return c.json({ error: `missing privilege ${priv}` }, 403)

  c.set('entityId', entityId)
  await next()
}
