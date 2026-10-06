import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import { sourceMatches } from "./source_contract.ts";
import { publishColumns, publishLookupFailure, resolveAdminKey } from "./admin_client.ts";
import { planEmptyWorld } from "./active_world_empty_planner.ts";
import { sectionCoordinates, sectionDistanceMeters } from "./validated_section_geojson.ts";
import { evaluateCandidateSnapshot } from "./active_world_overlap_stage.ts";
import { analyzeWorldScoring, RequestSourceLoader, type SourceRow } from "./world_scoring_stage.ts";
import { planWorldMutation, commitWorldMutation } from "./world_mutation.ts";
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

function safeDbCode(error: unknown): string | null {
  if (!error || typeof error !== "object") return null;
  const code = (error as { code?: unknown }).code;
  return typeof code === "string" && /^[A-Z0-9_]{1,32}$/.test(code) ? code : null;
}

function logWorldStage(stage: string, publishId: string): void {
  console.info(JSON.stringify({ stage, publish_id: publishId }));
}

function logWorldStageFailure(
  operation: string,
  publishId: string,
  errorCode: string,
  error?: unknown,
): void {
  console.error(JSON.stringify({
    stage: operation,
    operation,
    publish_id: publishId,
    error_code: errorCode,
    safe_db_code: safeDbCode(error),
  }));
}

async function activateEmptyWorld(admin: SupabaseClient, publishId: string, localDriveId: string, sourceSeed?: unknown): Promise<Response> {
  const { data: road, error: roadError } = await admin.from("world_validated_roads")
    .select("id,valid_distance_meters,section_count,processing_version,direction_key")
    .eq("publish_id", publishId).maybeSingle();
  if (roadError || !road) {
    logWorldStageFailure("active_world_road_lookup", publishId, "validated_road_lookup_failed", roadError);
    return error("validated_road_lookup_failed", 503);
  }
  const { data: completed, error: completedError } = await admin.from("world_active_world_generations")
    .select("generation,operation_id,trace_count").eq("source_publish_id", publishId).maybeSingle();
  if (completedError) return error("active_world_lookup_failed", 503);
  if (completed) return json({ ok: true, publish_id: publishId,
    validation: { validated_road_id: road.id, valid_distance_meters: Number(road.valid_distance_meters),
      eligible_for_world: Number(road.valid_distance_meters) >= rules.minimumValidDistanceMeters,
      section_count: Number(road.section_count) }, active_world: { state: "already_processed", ...completed } });
  if (!(Number(road.valid_distance_meters) >= rules.minimumValidDistanceMeters)) return error("world_ineligible", 422);
  const { data: rawSections, error: sectionsError } = await admin.rpc(
    "get_world_validated_road_sections_for_processing_exact",
    { p_validated_road_id: road.id },
  );
  if (sectionsError || !Array.isArray(rawSections)) {
    logWorldStageFailure("active_world_sections_lookup", publishId, "validated_sections_lookup_failed", sectionsError);
    return error("validated_sections_lookup_failed", 503);
  }
  const distances = rawSections.map((section) => sectionDistanceMeters(section.distance_meters));
  if (distances.some((distance) => distance === null)) {
    logWorldStageFailure("active_world_section_distance", publishId, "validated_sections_invalid");
    return error("validated_sections_invalid", 503);
  }
  const sections = rawSections.map((section, index) => ({
    id: String(section.section_key),
    distanceMeters: distances[index]!,
    geometry: sectionCoordinates(section.geometry) ?? [],
  }));
  if (sections.some((section) => section.geometry.length < 2)) {
    logWorldStageFailure("active_world_section_geometry", publishId, "validated_sections_invalid");
    return error("validated_sections_invalid", 503);
  }
  logWorldStage("validated_sections_loaded", publishId);
  // One read-only snapshot prevents mixing temporal generations. Even when
  // spatial candidates are empty a non-empty world must not run Stage 1.
  const { data: candidateSnapshot, error: candidateError } = await admin.rpc(
    "get_active_world_mutation_snapshot", { p_challenger_road_id: road.id },
  );
  if (candidateError || !candidateSnapshot) {
    logWorldStageFailure("active_world_candidates", publishId, "active_world_candidates_failed", candidateError);
    return error("active_world_candidates_failed", 503);
  }
  let overlapStage;
  try {
    overlapStage = evaluateCandidateSnapshot({ id: String(road.id), driveId: localDriveId, sections }, candidateSnapshot);
  } catch {
    logWorldStageFailure("active_world_overlap", publishId, "active_world_overlap_invalid");
    return error("active_world_overlap_invalid", 503);
  }
  if (overlapStage.state === "overlaps_ready" || overlapStage.snapshot.generation !== "0") {
    logWorldStage("active_world_overlap_completed", publishId);
    const loader = new RequestSourceLoader({
      async metadata(ids) {
        const { data, error: lookupError } = await admin.from("world_publishes")
          .select(publishColumns).in("id", ids);
        if (lookupError || !data) throw new Error("lookup");
        return data as unknown as SourceRow[];
      },
      async download(path) {
        const { data, error: storageError } = await admin.storage.from(bucket).download(path);
        if (storageError || !data) throw new Error("download");
        return JSON.parse(await data.text());
      },
    }, sourceSeed === undefined ? new Map() : new Map([[publishId, sourceSeed]]));
    const scoring = await analyzeWorldScoring(publishId,
      { id: String(road.id), driveId: localDriveId, sections },
      overlapStage.snapshot.roads, overlapStage.overlaps, loader);
    if (scoring.state === "failure") {
      logWorldStageFailure("active_world_scoring", publishId, scoring.errorCode);
      return error(scoring.errorCode, 503);
    }
    logWorldStage("active_world_scoring_completed", publishId);
    let committed;
    try {
      const plan = planWorldMutation(overlapStage.snapshot,
        {id:String(road.id),driveId:localDriveId,sections,directionKey:String(road.direction_key),
          processingVersion:Number(road.processing_version)}, publishId, scoring.inputs, new Date().toISOString());
      logWorldStage("active_world_mutation_planned", publishId);
      committed = await commitWorldMutation(plan,publishId,async(name,args)=>admin.rpc(name,args));
    } catch {
      logWorldStageFailure("active_world_mutation",publishId,"active_world_commit_failed");
      return error("active_world_commit_failed",503);
    }
    if(committed.state === "stale_generation") return error("stale_generation",409);
    if(committed.state !== "committed" && committed.state !== "already_processed") return error("active_world_commit_failed",503);
    logWorldStage("completed",publishId);
    return json({ok:true,publish_id:publishId,
      validation:{validated_road_id:road.id,valid_distance_meters:Number(road.valid_distance_meters),
        eligible_for_world:true,section_count:Number(road.section_count)},active_world:committed});
  }
  const plan = planEmptyWorld({
    generation: 0,
    driveScoreAlgorithmVersion: rules.driveScoreAlgorithmVersion,
    sourceDriveSessionId: localDriveId,
    validatedRoadId: String(road.id),
    directionKey: String(road.direction_key),
    processingVersion: Number(road.processing_version),
    sections,
  });
  logWorldStage("empty_world_plan_built", publishId);
  logWorldStage("activate_empty_world_rpc", publishId);
  const { data: activated, error: activationError } = await admin.rpc(
    "activate_empty_world_publish",
    {
      p_publish_id: publishId,
      p_expected_generation: plan.baseGeneration,
      p_drive_score_algorithm_version: plan.driveScoreAlgorithmVersion,
      p_world_rules_version: plan.validatedRoadProcessingVersion,
      p_expected_plan: plan,
    },
  );
  if (activationError || !activated) {
    logWorldStageFailure("active_world_commit", publishId, "active_world_commit_failed", activationError);
    return error("active_world_commit_failed", 503);
  }
  const state = String(activated.state ?? "");
  if (state === "committed" || state === "already_processed") {
    logWorldStage("completed", publishId);
    return json({
      ok: true,
      publish_id: publishId,
      validation: {
        validated_road_id: road.id,
        valid_distance_meters: Number(road.valid_distance_meters),
        eligible_for_world: Number(road.valid_distance_meters) >= rules.minimumValidDistanceMeters,
        section_count: Number(road.section_count),
      },
      active_world: activated,
    });
  }
  if (state === "world_comparison_not_implemented") return error(state, 409);
  if (state === "ineligible_validated_road") return error("world_ineligible", 422);
  if (state === "stale_generation") return error(state, 409);
  return error(state && /^[a-z0-9_]{1,64}$/.test(state) ? state : "active_world_commit_failed", 503);
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
  logWorldStage("publish_lookup", publishId);
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
  if (existing) {
    logWorldStage("validated_road_reuse", publishId);
    return activateEmptyWorld(admin, publishId, publish.local_drive_id);
  }

  const { data: claim, error: claimError } = await admin.rpc(
    "claim_world_publish_validation",
    { p_publish_id: publishId, p_user_id: userId },
  );
  if (claimError || !claim) return error("claim_failed", 503);
  if (claim.state === "exists") {
    logWorldStage("validated_road_reuse", publishId);
    return activateEmptyWorld(admin, publishId, publish.local_drive_id);
  }
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
      if (committed) return activateEmptyWorld(admin, publishId, publish.local_drive_id, source);
      return await fail("validation_persist_failed", true, 503);
    }
    if (persisted.state === "created" || persisted.state === "exists") {
      return activateEmptyWorld(admin, publishId, publish.local_drive_id, source);
    }
    return error("validation_claim_expired", 409);
  } catch {
    // Unexpected network/processing error remains retryable; never leak source,
    // telemetry, credentials or provider error bodies to logs or response.
    return await fail("validation_retryable", true, 503);
  }
});
