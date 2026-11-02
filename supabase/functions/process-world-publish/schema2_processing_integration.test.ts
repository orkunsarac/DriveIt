import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import "../../../test/fixtures/world_scoring_boundary.generated.js";
import { sourceMatches, type PublishedSource } from "./source_contract.ts";
import { matchRoad } from "./world_validation.ts";
import { type CandidateSnapshot } from "./active_world_overlap_stage.ts";
import { analyzeActiveCandidates } from "./world_road_overlap.ts";
import { analyzeWorldScoring, RequestSourceLoader, type SourceRow } from "./world_scoring_stage.ts";
import { planWorldMutation, commitWorldMutation } from "./world_mutation.ts";
import { commitEmptyWorldPlan, planEmptyWorld } from "./active_world_empty_planner.ts";

const cases = JSON.parse(readFileSync(new URL("../../../test/fixtures/active_world_scoring.json", import.meta.url), "utf8"));
const fixture = cases.find((entry: { name: string }) => entry.name === "A-challenger-better");
const start = "2026-10-06T00:00:00.000001Z";
const scalePoint = (point: Record<string, unknown>) => ({
  ...point,
  longitude: Number(point.longitude) * 1.25,
  distance_from_previous_meters: Number(point.distance_from_previous_meters) * 1.25,
});
const micros = (iso: string) => {
  const fraction = (iso.match(/\.(\d+)Z$/)?.[1] ?? "").padEnd(6, "0");
  return Date.parse(iso) * 1000 + Number(fraction.slice(3) || 0);
};
function makeSource(publishId: string, driveId: string, points: Record<string, unknown>[], corrupt?: string): PublishedSource {
  const values: Record<string, unknown>[] = points.map((original, index) => {
    const point = scalePoint(original) as Record<string, unknown>;
    const timestamp = String(point.timestamp);
    return {
      ...point,
      break_before: corrupt === "gap" && index === 160 ? true : false,
      gap_duration_micros: corrupt === "gap" && index === 160 ? 900_000_000 : 0,
      speed_source: "native",
      acceleration_reliable: true,
      timestamp_micros: String(micros(timestamp)),
    };
  });
  const first = String(values[0].timestamp), last = String(values.at(-1)!.timestamp);
  return {
    schema_version: 2, publish_id: publishId, local_drive_id: driveId,
    telemetry_version: 1, drive_score_algorithm_version: 1, world_rules_version: 6,
    score_calculation_mode: "reliable_intervals", score_calculation_version: 1,
    telemetry_reliability: { reliabilityPolicyVersion: 1,
      startedAtMicros: micros(first), stopRequestedAtMicros: micros(last) },
    started_at: first, ended_at: last, recorded_distance_meters: 5000,
    raw_route: values.map((point) => ({ latitude: Number(point.latitude),
      longitude: Number(point.longitude), break_before: point.break_before === true })),
    canonical_telemetry: values as PublishedSource["canonical_telemetry"],
  };
}
function row(id: string, drive: string, owner: string, source: PublishedSource): SourceRow {
  return { id, local_drive_id: drive, user_id: owner, source_path: `${owner}/${id}.json`, source_ready_at: "ready",
    source_schema_version: 2, telemetry_version: 1, drive_score_algorithm_version: 1, world_rules_version: 6,
    raw_route_point_count: source.raw_route.length, telemetry_point_count: source.canonical_telemetry.length };
}
const cloneRoad = (id: string, driveId: string, sectionId: string) => ({
  id, driveId, directionKey: "east", processingVersion: 3,
  sections: [{ id: sectionId, distanceMeters: 5000,
    geometry: [{ latitude: 0, longitude: 0 }, { latitude: 0, longitude: 0.0449660181362269 }] }],
});
function snapshot() {
  const firstRoad = cloneRoad("validated-a", "drive-a", "section-a");
  const challenger = cloneRoad("validated-b", "drive-b", "section-b");
  const trace = { id: "trace-a", sourcePublishId: "publish-a", sourceDriveId: "drive-a",
    validatedRoadId: firstRoad.id, matchedSectionId: "section-a", startOffsetMeters: 0,
    endOffsetMeters: 5000, directionKey: "east", activeFromGeneration: "1", activeToGeneration: null,
    processingVersion: 3, minLatitude: 0, maxLatitude: 0, minLongitude: 0,
    maxLongitude: 0.0449660181362269, createdAt: start, updatedAt: start };
  const value: CandidateSnapshot = { generation: "1", isEmpty: false, candidates: [trace], roads: [firstRoad] };
  return { value, firstRoad, challenger };
}

test("schema 2 processing end-to-end: source/ownership, route, reliable comparison, winner plan and CAS commit", async () => {
  const first = makeSource("publish-a", "drive-a", fixture.firstTelemetry);
  const second = makeSource("publish-b", "drive-b", fixture.secondTelemetry);
  const { value, firstRoad, challenger } = snapshot();
  const rowA = row("publish-a", "drive-a", "owner-a", first);
  const rowB = row("publish-b", "drive-b", "owner-b", second);
  assert.equal(sourceMatches(second, rowB), true);

  // Real route preprocessing and Mapbox matching code with a synthetic provider.
  const routeResult = await matchRoad(second.raw_route, second.canonical_telemetry, "test-mapbox-token",
    async (_url, form) => ({ status: 200, body: JSON.stringify({ code: "Ok", matchings: [{ confidence: 0.95,
      geometry: { type: "LineString", coordinates: form.get("coordinates")!.split(";")
        .map((pair) => pair.split(",").map(Number)) } }] }) }));
  assert.equal(routeResult.sections.length, 1);
  assert.equal(routeResult.status, "validated");
  assert.ok(routeResult.validDistanceMeters >= 5000);

  // Real active road overlap, then the same scoring and mutation stages used by index.ts.
  const overlaps = analyzeActiveCandidates(challenger, value.candidates, [firstRoad]);
  assert.equal(overlaps.length, 1);
  assert.equal(overlaps[0].comparisonEligible, true);
  const downloads: string[] = [];
  const loader = new RequestSourceLoader({
    async metadata(ids) { assert.deepEqual(ids, ["publish-b", "publish-a"]); return [rowA, rowB]; },
    async download(path) { downloads.push(path); return path === rowA.source_path ? first : second; },
  });
  const stage = await analyzeWorldScoring("publish-b", challenger, [firstRoad], overlaps, loader);
  assert.equal(stage.state, "scoring_completed");
  if (stage.state !== "scoring_completed") return;
  assert.deepEqual(downloads, ["owner-a/publish-a.json", "owner-b/publish-b.json"]);
  const scored = stage.inputs[0].scoring;
  assert.equal(scored.status, "success");
  assert.ok(scored.windows.length > 0);
  for (const window of scored.windows) {
    for (const score of [window.comparison.firstLocalScore, window.comparison.secondLocalScore]) {
      if (score) assert.equal((score as unknown as { calculationMode: string }).calculationMode, "reliable_intervals");
    }
  }
  assert.ok(scored.winningRegions.length > 0, "reliable comparison produces an eligible winner region");
  assert.ok(!JSON.stringify(stage).includes("canonical_telemetry"));
  assert.ok(!JSON.stringify(stage).includes("test-mapbox-token"));

  const mutation = planWorldMutation(value, challenger, "publish-b", stage.inputs, start);
  assert.equal(mutation.baseGeneration, "1");
  assert.equal(mutation.generation, "2");
  assert.ok(mutation.createTraces.some((entry) => entry.sourcePublishId === "publish-b"));
  let saved = false;
  const rpc = async (name: string, args: Record<string, unknown>) => {
    assert.equal(name, "commit_active_world_mutation");
    assert.equal(args.p_publish_id, "publish-b");
    if (args.p_expected_generation !== "1") return { data: { state: "stale_generation" }, error: null };
    if (saved) return { data: { state: "already_processed", generation: "2" }, error: null };
    saved = true;
    return { data: { state: "committed", generation: "2" }, error: null };
  };
  assert.equal((await commitWorldMutation(mutation, "publish-b", rpc)).state, "committed");
  assert.equal((await commitWorldMutation(mutation, "publish-b", rpc)).state, "already_processed");

  // Empty-world first publication follows the same version-1 World rules and server RPC contract.
  const emptyPlan = planEmptyWorld({ generation: 0, driveScoreAlgorithmVersion: 1,
    sourceDriveSessionId: "drive-b", validatedRoadId: challenger.id,
    directionKey: "east", processingVersion: 3, sections: challenger.sections });
  assert.equal(emptyPlan.generation, 1);
  assert.equal(emptyPlan.traces.length, 1);
  let activated = false;
  const activationRpc = async (name: string, args: Record<string, unknown>) => {
    assert.equal(name, "activate_empty_world_publish");
    assert.equal(args.p_publish_id, "publish-b");
    assert.equal(args.p_expected_generation, 0);
    if (activated) return { data: { state: "already_processed", generation: 1 }, error: null };
    activated = true;
    return { data: { state: "committed", generation: 1 }, error: null };
  };
  assert.equal((await commitEmptyWorldPlan("publish-b", emptyPlan, activationRpc)).state, "committed");
  assert.equal((await commitEmptyWorldPlan("publish-b", emptyPlan, activationRpc)).state, "already_processed");
});

test("schema 1 and schema 2 overlap is explicitly rejected before scoring", async () => {
  const legacy = { ...makeSource("publish-a", "drive-a", fixture.firstTelemetry), schema_version: 1,
    score_calculation_mode: undefined, score_calculation_version: undefined, telemetry_reliability: undefined } as unknown as PublishedSource;
  const reliable = makeSource("publish-b", "drive-b", fixture.secondTelemetry);
  const { value, challenger, firstRoad } = snapshot();
  const loader = new RequestSourceLoader({ async metadata() { return [
    { ...row("publish-a", "drive-a", "owner-a", legacy), source_schema_version: 1 },
    row("publish-b", "drive-b", "owner-b", reliable),
  ]; }, async download(path) { return path.includes("publish-a") ? legacy : reliable; } });
  const result = await analyzeWorldScoring("publish-b", challenger, [firstRoad],
    analyzeActiveCandidates(challenger, value.candidates, [firstRoad]), loader);
  assert.deepEqual(result, { state: "failure", errorCode: "world_score_mixed_source_modes" });
});

test("GPS gap inside schema 2 window creates an invalid boundary, not a continuous winner", async () => {
  const first = makeSource("publish-a", "drive-a", fixture.firstTelemetry);
  const second = makeSource("publish-b", "drive-b", fixture.secondTelemetry, "gap");
  const { value, challenger, firstRoad } = snapshot();
  const loader = new RequestSourceLoader({ async metadata() { return [
    row("publish-a", "drive-a", "owner-a", first), row("publish-b", "drive-b", "owner-b", second),
  ]; }, async download(path) { return path.includes("publish-a") ? first : second; } });
  const result = await analyzeWorldScoring("publish-b", challenger, [firstRoad],
    analyzeActiveCandidates(challenger, value.candidates, [firstRoad]), loader);
  assert.equal(result.state, "scoring_completed");
  if (result.state !== "scoring_completed") return;
  const score = result.inputs[0].scoring;
  assert.ok(score.windows.some((window) => window.state === "invalid"));
  assert.ok(score.winningRegions.every((region) => region.winningDistanceMeters < 5000));
});

test("source owner/path mismatch and insufficient whole-drive telemetry fail closed", async () => {
  const first = makeSource("publish-a", "drive-a", fixture.firstTelemetry);
  const second = makeSource("publish-b", "drive-b", fixture.secondTelemetry);
  const { value, challenger, firstRoad } = snapshot();
  const mismatched = new RequestSourceLoader({ async metadata() { return [
    { ...row("publish-a", "drive-a", "owner-a", first), source_path: "owner-b/publish-a.json" },
    row("publish-b", "drive-b", "owner-b", second),
  ]; }, async download() { return first; } });
  const overlaps = analyzeActiveCandidates(challenger, value.candidates, [firstRoad]);
  assert.deepEqual(await analyzeWorldScoring("publish-b", challenger, [firstRoad], overlaps, mismatched),
    { state: "failure", errorCode: "world_source_mismatch" });

  const insufficient = { ...second,
    telemetry_reliability: { ...second.telemetry_reliability!, startedAtMicros: micros(String(second.started_at)) - 10_000_000_000 },
    started_at: new Date(micros(String(second.started_at)) - 10_000_000_000).toISOString() };
  const poor = new RequestSourceLoader({ async metadata() { return [
    row("publish-a", "drive-a", "owner-a", first), row("publish-b", "drive-b", "owner-b", insufficient),
  ]; }, async download(path) { return path.includes("publish-a") ? first : insufficient; } });
  assert.deepEqual(await analyzeWorldScoring("publish-b", challenger, [firstRoad], overlaps, poor),
    { state: "failure", errorCode: "world_source_invalid" });
});
