import { authenticatedAdmin, failure, json, readJson, uuidV4 } from "../_shared/common.ts";

// Coordinates are validated on every request, handed directly to transient
// private Realtime Broadcast, and are never inserted into an application table.
Deno.serve(async (request) => {
  if (request.method !== "POST") return failure("method_not_allowed", 405);
  const auth = await authenticatedAdmin(request);
  if (!auth) return failure("unauthorized", 401);
  const body = await readJson(request, 8192);
  if (!body || !uuidV4.test(String(body.groupId)) || !uuidV4.test(String(body.membershipId)) ||
      !uuidV4.test(String(body.publicationId)) || !Number.isSafeInteger(body.generation) ||
      !Number.isSafeInteger(body.sequence) || Number(body.sequence) < 1 ||
      typeof body.latitude !== "number" || typeof body.longitude !== "number" ||
      typeof body.accuracyMeters !== "number" || typeof body.recordedAt !== "string") {
    return failure("location_claim_invalid", 422);
  }
  const recordedAt = Date.parse(body.recordedAt);
  if (!Number.isFinite(recordedAt)) return failure("location_claim_invalid", 422);
  const { data, error } = await auth.admin.rpc("phase8_group_accept_location", {
    p_actor: auth.userId,
    p_group: body.groupId,
    p_membership: body.membershipId,
    p_publication: body.publicationId,
    p_generation: body.generation,
    p_lat: body.latitude,
    p_lon: body.longitude,
    p_accuracy: body.accuracyMeters,
    p_sequence: body.sequence,
    p_recorded_at: new Date(recordedAt).toISOString(),
  });
  if (error || !data || typeof data.topic !== "string" || data.event !== "location" ||
      typeof data.payload !== "object" || data.payload === null) {
    const generationChanged = error?.message?.includes("group_generation_revoked") === true;
    const code = generationChanged ? "group_generation_revoked" :
      error?.code === "42501" ? "publication_revoked" :
      error?.code === "22023" ? "location_invalid_or_stale" : "location_rejected";
    return failure(code, generationChanged ? 409 : error?.code === "42501" ? 403 : 409);
  }
  // Server-only credential. Clients cannot send to realtime.messages directly.
  const channel = auth.admin.channel(data.topic, { config: { private: true, broadcast: { ack: true } } });
  const ready = new Promise<void>((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error("realtime_timeout")), 4000);
    channel.subscribe((status, error) => {
      if (status === "SUBSCRIBED") { clearTimeout(timeout); resolve(); }
      else if (status === "CHANNEL_ERROR" || status === "TIMED_OUT") {
        clearTimeout(timeout); reject(error ?? new Error("realtime_unavailable"));
      }
    });
  });
  try {
    await ready;
    const response = await channel.send({ type: "broadcast", event: "location", payload: data.payload });
    if (response !== "ok") return failure("realtime_unavailable", 503);
    return json({ ok: true });
  } catch {
    return failure("realtime_unavailable", 503);
  } finally {
    await auth.admin.removeChannel(channel);
  }
});
