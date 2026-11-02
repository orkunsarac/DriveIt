import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined
const key = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined
const enabled = import.meta.env.VITE_AUTH_ENABLED === 'true'
function publicKey(value: string): boolean {
  if (value.startsWith('sb_publishable_')) return true
  try { const part = value.split('.')[1]; const payload = JSON.parse(atob(part.replace(/-/g, '+').replace(/_/g, '/'))); return payload.role === 'anon' } catch { return false }
}
function validUrl(value: string): boolean {
  try { const u = new URL(value); return u.protocol === 'https:' || (u.protocol === 'http:' && ['localhost', '127.0.0.1'].includes(u.hostname)) } catch { return false }
}
export const supabase = enabled && url && key && validUrl(url) && publicKey(key) ? createClient(url, key, { auth: { flowType: 'pkce', detectSessionInUrl: true } }) : null
export const resetEnabled = !!supabase && import.meta.env.VITE_PASSWORD_RESET_ENABLED === 'true' && !!import.meta.env.VITE_AUTH_REDIRECT_URL && validUrl(import.meta.env.VITE_AUTH_REDIRECT_URL)
