import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const sql = readFileSync(
  new URL("../../migrations/202609300003_active_world_empty_generation.sql", import.meta.url),
  "utf8",
).toLowerCase();
const fn = sql.slice(sql.indexOf("create or replace function public.activate_empty_world_publish"));

test("active generation commit is serialized, stale-safe, and publish-idempotent", () => {
  assert.match(sql, /source_publish_id uuid unique references public\.world_publishes/);
  assert.match(fn, /where id = p_publish_id for update/);
  assert.match(fn, /where singleton = true for update/);
  assert.match(fn, /where source_publish_id = p_publish_id/);
  assert.match(fn, /v_current <> p_expected_generation/);
  assert.match(fn, /world_comparison_not_implemented/);
});

test("only eligible validated-road geometry can complete the publish", () => {
  assert.match(fn, /where publish_id = p_publish_id and user_id = v_publish\.user_id/);
  assert.match(fn, /valid_distance_meters >= 5000/);
  assert.match(fn, /world_validated_road_sections/);
  assert.match(fn, /active_to_generation is null/);
  assert.match(fn, /set current_generation = v_generation/);
  assert.match(fn, /set status = 'published', processed_at = v_now/);
  assert.ok(fn.indexOf("insert into public.world_active_world_traces") <
    fn.indexOf("set current_generation = v_generation"));
});

test("RPC is service-role only and active trace bounds are indexed", () => {
  assert.match(sql, /using gist \(bounds\)[\s\S]*where active_to_generation is null/);
  assert.match(sql, /from public, anon, authenticated;[\s\S]*grant execute on function public\.activate_empty_world_publish[\s\S]*to service_role/);
  assert.match(sql, /revoke all on public\.world_active_world_traces from public, anon, authenticated, service_role/);
  const grants = readFileSync(
    new URL("../../migrations/202609300004_world_validated_road_sections_service_role_select.sql", import.meta.url),
    "utf8",
  ).toLowerCase();
  assert.match(grants, /grant select on table public\.world_validated_road_sections to service_role/);
});

test("persisted validated road resumes activation before Mapbox matching", () => {
  const edge = readFileSync(
    new URL("./index.ts", import.meta.url),
    "utf8",
  );
  const existingRoadBranch = edge.indexOf("if (existing) {");
  const recoveryCall = edge.indexOf("return activateEmptyWorld", existingRoadBranch);
  const mapboxCall = edge.indexOf("const result = await matchRoad(");
  assert.ok(existingRoadBranch >= 0);
  assert.ok(recoveryCall > existingRoadBranch);
  assert.ok(mapboxCall > recoveryCall);
});

test("recovery reads PostGIS sections through the GeoJSON RPC before planning", () => {
  const edge = readFileSync(
    new URL("./index.ts", import.meta.url),
    "utf8",
  );
  assert.match(edge, /get_world_validated_road_sections_for_processing/);
  assert.match(edge, /sectionCoordinates\(section\.geometry\)/);
  assert.ok(edge.indexOf("get_world_validated_road_sections_for_processing") <
    edge.indexOf("const plan = planEmptyWorld"));
  assert.doesNotMatch(edge, /from\("world_validated_road_sections"\)/);
});
