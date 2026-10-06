import assert from "node:assert/strict";
import test from "node:test";
import { readFileSync } from "node:fs";
import { analyzeActiveCandidates, clipMatchToTrace, findCommonRoads, overlapRules, type Road, type Trace } from "./world_road_overlap.ts";
import { evaluateCandidateSnapshot, parseCandidateSnapshot } from "./active_world_overlap_stage.ts";
const fixture = JSON.parse(readFileSync(new URL("../../../test/fixtures/active_world_overlap_parity.json", import.meta.url), "utf8"));
export function fixtureRoad(id: string, sections: {id: string; distance: number; points: number[][]}[]): Road {
  return {id, driveId: `${id}-drive`, sections: sections.map((s) => ({id:s.id,distanceMeters:s.distance,
    geometry:s.points.map(([x,y])=>({latitude:41+y/111320,longitude:29+x/84000}))}))};
}
const trace: Trace = {id:"trace", sourcePublishId:"publish",sourceDriveId:"first-drive",validatedRoadId:"first",
  matchedSectionId:"a",startOffsetMeters:500,endOffsetMeters:2000,directionKey:"deliberately-unrelated",
  activeFromGeneration:"1",activeToGeneration:null,processingVersion:3};
for (const c of fixture.cases) test(`overlap fixture ${c.name}`, () => {
  const first=fixtureRoad("first",c.first),second=fixtureRoad("second",c.second);
  const matches=findCommonRoads(first,second);
  assert.equal(matches.length,c.count);
  for (const m of matches) assert.equal(m.comparisonEligible,c.eligible);
  if (c.trace_span) {
    const coverage=clipMatchToTrace(matches[0],trace)!;
    assert.equal(coverage.activeStartOffsetMeters,500);assert.equal(coverage.activeEndOffsetMeters,2000);
    assert.equal(coverage.challengerStartOffsetMeters,500);assert.equal(coverage.challengerEndOffsetMeters,2000);
    assert.equal(coverage.comparisonEligible,false);assert.equal(coverage.match.ownershipCovered,true);
  }
});
test("Dart rule constants including existing clipping epsilon are unchanged",()=>{
  const rules=readFileSync(new URL("../../../lib/features/my_world/config/my_world_rules.dart",import.meta.url),"utf8");
  const mapping: Record<string,number> = {commonRoadResampleIntervalMeters:25,commonRoadGeometryToleranceMeters:15,
    commonRoadMaximumDirectionDifferenceDegrees:30,commonRoadMinimumGeometryConfidence:.65,
    commonRoadMinimumReportedDistanceMeters:100,minimumCommonWorldDistanceMeters:3000,commonRoadMaximumRelativeLengthDifference:.2};
  for(const [key,value] of Object.entries(mapping)) assert.equal(Number(rules.match(new RegExp(`${key} = ([.0-9]+)`))![1]),value);
  assert.equal(overlapRules.clipEpsilon,.01);
});
test("multiple candidates deterministic; repeated analysis pure; no candidates empty",()=>{
  const r=fixtureRoad("first",fixture.cases[0].first),c=fixtureRoad("second",fixture.cases[0].second);
  const traces=[trace,{...trace,id:"a-trace",startOffsetMeters:2000,endOffsetMeters:4000}];
  const a=analyzeActiveCandidates(c,traces,[r]);
  assert.deepEqual(a,analyzeActiveCandidates(c,traces.toReversed(),[r]));
  assert.deepEqual(a,analyzeActiveCandidates(c,traces,[r]));assert.equal(a.length,2);
  assert.deepEqual(analyzeActiveCandidates(c,[],[]),[]);
});
test("partial active span in a later section retains cumulative, not section-local offsets",()=>{
  const c=fixture.cases.find((c: {name:string})=>c.name==="multi-section-cumulative");
  const matches=findCommonRoads(fixtureRoad("first",c.first),fixtureRoad("second",c.second));
  const coverage=clipMatchToTrace(matches[1],{...trace,matchedSectionId:"c",startOffsetMeters:750,endOffsetMeters:1800})!;
  assert.equal(coverage.activeStartOffsetMeters,750);assert.equal(coverage.activeEndOffsetMeters,1800);
  assert.equal(coverage.challengerStartOffsetMeters,750);assert.equal(coverage.challengerEndOffsetMeters,1800);
});
const raw=()=>({generation:"1",is_empty:false,candidates:[{id:"trace",source_publish_id:"publish",source_drive_id:"first-drive",
  validated_road_id:"first",matched_section_id:"a",start_offset_meters:"500",end_offset_meters:"2000",
  direction_key:"unrelated",active_from_generation:"1",active_to_generation:null,processing_version:3}],
  roads:[{id:"first",drive_id:"first-drive",sections:[{section_key:"a",section_order:0,distance_meters:"4000",
    geometry:{type:"LineString",coordinates:[[29,41],[29+4000/84000,41]]}}]}]});
test("current-only snapshot rejects closed and future temporal versions",()=>{
  assert.equal(parseCandidateSnapshot(raw()).candidates.length,1);
  const closed=raw();closed.candidates[0].active_to_generation="1" as never;
  assert.throws(()=>parseCandidateSnapshot(closed),/inactive_trace/);
  const future=raw();future.candidates[0].active_from_generation="2";
  assert.throws(()=>parseCandidateSnapshot(future),/inactive_trace/);
});
test("read-only intermediate stage never implies ownership/published; empty spatial candidates still non-empty world",()=>{
  const c=fixtureRoad("second",fixture.cases[0].second);
  assert.equal(evaluateCandidateSnapshot(c,raw()).state,"ownership_processing_not_implemented");
  const no=raw();no.candidates=[];no.roads=[];
  assert.equal(evaluateCandidateSnapshot(c,no).state,"ownership_processing_not_implemented");
  assert.equal(evaluateCandidateSnapshot(c,{...no,is_empty:true,generation:"0"}).state,"empty_world");
});
test("candidate SQL uses current temporal snapshot, spatial index and server-only privileges",()=>{
  const sql=readFileSync(new URL("../../migrations/202610060001_active_world_overlap_candidates.sql",import.meta.url),"utf8");
  assert.match(sql,/active_from_generation <= s.current_generation/);assert.match(sql,/t.active_to_generation is null/);
  assert.match(sql,/t.bounds && extensions.ST_Envelope/);
  const schema=readFileSync(new URL("../../migrations/202609300003_active_world_empty_generation.sql",import.meta.url),"utf8");
  assert.match(schema,/using gist \(bounds\)[\s\S]*where active_to_generation is null/);
  assert.match(sql,/from public,anon,authenticated/);assert.match(sql,/to service_role/);
  assert.match(sql,/set search_path = pg_catalog, extensions, public, pg_temp/);
  assert.doesNotMatch(sql,/insert into|update public|delete from/i);
});

function compareParity(actual: unknown, expected: unknown, path="result") {
  if(typeof expected === "number") {
    assert.equal(typeof actual,"number",path);
    const tolerance=path.includes("latitude") || path.includes("longitude") ? 1e-12 : 1e-8;
    assert.ok(Math.abs((actual as number)-expected)<=tolerance,`${path}: ${actual} != ${expected}`);
  } else if(Array.isArray(expected)) {
    assert.ok(Array.isArray(actual),path);assert.equal(actual.length,expected.length,path);
    expected.forEach((value,i)=>compareParity(actual[i],value,`${path}[${i}]`));
  } else if(expected && typeof expected === "object") {
    assert.ok(actual && typeof actual === "object",path);
    assert.deepEqual(Object.keys(actual).sort(),Object.keys(expected).sort(),path);
    for(const [key,value] of Object.entries(expected)) compareParity((actual as Record<string,unknown>)[key],value,`${path}.${key}`);
  } else assert.equal(actual,expected,path);
}
const oracle=JSON.parse(readFileSync(new URL("../../../test/fixtures/active_world_overlap_dart_oracle.json",import.meta.url),"utf8"));
for(const c of fixture.cases) test(`Dart/server exact overlap parity: ${c.name}`,()=>{
  compareParity(findCommonRoads(fixtureRoad("first",c.first),fixtureRoad("second",c.second)),oracle[c.name]);
});
test("pipeline duplicate short-circuits; non-empty intermediate path cannot commit",()=>{
  const source=readFileSync(new URL("./index.ts",import.meta.url),"utf8");
  assert.ok(source.indexOf('if (completed) return json') < source.indexOf('get_active_world_overlap_candidates'));
  const guard=source.slice(source.indexOf('if (overlapStage.state ==='),source.indexOf('const plan = planEmptyWorld'));
  assert.match(guard,/analyzeWorldScoring/);
  assert.match(guard,/error_code: scoring.state/);
  const scoring=readFileSync(new URL('./world_scoring_stage.ts',import.meta.url),'utf8');
  assert.match(scoring,/world_ownership_mutation_not_implemented/);
  assert.doesNotMatch(guard,/admin.rpc|activate_empty_world_publish|upload|matchRoad/);
});
