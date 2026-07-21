import { supabase, apiBase } from './supabase'

/** Fetch helper for the API tier: attaches the Supabase JWT and the selected entity. */
export async function api<T = unknown>(
  path: string,
  opts: { method?: string; body?: unknown; entityId?: string } = {},
): Promise<T> {
  const { data: { session } } = await supabase.auth.getSession()
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${session?.access_token ?? ''}`,
  }
  if (opts.entityId) headers['X-Entity-Id'] = opts.entityId
  const res = await fetch(`${apiBase}${path}`, {
    method: opts.method ?? 'GET',
    headers,
    body: opts.body === undefined ? undefined : JSON.stringify(opts.body),
  })
  const json = await res.json().catch(() => ({}))
  if (!res.ok) throw new Error((json as { error?: string }).error ?? `${res.status} ${res.statusText}`)
  return json as T
}
