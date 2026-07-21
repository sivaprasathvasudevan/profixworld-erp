import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL as string
const anon = import.meta.env.VITE_SUPABASE_ANON_KEY as string

// Client uses the PUBLIC anon key only. All ERP document writes go through the
// API (service-role) — never write documents directly from the client.
export const supabase = createClient(url, anon, {
  auth: { storageKey: 'profixworld-erp-auth', persistSession: true, autoRefreshToken: true },
})

export const apiBase = (import.meta.env.VITE_API_BASE_URL as string) ?? ''
