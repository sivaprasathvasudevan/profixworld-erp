import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import type { Bindings } from './index'

/** Service-role Supabase client — API tier only. Never expose this key to the client tier. */
export function db(env: Bindings): SupabaseClient {
  return createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
}
