import { authenticatedAdmin, bucket, canonicalJson, failure, json, readJson, sha256Hex, validateV2DriveEnvelope } from "../_shared/common.ts";

function encodeCursor(snapshotId: string, sequence: number): string {
  return btoa(`${snapshotId}:${sequence}`).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}
function decodeCursor(value: unknown): { snapshotId: string; sequence: number } | null {
  if (typeof value !== "string" || value.length > 128 || !/^[A-Za-z0-9_-]+$/.test(value)) return null;
  try {
    const raw = atob(value.replaceAll("-", "+").replaceAll("_", "/"));
    const match = /^([0-9a-f-]{36}):(0|[1-9][0-9]*)$/i.exec(raw);
    if (!match) return null;
    const sequence = Number(match[2]);
    return Number.isSafeInteger(sequence) ? { snapshotId: match[1], sequence } : null;
  } catch { return null; }
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return failure("method_not_allowed", 405);
  const auth = await authenticatedAdmin(request);
  if (!auth) return failure("unauthorized", 401);
  const body = await readJson(request);
  if (!body || (body.action !== "begin" && body.action !== "page")) return failure("request_invalid", 400);
  let snapshotId: string;
  let after: number;
  let resumedFromCursor: string | null = null;
  if (body.action === "begin") {
    const { data, error } = await auth.admin.rpc("phase8_begin_drive_snapshot", { p_owner_id: auth.userId });
    if (error || !data?.snapshot_id || !Number.isSafeInteger(Number(data.high_water))) return failure("snapshot_unavailable", 503);
    snapshotId = data.snapshot_id;
    after = 0;
  } else {
    const cursor = decodeCursor(body.cursor);
    if (!cursor) return failure("cursor_invalid", 400);
    snapshotId = cursor.snapshotId;
    after = cursor.sequence;
    // A completed/expired snapshot must not trap this device permanently at
    // its old high-water mark. Validate the old owner-bound checkpoint before
    // creating a new snapshot, retaining the exact committed sequence.
    const { data: previous, error: previousError } = await auth.admin
      .from("phase8_drive_snapshots").select("high_water,expires_at")
      .eq("id", snapshotId).eq("owner_id", auth.userId).maybeSingle();
    const priorHigh = Number(previous?.high_water);
    const priorExpiry = Date.parse(previous?.expires_at);
    if (previousError || !previous || !Number.isSafeInteger(priorHigh) ||
        !Number.isFinite(priorExpiry) || after > priorHigh) return failure("cursor_unavailable", 404);
    if (after === priorHigh || priorExpiry <= Date.now()) {
      const { data: renewed, error } = await auth.admin.rpc("phase8_begin_drive_snapshot", { p_owner_id: auth.userId });
      if (error || !renewed?.snapshot_id || Number(renewed.high_water) < after) {
        return failure("snapshot_unavailable", 503);
      }
      snapshotId = renewed.snapshot_id;
      resumedFromCursor = String(body.cursor);
    }
  }
  const limit = Number(body.limit ?? 50);
  if (!Number.isInteger(limit) || limit < 1 || limit > 100) return failure("page_limit_invalid", 400);
  const { data: page, error: pageError } = await auth.admin.rpc("phase8_read_drive_snapshot_page", {
    p_owner_id: auth.userId,
    p_snapshot_id: snapshotId,
    p_after_sequence: after,
    p_limit: limit,
  });
  if (pageError || !page || !Array.isArray(page.changes)) return failure("page_unavailable", 503);
  const changes: unknown[] = [];
  let total = 0;
  try {
    for (const row of page.changes as Record<string, unknown>[]) {
      if (row.operation === "drive_tombstone") {
        if (!row.mutation || typeof row.mutation !== "object") throw new Error("tombstone_missing");
        changes.push({ sequence: row.sequence, mutation: row.mutation });
        continue;
      }
      if (row.operation !== "drive_upsert" || typeof row.object_path !== "string" ||
          typeof row.source_identity !== "string" || typeof row.idempotency_key !== "string" ||
          typeof row.payload_fingerprint !== "string" || typeof row.object_sha256 !== "string") throw new Error("change_invalid");
      const { data: object, error } = await auth.admin.storage.from(bucket).download(row.object_path);
      if (error || !object) throw new Error("object_missing");
      const bytes = new Uint8Array(await object.arrayBuffer());
      total += bytes.byteLength;
      if (bytes.byteLength > 10 * 1024 * 1024 || total > 10 * 1024 * 1024) throw new Error("page_payload_too_large");
      if (await sha256Hex(bytes) !== row.object_sha256) throw new Error("object_checksum_invalid");
      const text = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
      const mutation = JSON.parse(text);
      if (canonicalJson(mutation) !== text) throw new Error("envelope_not_canonical");
      await validateV2DriveEnvelope(mutation, {
        userId: auth.userId,
        sourceIdentity: row.source_identity,
        idempotencyKey: row.idempotency_key,
        payloadFingerprint: row.payload_fingerprint,
      });
      changes.push({ sequence: row.sequence, mutation });
    }
  } catch {
    // An incomplete page is never returned with an advanced cursor.
    return failure("page_integrity_failed", 422);
  }
  const next = Number(page.next);
  const highWater = Number(page.high_water);
  if (!Number.isSafeInteger(next) || !Number.isSafeInteger(highWater) || next < after || next > highWater) {
    return failure("page_cursor_invalid", 422);
  }
  if (next === after && after < highWater) return failure("page_sequence_gap", 503);
  return json({
    ok: true,
    snapshotId,
    from: after,
    next,
    highWater,
    nextCursor: encodeCursor(snapshotId, next),
    hasMore: next < highWater,
    resumedFromCursor,
    changes,
  });
});
