import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { sectionCoordinates, sectionDistanceMeters } from "./validated_section_geojson.ts";
import { planEmptyWorld } from "./active_world_empty_planner.ts";

test("exact distance text survives planner and JSON round-trip without changing float8", () => {
  const canonical = 6998.4040194567788;
  const lossy = 6998.4040194567797;
  assert.notEqual(canonical, lossy);
  const decoded = sectionDistanceMeters(JSON.parse(JSON.stringify("6998.404019456779")));
  assert.equal(decoded, canonical);
  const input = {
    generation: 0, driveScoreAlgorithmVersion: 1, sourceDriveSessionId: "precision-drive",
    validatedRoadId: "precision-road", directionKey: "forward", processingVersion: 3,
    sections: [{ id: "precision-section", distanceMeters: decoded!, geometry: [
      { latitude: 0, longitude: 0 }, { latitude: 0, longitude: 0.02 },
    ] }],
  };
  const plan = planEmptyWorld(input);
  const transported = JSON.parse(JSON.stringify(plan));
  assert.equal(transported.traces[0].endOffsetMeters, canonical);
  assert.equal(transported.traces[0].id, "precision-drive:precision-road:precision-section:0.000:6998.404");
  assert.equal(planEmptyWorld({ ...input, sections: [{ ...input.sections[0], distanceMeters: lossy }] }).traces[0].id,
    transported.traces[0].id);
});

test("exact distance contract rejects legacy numbers and malformed text, preserves fallback", () => {
  assert.equal(sectionDistanceMeters(6998.4040194567797), null);
  for (const invalid of [null, "", " ", "1 metre", "0x10", "1e999"]) {
    assert.equal(sectionDistanceMeters(invalid), null);
  }
  assert.equal(sectionDistanceMeters("0"), 0);
  assert.equal(sectionDistanceMeters("1.25e3"), 1250);
  assert.ok(Number.isNaN(sectionDistanceMeters("NaN")));
  assert.equal(sectionDistanceMeters("Infinity"), Infinity);
});

test("GeoJSON LineString maps [longitude, latitude] without swapping", () => {
  assert.deepEqual(sectionCoordinates({
    type: "LineString",
    coordinates: [[29.927, 40.7128], [29.928, 40.7138]],
  }), [
    { longitude: 29.927, latitude: 40.7128 },
    { longitude: 29.928, latitude: 40.7138 },
  ]);
});

test("exact read RPC pins float8 text conversion before PostgREST serialization", () => {
  const sql = readFileSync(
    new URL("../../migrations/202610010001_world_validated_sections_exact_distance_read.sql", import.meta.url),
    "utf8",
  ).toLowerCase();
  assert.match(sql, /distance_meters text/);
  assert.match(sql, /set extra_float_digits = 3/);
  assert.match(sql, /s\.distance_meters::text/);
  assert.match(sql, /order by s\.section_order/);
  assert.doesNotMatch(sql, /security definer|round\(|truncate\(/);
  assert.match(sql, /from public, anon, authenticated/);
  assert.match(sql, /to service_role/);
});

test("invalid GeoJSON and lines with fewer than two points are rejected", () => {
  assert.equal(sectionCoordinates({ type: "MultiLineString", coordinates: [] }), null);
  assert.equal(sectionCoordinates({ type: "LineString", coordinates: [[29, 40]] }), null);
  assert.equal(sectionCoordinates({ type: "LineString", coordinates: [[29, 40], [181, 40]] }), null);
  assert.equal(sectionCoordinates({ type: "LineString", coordinates: [[29, 40], [29, Number.NaN]] }), null);
  assert.equal(sectionCoordinates("0102000020E6100000"), null);
});

test("section projection is ordered and server-only, with PostGIS as geometry source", () => {
  const sql = readFileSync(
    new URL("../../migrations/202609300005_world_validated_sections_geojson_read.sql", import.meta.url),
    "utf8",
  ).toLowerCase();
  assert.match(sql, /returns table \([\s\S]*id uuid,[\s\S]*validated_road_id uuid,[\s\S]*section_key text,[\s\S]*section_order integer,[\s\S]*distance_meters double precision,[\s\S]*confidence double precision,[\s\S]*source_trace_index integer,[\s\S]*source_chunk_index integer,[\s\S]*geometry jsonb/);
  assert.match(sql, /extensions\.st_asgeojson\(s\.geometry, 15, 0\)::jsonb/);
  assert.match(sql, /extensions\.st_srid\(s\.geometry\) = 4326/);
  assert.match(sql, /order by s\.section_order/);
  assert.doesNotMatch(sql, /security definer/);
  assert.match(sql, /revoke all on function[\s\S]*from public, anon, authenticated/);
  assert.match(sql, /grant execute on function[\s\S]*to service_role/);
});
