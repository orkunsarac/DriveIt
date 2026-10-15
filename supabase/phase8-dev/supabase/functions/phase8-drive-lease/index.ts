import { authenticatedAdmin, failure, json, readJson, uuidV4 } from "../_shared/common.ts";

Deno.serve(async (request) => {
  if (request.method !== "POST") return failure("method_not_allowed", 405);
  const auth = await authenticatedAdmin(request);
  if (!auth) return failure("unauthorized", 401);
  const b = await readJson(request);
  if (!b || typeof b.sourceIdentity !== "string" || !uuidV4.test(b.sourceIdentity) ||
      typeof b.deviceId !== "string" || !uuidV4.test(b.deviceId) ||
      typeof b.sessionId !== "string" || b.sessionId.length < 1 || b.sessionId.length > 128 ||
      !["acquire", "heartbeat"].includes(String(b.action)) ||
      (b.action === "heartbeat" && (!Number.isSafeInteger(b.fencingToken) || Number(b.fencingToken) < 1))) {
    return failure("lease_claim_invalid", 422);
  }
  const { data, error } = await auth.admin.rpc("phase8_drive_lease", {
    p_owner_id: auth.userId, p_source_identity: b.sourceIdentity, p_device_id: b.deviceId,
    p_session_id: b.sessionId, p_action: b.action, p_fencing_token: b.fencingToken ?? null,
  });
  if (error || !data) return failure("lease_fenced", 409);
  return json({ ok: true, lease: data });
});
