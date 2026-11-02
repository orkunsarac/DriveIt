// Proposal only: wrap the existing handler after deployment approval.
// No origin means native clients continue to use the existing handler unchanged.
export function cors(request, allowedOrigin) {
  const origin = request.headers.get('origin')
  if (!origin) return { headers: {}, allowed: true }
  let configured = false
  try { const u = new URL(allowedOrigin); configured = u.protocol === 'https:' && u.origin === allowedOrigin && !u.username && !u.password } catch { /* fail closed */ }
  if (!configured || origin !== allowedOrigin) return { headers: { Vary: 'Origin' }, allowed: false }
  return { allowed: true, headers: { 'Access-Control-Allow-Origin': origin, 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info', 'Access-Control-Max-Age': '600', Vary: 'Origin' } }
}
export function withCors(handler, allowedOrigin) {
 return async request => {
  const policy = cors(request, allowedOrigin)
  if (!policy.allowed) return new Response(null, { status: 403, headers: policy.headers })
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: policy.headers })
  const response = await handler(request)
  const headers = new Headers(response.headers)
  for (const [key,value] of Object.entries(policy.headers)) headers.set(key,value)
  return new Response(response.body, { status: response.status, statusText: response.statusText, headers })
 }
}
