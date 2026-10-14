import { authenticatedAdmin, expectedDriveUpsertKey, failure, isSha256, json, ownerScope as makeOwnerScope, readJson, uuidV4 } from "../_shared/common.ts";

Deno.serve(async (request) => {
  if (request.method !== "POST") return failure("method_not_allowed", 405);
  const auth = await authenticatedAdmin(request);
  if (!auth) return failure("unauthorized", 401);
  const body = await readJson(request);
  if (!body) return failure("request_invalid", 400);
  const { userId } = auth;
  if (body.action === "capabilities") {
    const { data, error } = await auth.admin.rpc("phase8_drive_sync_capabilities", { p_owner_id: userId });
    if (error || !data) return failure("backend_not_ready", 503);
    return json({ ok: true, ...data });
  }
  const sourceIdentity = body.sourceIdentity;
  const ownerScope = body.ownerScope;
  const idempotencyKey = body.idempotencyKey;
  const contractVersion = body.contractVersion;
  const payloadFingerprint = body.payloadFingerprint;
  const objectSha256 = body.objectSha256;
  const objectBytes = body.objectBytes;
  if (body.ownerId !== userId || ownerScope !== JSON.stringify(["local_account_store_v1", "account", userId]) ||
      typeof sourceIdentity !== "string" || !uuidV4.test(sourceIdentity) ||
      typeof idempotencyKey !== "string" || !/^owner-sync-v2:[0-9a-f]{64}$/.test(idempotencyKey) ||
      contractVersion !== 2 || !isSha256(payloadFingerprint) || !isSha256(objectSha256) ||
      !Number.isInteger(objectBytes) || Number(objectBytes) < 1 || Number(objectBytes) > 10 * 1024 * 1024) {
    return failure("upload_claim_invalid", 422);
  }
  if (sourceIdentity !== sourceIdentity.toLowerCase() || ownerScope !== makeOwnerScope(userId) ||
      idempotencyKey !== await expectedDriveUpsertKey(userId, sourceIdentity)) {
    return failure("upload_claim_invalid", 422);
  }
  const { data, error } = await auth.admin.rpc("phase8_begin_drive_upload", {
    p_owner_id: userId,
    p_owner_scope: ownerScope,
    p_source_identity: sourceIdentity,
    p_idempotency_key: idempotencyKey,
    p_contract_version: contractVersion,
    p_payload_fingerprint: payloadFingerprint,
    p_object_sha256: objectSha256,
    p_object_bytes: objectBytes,
  });
  if (error || !data || typeof data.intent_id !== "string") {
    console.error(JSON.stringify({ operation: "phase8_begin", code: "reservation_failed" }));
    return failure("reservation_failed", 409);
  }
  return json({ ok: true, intentId: data.intent_id, state: data.state, receipt: data.receipt ?? null });
});
