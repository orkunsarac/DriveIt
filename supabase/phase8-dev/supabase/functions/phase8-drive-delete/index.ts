import { authenticatedAdmin, canonicalSha256, failure, json, ownerScope, readJson, sha256Hex, uuidV4 } from "../_shared/common.ts";

// UID is derived from a verified Auth token, never from body.ownerId.
Deno.serve(async (request) => {
  if (request.method !== "POST") return failure("method_not_allowed", 405);
  const auth = await authenticatedAdmin(request);
  if (!auth) return failure("unauthorized", 401);
  const body = await readJson(request);
  if (!body) return failure("request_invalid", 400);
  if (body.action === "observe") {
    if (typeof body.sourceIdentity !== "string" || !uuidV4.test(body.sourceIdentity)) return failure("source_invalid", 422);
    const { data, error } = await auth.admin.from("phase8_drive_manifests")
      .select("source_identity,payload_fingerprint,change_sequence").eq("owner_id", auth.userId)
      .eq("source_identity", body.sourceIdentity).maybeSingle();
    if (error || !data) return failure("source_unavailable", 404);
    return json({ ok: true, ownerId: auth.userId, ...data });
  }
  const m = body.mutation as Record<string, unknown> | undefined;
  const p = m?.payload as Record<string, unknown> | undefined;
  if (!m || !p || m.version !== 2 || m.kind !== "driveTombstone" || m.ownerId !== auth.userId ||
      m.ownerScope !== ownerScope(auth.userId) || typeof m.sourceIdentity !== "string" || !uuidV4.test(m.sourceIdentity) ||
      typeof p.deletionId !== "string" || !uuidV4.test(p.deletionId) || p.causalVersion !== 1 ||
      !Number.isSafeInteger(p.observedRemoteSequence) || Number(p.observedRemoteSequence) < 1 ||
      typeof p.observedPayloadFingerprint !== "string" || !/^[0-9a-f]{64}$/.test(p.observedPayloadFingerprint) ||
      typeof p.deletedAt !== "string" || !p.deletedAt.endsWith("Z") || !Number.isFinite(Date.parse(p.deletedAt)) ||
      m.payloadFingerprint !== await canonicalSha256(p)) return failure("deletion_claim_invalid", 422);
  const key = `owner-sync-v2:${await sha256Hex(new TextEncoder().encode(`${ownerScope(auth.userId)}|${auth.userId}|driveTombstone|${p.deletionId}`))}`;
  if (m.idempotencyKey !== key) return failure("deletion_identity_invalid", 422);
  const { data, error } = await auth.admin.rpc("phase8_delete_drive", {
    p_owner_id: auth.userId, p_source_identity: m.sourceIdentity, p_deletion_id: p.deletionId,
    p_observed_sequence: p.observedRemoteSequence, p_observed_fingerprint: p.observedPayloadFingerprint, p_mutation: m,
  });
  if (error || !data) return failure("deletion_conflict", 409);
  return json({ ok: true, ...data });
});
