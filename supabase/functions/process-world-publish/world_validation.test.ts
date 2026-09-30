import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import {
  chunk, distanceMeters, matchRoad, preprocess, retryable, rules,
  type Coordinate, type TelemetryPoint,
} from "./world_validation.ts";

const fixture = JSON.parse(readFileSync(
  new URL("../../../test/fixtures/world_server_parity.json", import.meta.url),
  "utf8",
));

function routeFor(encoded: unknown): Coordinate[] {
  if (Array.isArray(encoded)) return encoded.map(([latitude, longitude]) => ({ latitude, longitude }));
  const linear = (encoded as { linear: {
    count: number; latitude: number; longitude: number; latitude_step: number;
  } }).linear;
  return Array.from({ length: linear.count }, (_, i) => ({
    latitude: linear.latitude + i * linear.latitude_step,
    longitude: linear.longitude,
  }));
}

function indices(encoded: unknown): number[] {
  if (!Array.isArray(encoded)) return (encoded as { indices: number[] }).indices;
  return Array.from({ length: encoded[1] - encoded[0] + 1 }, (_, i) => encoded[0] + i);
}

test("shared fixture pins mirrored Dart rule values", () => {
  assert.deepEqual(fixture.rules, {
    source_schema_version: rules.sourceSchemaVersion,
    telemetry_version: rules.telemetryVersion,
    drive_score_algorithm_version: rules.driveScoreAlgorithmVersion,
    world_rules_version: rules.worldRulesVersion,
    validated_road_processing_version: rules.validatedRoadProcessingVersion,
    minimum_valid_distance_meters: rules.minimumValidDistanceMeters,
    minimum_useful_point_distance_meters: rules.minimumUsefulPointDistanceMeters,
    maximum_plausible_point_jump_meters: rules.maximumPlausiblePointJumpMeters,
    maximum_plausible_gap_average_speed_mps: rules.maximumPlausibleGapAverageSpeedMps,
    canonical_route_alignment_tolerance_meters: rules.canonicalRouteAlignmentToleranceMeters,
    map_matching_maximum_coordinates: rules.mapMatchingMaximumCoordinates,
    map_matching_chunk_overlap: rules.mapMatchingChunkOverlap,
    map_matching_radius_meters: rules.mapMatchingRadiusMeters,
    chunk_geometry_merge_tolerance_meters: rules.chunkGeometryMergeToleranceMeters,
    map_matching_timeout_ms: rules.mapMatchingTimeoutMs,
  });
});

for (const scenario of fixture.cases) {
  test(`TypeScript preprocessing/chunk parity: ${scenario.name}`, () => {
    const route = routeFor(scenario.route);
    const telemetry: TelemetryPoint[] = scenario.telemetry.map(
      ([latitude, longitude, timestamp]: [number, number, string]) =>
        ({ latitude, longitude, timestamp }),
    );
    const result = preprocess(route, telemetry);
    const expected = scenario.expected;
    assert.equal(result.inputPointCount, expected.input);
    assert.equal(result.acceptedPointCount, expected.accepted);
    assert.equal(result.invalidPointCount, expected.invalid);
    assert.equal(result.tooClosePointCount, expected.too_close);
    assert.equal(result.jumpSplitCount, expected.jump_splits);
    assert.equal(result.plausibleGapContinuationCount, expected.plausible_gaps);
    assert.equal(result.traces.length, expected.traces.length);
    result.traces.forEach((trace, i) => {
      assert.equal(trace.index, i);
      assert.deepEqual(trace.points, indices(expected.traces[i]).map((index) => route[index]));
    });
    const chunks = chunk(result.traces);
    assert.equal(chunks.length, expected.chunks.length);
    chunks.forEach((item, i) => {
      assert.deepEqual(item.points, indices(expected.chunks[i]).map((index) => route[index]));
    });
  });
}

function ok(...matchings: { geometry: number[][]; confidence: number | null }[]) {
  return JSON.stringify({
    code: "Ok",
    matchings: matchings.map((matching) => ({
      geometry: { type: "LineString", coordinates: matching.geometry },
      confidence: matching.confidence,
    })),
  });
}

test("Mapbox POST contract, section parsing, distance, confidence and direction", async () => {
  const route = [{ latitude: 40, longitude: 29 }, { latitude: 40, longitude: 29.001 }];
  let calls = 0;
  const result = await matchRoad(route, [], "test-token", async (uri, form, timeoutMs) => {
    calls++;
    assert.match(uri, /matching\/v5\/mapbox\/driving\?access_token=test-token$/);
    assert.equal(form.get("coordinates"), "29,40;29.001,40");
    assert.equal(form.get("radiuses"), "25;25");
    assert.equal(form.get("geometries"), "geojson");
    assert.equal(form.get("overview"), "full");
    assert.equal(form.get("steps"), "false");
    assert.equal(form.get("tidy"), "true");
    assert.equal(timeoutMs, 15000);
    return { status: 200, body: ok({
      geometry: [[29, 40], [29.001, 40]], confidence: 0.84,
    }) };
  });
  assert.equal(calls, 1);
  assert.equal(result.status, "validated");
  assert.equal(result.sections.length, 1);
  assert.equal(result.sections[0].id, "t0:c0:m0");
  assert.equal(result.sections[0].sourceTraceIndex, 0);
  assert.equal(result.sections[0].sourceChunkIndex, 0);
  assert.equal(result.confidence, 0.84);
  assert.equal(result.directionKey, "40.00000,29.00000>40.00000,29.00100");
  assert.equal(result.validDistanceMeters, distanceMeters(route[0], route[1]));
  assert.ok(Math.abs(result.averageHeadingDegrees! - 89.9997) < 0.01);
});

test("adjacent chunks merge shared geometry and weight confidence by distance", async () => {
  const route = routeFor({
    linear: { count: 101, latitude: 40, longitude: 29, latitude_step: 0.0002 },
  });
  let call = 0;
  const result = await matchRoad(route, [], "test-token", async () => {
    const points = call++ === 0 ? route.slice(0, 100) : route.slice(97);
    return {
      status: 200,
      body: ok({
        geometry: points.map((p) => [p.longitude, p.latitude]),
        confidence: call === 1 ? 0.8 : 0.6,
      }),
    };
  });
  assert.equal(call, 2);
  assert.equal(result.sections.length, 1);
  assert.equal(result.sections[0].id, "t0:c0:m0");
  assert.equal(result.sections[0].sourceChunkIndex, 1);
  assert.equal(result.sections[0].geometry.length, 101);
  const firstDistance = distanceMeters(route[0], route[99]);
  const secondDistance = distanceMeters(route[97], route[100]);
  const expectedConfidence = (0.8 * firstDistance + 0.6 * secondDistance) /
    (firstDistance + secondDistance);
  assert.ok(Math.abs(result.confidence! - expectedConfidence) < 1e-12);
  assert.ok(Math.abs(result.validDistanceMeters -
    distanceMeters(route[0], route[100])) < 0.00001);
  assert.equal(result.status, "validated");
});

test("disconnected sections stay separate; permanent chunk error is partial", async () => {
  const route = routeFor(fixture.cases.find(
    (item: { name: string }) => item.name === "teleport_split",
  ).route);
  let call = 0;
  const result = await matchRoad(route, [], "test-token", async () => {
    call++;
    return call === 1
      ? { status: 200, body: ok({ geometry: [[29, 40], [29, 40.0001]], confidence: 0.9 }) }
      : { status: 400, body: "{}" };
  });
  assert.equal(result.status, "partiallyValidated");
  assert.equal(result.failureKind, "invalidInput");
  assert.equal(result.sections.length, 1);
  assert.equal(result.sections[0].id, "t0:c0:m0");
});

test("multiple matchings retain sections and weighted overall confidence", async () => {
  const route = [{ latitude: 40, longitude: 29 }, { latitude: 40, longitude: 29.002 }];
  const result = await matchRoad(route, [], "test-token", async () => ({
    status: 200,
    body: ok(
      { geometry: [[29, 40], [29.001, 40]], confidence: 0.9 },
      { geometry: [[29.001, 40], [29.002, 40]], confidence: 0.5 },
    ),
  }));
  assert.deepEqual(result.sections.map((s) => s.id), ["t0:c0:m0", "t0:c0:m1"]);
  assert.equal(result.status, "partiallyValidated");
  assert.ok(Math.abs(result.confidence! - 0.7) < 1e-9);
  assert.equal(result.directionKey, "40.00000,29.00000>40.00000,29.00200");
});

test("rate limiting remains retryable and never invents geometry", async () => {
  const route = [{ latitude: 40, longitude: 29 }, { latitude: 40, longitude: 29.001 }];
  const result = await matchRoad(route, [], "test-token", async () =>
    ({ status: 429, body: "{}" }));
  assert.equal(result.failureKind, "rateLimited");
  assert.equal(result.sections.length, 0);
  assert.equal(retryable(result.failureKind), true);
});
