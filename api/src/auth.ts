import { createRemoteJWKSet, jwtVerify } from 'jose'
import type { MiddlewareHandler } from 'hono'

// Supabase now issues ES256 JWTs; verify against the project JWKS.
let _jwks: ReturnType<typeof createRemoteJWKSet> | null = null
function jwks(url: string) {
  if (!_jwks) _jwks = createRemoteJWKSet(new URL(url))
  return _jwks
}

export type AuthUser = { id: string; email?: string; role?: string }

/** Validates the Supabase Auth bearer token and sets c.var.user. */
export const requireAuth: MiddlewareHandler = async (c, next) => {
  const authz = c.req.header('Authorization') ?? ''
  const token = authz.startsWith('Bearer ') ? authz.slice(7) : ''
  if (!token) return c.json({ error: 'missing bearer token' }, 401)
  try {
    const { payload } = await jwtVerify(token, jwks(c.env.SUPABASE_JWKS_URL), {
      issuer: c.env.SUPABASE_JWT_ISSUER,
    })
    c.set('user', {
      id: payload.sub as string,
      email: payload.email as string | undefined,
      role: payload.role as string | undefined,
    })
    await next()
  } catch {
    return c.json({ error: 'invalid token' }, 401)
  }
}
