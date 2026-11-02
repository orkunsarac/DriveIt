import assert from "node:assert/strict";
import test from "node:test";
import { sourceMatches, type PublishSourceMetadata } from "./source_contract.ts";

const publish: PublishSourceMetadata = {
  id: "publish-id",
  local_drive_id: "drive-id",
  source_schema_version: 1,
  telemetry_version: 1,
  drive_score_algorithm_version: 1,
  world_rules_version: 6,
  raw_route_point_count: 2,
  telemetry_point_count: 2,
};

const telemetry = {
  latitude: 40.1,
  longitude: 29.1,
  timestamp: "2026-09-23T12:00:00.000123Z",
  speed_mps: 8.123456789,
  heading_degrees: 90,
  altitude_meters: 50,
  accuracy_meters: 2,
  distance_from_previous_meters: 8,
  acceleration_mps2: -0.123456789,
};

function source() {
  return {
    publish_id: "publish-id",
    local_drive_id: "drive-id",
    schema_version: 1,
    telemetry_version: 1,
    drive_score_algorithm_version: 1,
    world_rules_version: 6,
    started_at: "2026-09-23T11:58:00Z",
    ended_at: "2026-09-23T12:00:00Z",
    recorded_distance_meters: 5000,
    raw_route: [
      { latitude: 40.1, longitude: 29.1 },
      { latitude: 40.2, longitude: 29.2 },
    ],
    canonical_telemetry: [
      { ...telemetry },
      { ...telemetry, latitude: 40.2, longitude: 29.2 },
    ],
  };
}

test("full immutable-source contract matches server row", () => {
  assert.equal(sourceMatches(source(), publish), true);
});

test("publish, drive, versions and counts must match exactly", () => {
  for (const [sourceKey, badValue] of [
    ["publish_id", "other"],
    ["local_drive_id", "other"],
    ["schema_version", 2],
    ["telemetry_version", 2],
    ["drive_score_algorithm_version", 2],
    ["world_rules_version", 5],
  ] as const) {
    assert.equal(sourceMatches({ ...source(), [sourceKey]: badValue }, publish), false);
  }
  assert.equal(sourceMatches({ ...source(), raw_route: [] }, publish), false);
  assert.equal(sourceMatches({ ...source(), canonical_telemetry: [] }, publish), false);
});

test("all canonical fields and finite coordinates are required", () => {
  for (const field of [
    "latitude", "longitude", "timestamp", "speed_mps",
    "heading_degrees", "altitude_meters", "accuracy_meters",
    "distance_from_previous_meters", "acceleration_mps2",
  ]) {
    const corrupted = source();
    delete (corrupted.canonical_telemetry[0] as Record<string, unknown>)[field];
    assert.equal(sourceMatches(corrupted, publish), false, field);
  }
  const corrupted = source();
  corrupted.raw_route[0].latitude = Number.NaN;
  assert.equal(sourceMatches(corrupted, publish), false);
});

function micros(iso: string): number {
  const fraction = (iso.match(/\.(\d+)Z$/)?.[1] ?? "").padEnd(6, "0");
  return Date.parse(iso) * 1000 + Number(fraction.slice(3) || 0);
}

function reliableSource() {
  const first = { ...telemetry, timestamp: "2026-09-23T12:00:00.000123Z",
    break_before: false, gap_duration_micros: 0, speed_source: "native",
    acceleration_reliable: true, timestamp_micros: "1790164800000123" };
  const second = { ...first, latitude: 40.2, longitude: 29.2,
    timestamp: "2026-09-23T12:00:10.000124Z",
    timestamp_micros: "1790164810000124", distance_from_previous_meters: 8 };
  const started = first.timestamp, ended = second.timestamp;
  return {
    publish_id: "publish-id", local_drive_id: "drive-id", schema_version: 2,
    telemetry_version: 1, drive_score_algorithm_version: 1, world_rules_version: 6,
    score_calculation_mode: "reliable_intervals", score_calculation_version: 1,
    telemetry_reliability: { reliabilityPolicyVersion: 1,
      startedAtMicros: micros(started), stopRequestedAtMicros: micros(ended) },
    started_at: started, ended_at: ended, recorded_distance_meters: 5000,
    raw_route: [
      { latitude: 40.1, longitude: 29.1, break_before: false },
      { latitude: 40.2, longitude: 29.2, break_before: false },
    ], canonical_telemetry: [first, second],
  };
}

test("schema 2 reliable source contract validates lossless quality and time evidence", () => {
  const value = reliableSource();
  assert.equal(sourceMatches(value, { ...publish, source_schema_version: 2 }), true);
});

test("schema 2 rejects mixed, missing, tampered, and unsupported reliability evidence", () => {
  const valid = reliableSource();
  const row = { ...publish, source_schema_version: 2 };
  for (const changed of [
    { ...valid, score_calculation_mode: "legacy_v1" },
    { ...valid, score_calculation_version: 2 },
    { ...valid, telemetry_reliability: { ...valid.telemetry_reliability, reliabilityPolicyVersion: 2 } },
    { ...valid, raw_route: valid.raw_route.map((p, i) => i ? p : ({ ...p, break_before: undefined })) },
    { ...valid, canonical_telemetry: valid.canonical_telemetry.map((p, i) => i ? ({ ...p, break_before: true }) : p) },
    { ...valid, canonical_telemetry: valid.canonical_telemetry.map((p, i) => i ? p : ({ ...p, speed_source: "invented" })) },
    { ...valid, canonical_telemetry: valid.canonical_telemetry.map((p, i) => i ? p : ({ ...p, timestamp_micros: "1" })) },
  ]) assert.equal(sourceMatches(changed, row), false);
});
