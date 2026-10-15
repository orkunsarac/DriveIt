import { authenticatedAdmin, bucket, canonicalJson, failure, isSha256, json, readJson, validateV2DriveEnvelope } from "../_shared/common.ts";

Deno.serve(async (request) => {
  if (request.method !== "POST") return failure("method_not_allowed", 405);
  const auth = await authenticatedAdmin(request);
  if (!auth) return failure("unauthorized", 401);
  const body = await readJson(request);
  if (!body || typeof body.intentId !== "string") return failure("request_invalid", 400);
  const { data: intent, error: intentError } = await auth.admin
    .from("phase8_drive_upload_intents")
    .select("id,owner_id,idempotency_key,source_identity,contract_version,payload_fingerprint,object_sha256,object_bytes,staging_path,state,receipt")
    .eq("id", body.intentId).eq("owner_id", auth.userId).maybeSingle();
  if (intentError || !intent) return failure("intent_not_found", 404);
  const { data: cancelled, error: cancellationError } = await auth.admin.from("phase8_drive_cancellations")
    .select("source_identity").eq("owner_id", auth.userId).eq("source_identity", intent.source_identity).maybeSingle();
  if (cancellationError) return failure("cancellation_check_unavailable", 503);
  if (cancelled) return failure("source_cancelled", 409);
  // ACK replay must pass the DB tombstone/fencing barrier too.
  if (intent.state !== "staging" && intent.state !== "finalized") return failure("intent_not_finalizable", 409);
  const { data: object, error: objectError } = await auth.admin.storage.from(bucket).download(intent.staging_path);
  if (objectError || !object) return failure("staged_object_missing", 409);
  const bytes = new Uint8Array(await object.arrayBuffer());
  if (bytes.byteLength !== intent.object_bytes || bytes.byteLength > 10 * 1024 * 1024) return failure("staged_object_size_mismatch", 422);
  const objectHashBuffer = await crypto.subtle.digest("SHA-256", bytes);
  const objectSha256 = [...new Uint8Array(objectHashBuffer)].map((b) => b.toString(16).padStart(2, "0")).join("");
  if (!isSha256(intent.object_sha256) || objectSha256 !== intent.object_sha256) return failure("staged_object_hash_mismatch", 422);
  let text: string;
  let envelope: unknown;
  try {
    text = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
    envelope = JSON.parse(text);
    canonicalJson(envelope);
  } catch { return failure("staged_envelope_invalid", 422); }
  try {
    const validated = await validateV2DriveEnvelope(envelope, {
      userId: auth.userId,
      sourceIdentity: intent.source_identity,
      idempotencyKey: intent.idempotency_key,
      payloadFingerprint: intent.payload_fingerprint,
    });
    // Require exact canonical envelope bytes; no alternate whitespace/number
    // encoding can hash to an accepted semantically equivalent object.
    if (canonicalJson(envelope) !== text) return failure("envelope_not_canonical", 422);
    const { data: receipt, error } = await auth.admin.rpc("phase8_finalize_drive_upload_fenced", {
      p_owner_id: auth.userId,
      p_intent_id: intent.id,
      p_drive_id: validated.driveId,
      p_payload_fingerprint: intent.payload_fingerprint,
      p_object_sha256: intent.object_sha256,
      p_object_bytes: intent.object_bytes,
      p_device_id: body.deviceId ?? null,
      p_session_id: body.sessionId ?? null,
      p_fencing_token: body.fencingToken ?? null,
    });
    if (error || !receipt) {
      console.error(JSON.stringify({ operation: "phase8_finalize", code: "transaction_failed" }));
      return failure("finalization_conflict", 409);
    }
    return json({ ok: true, receipt });
  } catch {
    return failure("staged_envelope_rejected", 422);
  }
});
