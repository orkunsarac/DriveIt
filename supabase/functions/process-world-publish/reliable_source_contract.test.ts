import { sourceMatches } from "./source_contract.ts";
import { RequestSourceLoader, ScoringSourceError } from "./world_scoring_stage.ts";
function assert(value: unknown) { if (!value) throw new Error("reliable source contract failed"); }
const firstAt = "2026-10-06T00:00:00.000001Z", lastAt = "2026-10-06T00:00:10.000002Z";
const toMicros = (iso: string) => Date.parse(iso) * 1000 + Number((iso.match(/\.(\d+)Z$/)?.[1] ?? "").padEnd(6, "0").slice(3) || 0);
function reliableSource(id = "p", drive = "d") {
  const point = (timestamp: string, longitude: number, distance: number) => ({
    latitude: 40, longitude, timestamp, timestamp_micros: String(toMicros(timestamp)),
    speed_mps: 10, heading_degrees: 90, altitude_meters: 50, accuracy_meters: 4,
    distance_from_previous_meters: distance, acceleration_mps2: 0,
    break_before: false, gap_duration_micros: 0,
    speed_source: "native", acceleration_reliable: true,
  });
  return {
    publish_id: id, local_drive_id: drive, schema_version: 2, telemetry_version: 1,
    drive_score_algorithm_version: 1, world_rules_version: 6,
    score_calculation_mode: "reliable_intervals", score_calculation_version: 1,
    telemetry_reliability: { reliabilityPolicyVersion: 1,
      startedAtMicros: toMicros(firstAt), stopRequestedAtMicros: toMicros(lastAt) },
    started_at: firstAt, ended_at: lastAt, recorded_distance_meters: 10,
    raw_route: [{ latitude: 40, longitude: 29, break_before: false },
      { latitude: 40, longitude: 29.001, break_before: false }],
    canonical_telemetry: [point(firstAt, 29, 0), point(lastAt, 29.001, 10)],
  };
}
function row(source: ReturnType<typeof reliableSource>) {
  return { id: source.publish_id, local_drive_id: source.local_drive_id, user_id: "owner",
    source_path: `owner/${source.publish_id}.json`, source_ready_at: "ready",
    source_schema_version: 2, telemetry_version: 1, drive_score_algorithm_version: 1,
    world_rules_version: 6, raw_route_point_count: 2, telemetry_point_count: 2 };
}
Deno.test("reliable schema 2 is accepted only after exact source contract validation", async () => {
  const source = reliableSource(), metadata = row(source);
  assert(sourceMatches(source, metadata));
  const loader = new RequestSourceLoader({
    metadata: async () => [metadata],
    download: async () => { throw new Error("seed should avoid duplicate storage read"); },
  }, new Map([[source.publish_id, source]]));
  await loader.prepare([source.publish_id]);
  assert((await loader.load(source.publish_id, source.local_drive_id)).schema_version === 2);
});
Deno.test("schema 2 with missing quality or altered timestamp is rejected", async () => {
  const source = reliableSource(), metadata = row(source);
  const broken = { ...source, canonical_telemetry: source.canonical_telemetry.map((point, i) =>
    i ? point : { ...point, timestamp_micros: "1" }) };
  const loader = new RequestSourceLoader({ metadata: async () => [metadata], download: async () => broken });
  await loader.prepare([source.publish_id]);
  try { await loader.load(source.publish_id, source.local_drive_id); throw new Error("invalid source accepted"); }
  catch (error) { assert(error instanceof ScoringSourceError && error.code === "world_source_invalid"); }
});
Deno.test("unknown source schemas cannot be relabelled as legacy", () => {
  assert(!sourceMatches({ schema_version: 99 }, {
    id: "p", local_drive_id: "d", source_schema_version: 99,
    telemetry_version: 1, drive_score_algorithm_version: 1,
    world_rules_version: 6, raw_route_point_count: 2, telemetry_point_count: 2,
  }));
});
