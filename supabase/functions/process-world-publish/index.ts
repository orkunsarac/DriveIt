import { createClient } from "npm:@supabase/supabase-js@2";
import { sourceMatches } from "./source_contract.ts";
import { publishColumns, publishLookupFailure, resolveAdminKey } from "./admin_client.ts";
import {
  matchRoad, retryable, rules,
  type MatchedSection,
} from "./world_validation.ts";

const bucket = "world-drive-sources";
const providerId = "mapbox-map-matching-v5-driving";
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type PublishRow = {
  id: string;
  user_id: string;
  local_drive_id: string;
  status: string;
  source_path: string | null;
  source_ready_at: string | null;
  source_schema_version: number | null;
  telemetry_version: number | null;
  drive_score_algorithm_version: number | null;
  world_rules_version: number;
  raw_route_point_count: number | null;
  telemetry_point_count: number | null;
};

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status, headers: { "content-type": "application/json; charset=utf-8" },
  });
}

function error(code: string, status: number): Response {
  return json({ ok: false, error_code: code }, status);
}

function validationResponse(
  publishId: string,
  road: Record<string, unknown>,
): Response {
  const distance = Number(road.valid_distance_meters);
  return json({
    ok: true,
    publish_id: publishId,
    validation: {
      validated_road_id: road.validated_road_id ?? road.id,
      valid_distance_meters: distance,
      eligible_for_world: distance >= rules.minimumValidDistanceMeters,
      section_count: road.section_count,
    },
  });
}

function roadPayload(sections: MatchedSection[], result: Awaited<ReturnType<typeof matchRoad>>) {
  const line = (section: MatchedSection) => section.geometry.map(
    (point) => [point.longitude, point.latitude],
  );
  return {
    road: {
      provider_id: providerId,
      processing_version: rules.validatedRoadProcessingVersion,
      valid_distance_meters: result.validDistanceMeters,
      validation_status: result.status,
      confidence: result.confidence === null ? null
        : Math.min(1, Math.max(0, result.confidence)),
      direction_key: result.directionKey,
      average_heading_degrees: result.averageHeadingDegrees,
      section_count: sections.length,
      geometry: {
        type: "MultiLineString",
        coordinates: sections.map(line),
      },
    },
    sections: sections.map((section, order) => ({
      section_key: section.id,
      section_order: order,
      distance_meters: section.distanceMeters,
      confidence: section.confidence,
      source_trace_index: section.sourceTraceIndex,
      source_chunk_index: section.sourceChunkIndex,
      geometry: { type: "LineString", coordinates: line(section) },
    })),
  };
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return error("method_not_allowed", 405);
  const authHeader = request.headers.get("authorization") ?? "";
  if (!/^Bearer\s+[^\s]+$/i.test(authHeader)) return error("unauthorized", 401);
  const token = authHeader.replace(/^Bearer\s+/i, "");
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = resolveAdminKey(
    Deno.env.get("SUPABASE_SECRET_KEYS"),
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
  );
  if (!url || !serviceKey) return error("server_not_configured", 503);
  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: authError } = await admin.auth.getUser(token);
  if (authError || !userData.user) return error("unauthorized", 401);
  const userId = userData.user.id;
  let publishId: string;
  try {
    const body = await request.json();
    if (!body || typeof body.publish_id !== "string" ||
        !uuidPattern.test(body.publish_id)) return error("invalid_request", 400);
    publishId = body.publish_id;
  } catch {
    return error("invalid_request", 400);
  }

  const { data: rawPublish, error: lookupError } = await admin
    .from("world_publishes").select(publishColumns).eq("id", publishId).maybeSingle();
  if (lookupError) return publishLookupFailure(lookupError);
  const publish = rawPublish as PublishRow | null;
  if (!publish || publish.user_id !== userId) return error("not_found", 404);
  if (!publish.source_path || !publish.source_ready_at) {
    return error("source_not_ready", 409);
  }

  // Short-circuit before Storage or Mapbox; the claim RPC repeats this check
  // under a row lock to handle a concurrent request.
  const { data: existing, error: existingError } = await admin
    .from("world_validated_roads")
    .select("id,valid_distance_meters,section_count")
    .eq("publish_id", publishId).maybeSingle();
  if (existingError) return error("validation_lookup_failed", 503);
  if (existing) return validationResponse(publishId, existing);

  const { data: claim, error: claimError } = await admin.rpc(
    "claim_world_publish_validation",
    { p_publish_id: publishId, p_user_id: userId },
  );
  if (claimError || !claim) return error("claim_failed", 503);
  if (claim.state === "exists") return validationResponse(publishId, claim);
  if (claim.state === "busy") return error("processing", 202);
  if (claim.state !== "claimed" || typeof claim.claim_token !== "string") {
    return error(String(claim.state ?? "claim_failed"), 409);
  }
  const claimToken: string = claim.claim_token;
  async function fail(code: string, isRetryable: boolean, status: number) {
    const { data: released, error: releaseError } = await admin.rpc(
      "fail_world_publish_validation",
      {
        p_publish_id: publishId, p_user_id: userId,
        p_claim_token: claimToken, p_retryable: isRetryable,
        p_error_code: code,
      },
    );
    if (releaseError) return error("state_update_failed", 503);
    if (released !== true) return error("validation_claim_expired", 409);
    return error(code, status);
  }
  if (publish.source_path !== `${userId}/${publish.id}.json`) {
    return await fail("source_mismatch", false, 422);
  }
  if (publish.source_schema_version !== rules.sourceSchemaVersion ||
      publish.telemetry_version !== rules.telemetryVersion ||
      publish.world_rules_version !== rules.worldRulesVersion ||
      publish.drive_score_algorithm_version !== rules.driveScoreAlgorithmVersion) {
    return await fail("unsupported_version", false, 422);
  }

  try {
    const { data: file, error: storageError } = await admin.storage
      .from(bucket).download(publish.source_path);
    if (storageError || !file) return await fail("source_download_failed", true, 503);
    let source: unknown;
    try {
      source = JSON.parse(await file.text());
    } catch {
      return await fail("source_invalid", false, 422);
    }
    if (!sourceMatches(source, publish)) {
      return await fail("source_mismatch", false, 422);
    }
    const mapboxToken = Deno.env.get("MAPBOX_ACCESS_TOKEN") ?? "";
    const result = await matchRoad(
      source.raw_route,
      source.canonical_telemetry.map((p) => ({
        latitude: p.latitude, longitude: p.longitude, timestamp: p.timestamp,
      })),
      mapboxToken,
      async (uri, form, timeoutMs) => {
        const response = await fetch(uri, {
          method: "POST",
          headers: { "content-type": "application/x-www-form-urlencoded; charset=utf-8" },
          body: form.toString(),
          signal: AbortSignal.timeout(timeoutMs),
        });
        return { status: response.status, body: await response.text() };
      },
    );
    if (retryable(result.failureKind)) {
      return await fail("mapbox_" + result.failureKind.toLowerCase(), true, 503);
    }
    if (!result.sections.length) {
      return await fail("validation_" + result.failureKind.toLowerCase(), false, 422);
    }
    const payload = roadPayload(result.sections, result);
    const { data: persisted, error: persistError } = await admin.rpc(
      "finish_world_publish_validation",
      {
        p_publish_id: publishId, p_user_id: userId,
        p_claim_token: claimToken,
        p_road: payload.road, p_sections: payload.sections,
      },
    );
    if (persistError || !persisted) {
      // The database may have committed even if its HTTP response was lost.
      const { data: committed } = await admin.from("world_validated_roads")
        .select("id,valid_distance_meters,section_count")
        .eq("publish_id", publishId).maybeSingle();
      if (committed) return validationResponse(publishId, committed);
      return await fail("validation_persist_failed", true, 503);
    }
    if (persisted.state === "created" || persisted.state === "exists") {
      return validationResponse(publishId, persisted);
    }
    return error("validation_claim_expired", 409);
  } catch {
    // Unexpected network/processing error remains retryable; never leak source,
    // telemetry, credentials or provider error bodies to logs or response.
    return await fail("validation_retryable", true, 503);
  }
});
