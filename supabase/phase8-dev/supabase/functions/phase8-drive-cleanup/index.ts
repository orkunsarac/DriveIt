import { createClient } from "npm:@supabase/supabase-js@2.117.2";
import { bucket, failure, json } from "../_shared/common.ts";

// Scheduled caller only. This endpoint uses an independent server secret;
// never expose it to Flutter or place it in a checked-in file.
Deno.serve(async (request) => {
  if (request.method !== "POST") return failure("method_not_allowed", 405);
  const expected = Deno.env.get("PHASE8_CLEANUP_TOKEN");
  const supplied = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
  if (!expected || !supplied || supplied.length !== expected.length) return failure("unauthorized", 401);
  const left = new TextEncoder().encode(supplied);
  const right = new TextEncoder().encode(expected);
  let difference = 0;
  for (let i = 0; i < left.length; i++) difference |= left[i] ^ right[i];
  if (difference !== 0) return failure("unauthorized", 401);
  const url = Deno.env.get("SUPABASE_URL");
  const keyJson = Deno.env.get("SUPABASE_SECRET_KEYS");
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  let key = serviceRole?.trim() || "";
  if (keyJson) {
    try {
      const parsed = JSON.parse(keyJson) as Record<string, unknown>;
      if (typeof parsed.default === "string") key = parsed.default;
    } catch { /* use legacy server-side key */ }
  }
  if (!url || !key) return failure("server_not_configured", 503);
  const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: rows, error } = await admin.rpc("phase8_claim_drive_orphans", { p_limit: 50 });
  if (error || !Array.isArray(rows)) return failure("cleanup_claim_failed", 503);
  let expired = 0;
  let retryable = 0;
  for (const row of rows as Array<{ intent_id: string; staging_path: string }>) {
    const { error: removeError } = await admin.storage.from(bucket).remove([row.staging_path]);
    if (removeError) { retryable++; continue; }
    const { data: marked, error: markError } = await admin.rpc("phase8_expire_drive_orphan", {
      p_intent_id: row.intent_id,
    });
    if (markError || marked !== true) { retryable++; continue; }
    expired++;
  }
  return json({ ok: true, examined: rows.length, expired, retryable });
});
