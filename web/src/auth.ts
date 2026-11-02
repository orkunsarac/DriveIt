import { createClient } from '@supabase/supabase-js'

const PROD_URL = 'https://arwnbogcswisfesayosy.supabase.co'
const url = import.meta.env.VITE_SUPABASE_URL as string | undefined
const key = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined
function publicKey(value: string): boolean {
  if (value.startsWith('sb_publishable_')) return true
  try { const part = value.split('.')[1]; const payload = JSON.parse(atob(part.replace(/-/g, '+').replace(/_/g, '/'))); return payload.role === 'anon' && payload.ref === 'arwnbogcswisfesayosy' } catch { return false }
}
export const supabase = import.meta.env.VITE_AUTH_ENABLED === 'true' && url === PROD_URL && !!key && publicKey(key) ? createClient(PROD_URL, key, { auth: { flowType: 'pkce', detectSessionInUrl: true } }) : null
export function pinnedClient(token: string) {
  if (!supabase || !key) throw new Error('Auth unavailable')
  return createClient(PROD_URL, key, { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false }, global: { headers: { Authorization: `Bearer ${token}` } } })
}
function validRedirect(value: string): boolean {
  try { const u = new URL(value); return u.protocol === 'https:' && u.origin === window.location.origin && u.pathname === '/sifre-sifirlama' && !u.search && !u.hash && !u.username && !u.password } catch { return false }
}
export const resetEnabled = !!supabase && import.meta.env.VITE_PASSWORD_RESET_ENABLED === 'true' && !!import.meta.env.VITE_AUTH_REDIRECT_URL && validRedirect(import.meta.env.VITE_AUTH_REDIRECT_URL)
