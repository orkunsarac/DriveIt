import assert from "node:assert/strict";
import test from "node:test";
import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { clipActiveCoverage, evaluateScoring, type ScoringInput } from "./world_scoring.ts";
import "../../../test/fixtures/world_scoring_boundary.generated.js";
import { analyzeWorldScoring, RequestSourceLoader, type SourceRow } from "./world_scoring_stage.ts";
import type { Coverage } from "./world_road_overlap.ts";
const root = new URL("../../../", import.meta.url);
type Fixture = ScoringInput & { name: string; scores?: (number | null)[] };
const cases: Fixture[] = JSON.parse(readFileSync(new URL("test/fixtures/active_world_scoring.json",root),"utf8"));
const oracle = JSON.parse(readFileSync(new URL("test/fixtures/active_world_scoring_oracle.json",root),"utf8"));
test("shared active span excludes inactive length at exact 2999/3000 boundaries",()=> {
  const match=cases[0].match;
  const active=clipActiveCoverage(match,match.firstSectionId,1000,3000)!;
  assert.deepEqual(active,{firstStartOffsetMeters:1000,firstEndOffsetMeters:3000,
    secondStartOffsetMeters:1000,secondEndOffsetMeters:3000,
    commonDistanceMeters:2000,comparisonEligible:false});
  assert.equal(clipActiveCoverage(match,match.firstSectionId,500,3499)!.comparisonEligible,false);
  assert.equal(clipActiveCoverage(match,match.firstSectionId,500,3500)!.comparisonEligible,true);
  assert.equal(clipActiveCoverage(match,match.firstSectionId,5000,6000),null);
  // Defensive bridge test: the overlap engine normally emits only true.
  const reverse=JSON.parse(JSON.stringify({...match,directionCompatible:false}));
  assert.equal(clipActiveCoverage(reverse,match.firstSectionId,500,3500),null);
  const unequal={...match,firstStartOffsetMeters:0,firstEndOffsetMeters:5000,
    secondStartOffsetMeters:0,secondEndOffsetMeters:4000};
  assert.deepEqual(clipActiveCoverage(unequal,match.firstSectionId,2400,2600),{
    firstStartOffsetMeters:2400,firstEndOffsetMeters:2600,
    secondStartOffsetMeters:1920,secondEndOffsetMeters:2080,
    commonDistanceMeters:160,comparisonEligible:false});
  const cumulative={...match,firstStartOffsetMeters:5000,firstEndOffsetMeters:9000,
    secondStartOffsetMeters:6000,secondEndOffsetMeters:10000};
  assert.deepEqual(clipActiveCoverage(cumulative,match.firstSectionId,6000,8000),{
    firstStartOffsetMeters:6000,firstEndOffsetMeters:8000,
    secondStartOffsetMeters:7000,secondEndOffsetMeters:9000,
    commonDistanceMeters:2000,comparisonEligible:false});
});
test("normalized telemetry follows physical geometry, including cumulative/fallback prefixes",()=> {
  for(const [name,low,high] of [
    ['SEM-A-geometry4000-canonical5000',192,208],
    ['SEM-multi-cumulative',380,400],['SEM-prefix-fallback',380,400]] as const) {
    const result=evaluateScoring(cases.find(c=>c.name===name)!);
    assert.equal(result.status,'success');
    assert.ok(result.firstExtraction!.startIndex>=low && result.firstExtraction!.startIndex<=low+1);
    assert.ok(result.firstExtraction!.endIndex>=high-1 && result.firstExtraction!.endIndex<=high);
  }
});
// Only machine-level floating point drift is tolerated in geometric/scoring
// doubles; names, outcomes, timestamp strings, indices and counts are exact.
function parity(actual: unknown, expected: unknown, path = ""): void {
  if (typeof expected === "number") {
    assert.equal(typeof actual,"number",path);
    if (/OffsetMeters$|winningDistanceMeters$|\.(count|startIndex|endIndex|supportingWindowCount|algorithmVersion|displayScore)$/.test(path)) {
      assert.equal(actual,expected,path);
    } else {
      assert.ok(Math.abs((actual as number)-expected) <= 1e-9 * Math.max(1, Math.abs(expected)),path);
    }
  } else if (Array.isArray(expected)) {
    assert.ok(Array.isArray(actual),path); assert.equal(actual.length,expected.length,path);
    expected.forEach((v,i)=>parity(actual[i],v,`${path}[${i}]`));
  } else if (expected && typeof expected === "object") {
    assert.ok(actual && typeof actual === "object",path);
    assert.deepEqual(Object.keys(actual).sort(),Object.keys(expected).sort(),path);
    for (const [k,v] of Object.entries(expected)) parity((actual as Record<string,unknown>)[k],v,`${path}.${k}`);
  } else assert.equal(actual,expected,path);
}
for (const [i,c] of cases.entries()) test(`native Dart vs Deno scoring: ${c.name}`,()=> {
  const result = c.scores
    ? JSON.parse((globalThis as unknown as {driveItWorldScoringBoundaryTest:(s:string)=>string})
      .driveItWorldScoringBoundaryTest(JSON.stringify(c)))
    : evaluateScoring(c);
  parity(result,oracle[i],c.name);
});
test("compiler artifact cannot silently drift from any transitive Dart source",()=> {
  const manifest = JSON.parse(readFileSync(new URL("world_scoring.manifest.json",import.meta.url),"utf8"));
  const hash=(url:URL)=>createHash('sha256').update(readFileSync(url,'utf8').replaceAll('\r\n','\n')).digest('hex');
  for (const [path,hash] of Object.entries(manifest.sources)) {
    assert.equal(createHash('sha256').update(readFileSync(new URL(path,root),'utf8').replaceAll('\r\n','\n')).digest('hex'),hash,path);
  }
  assert.equal(hash(new URL("world_scoring.generated.js",import.meta.url)),manifest.artifact_sha256);
  assert.equal(hash(new URL('../../../test/fixtures/world_scoring_boundary.generated.js',import.meta.url)),manifest.boundary_artifact_sha256);
});
test("actual calculator wins, N/A contributions, and partial span are retained",()=> {
  const a=evaluateScoring(cases[0]); assert.equal(a.comparison?.outcome,"secondWins");
  assert.equal(a.winningRegions.length,1); assert.equal(a.winningRegions[0].winningDistanceMeters,4000);
  const b=evaluateScoring(cases[1]); assert.equal(b.winningRegions.length,0);
  assert.ok(Object.values(a.windows[0].comparison.secondLocalScore!.contributions)
    .some(c=>c.source === 'neutralNotApplicable'));
  const partial=evaluateScoring(cases.find(c=>c.name === 'J-partial')!);
  // Native projection can exclude a point exactly on a boundary by sub-ULP
  // geometry error. Never widen/clamp its semantics to make a test pass.
  assert.ok(partial.firstExtraction!.startIndex>=100);
  assert.ok(partial.firstExtraction!.endIndex<=450);
  assert.ok(partial.windows.every(w=>w.existingStartOffsetMeters>=1000&&w.existingEndOffsetMeters<=4500));
});
test("strict chronological microseconds survive the JS bridge",()=> {
  const result=evaluateScoring(cases.find(c=>c.name==='N-microseconds')!);
  assert.equal(result.firstExtraction?.timestamps[0],'2026-10-06T00:00:00.000001Z');
  assert.equal(result.firstExtraction?.timestamps[1],'2026-10-06T00:00:00.000002Z');
});

const fixture=cases[0];
function row(id:string,driveId:string,points=fixture.firstTelemetry.length): SourceRow {
  return {id,user_id:'owner',local_drive_id:driveId,source_path:`owner/${id}.json`,source_ready_at:'ready',
    source_schema_version:1,telemetry_version:1,drive_score_algorithm_version:1,world_rules_version:6,
    raw_route_point_count:2,telemetry_point_count:points};
}
function source(r:SourceRow,points=fixture.firstTelemetry): unknown {
  return { publish_id:r.id, local_drive_id:r.local_drive_id,schema_version:1,telemetry_version:1,
    drive_score_algorithm_version:1,world_rules_version:6,started_at:'2026-10-06T00:00:00Z',
    ended_at:'2026-10-06T02:00:00Z',recorded_distance_meters:4000,
    raw_route:[{latitude:0,longitude:0},{latitude:0,longitude:.04}],canonical_telemetry:points };
}
function coverage(traceId:string): Coverage {
  return { trace:{id:traceId,sourcePublishId:'incumbent',sourceDriveId:'first-drive',validatedRoadId:'first',
    matchedSectionId:'first-section',startOffsetMeters:0,endOffsetMeters:4000,directionKey:'east',
    activeFromGeneration:'1',activeToGeneration:null,processingVersion:6},match:fixture.match,
    activeStartOffsetMeters:0,activeEndOffsetMeters:4000,challengerStartOffsetMeters:0,
    challengerEndOffsetMeters:4000,commonDistanceMeters:4000,comparisonEligible:true };
}
test("exact candidate sources only, one metadata batch and single download per source",async()=> {
  const r1=row('incumbent','first-drive'),r2=row('challenger','second-drive');
  const downloads:string[]=[];let batches=0;
  const loader=new RequestSourceLoader({async metadata(ids){batches++;assert.deepEqual(ids,['challenger','incumbent']);return [r1,r2];},
    async download(path){downloads.push(path);return path===r1.source_path?source(r1):source(r2,fixture.secondTelemetry);}});
  const result=await analyzeWorldScoring('challenger',fixture.secondRoad,[fixture.firstRoad],
    [coverage('a'),coverage('b')],loader);
  assert.equal(result.state,'world_ownership_mutation_not_implemented');assert.equal(batches,1);
  assert.deepEqual(downloads,['owner/incumbent.json','owner/challenger.json']);
  assert.equal(result.inputs.length,2);
});
test("already downloaded challenger seed avoids another Storage transfer",async()=> {
  const r1=row('incumbent','first-drive'),r2=row('challenger','second-drive');let downloads=0;
  const loader=new RequestSourceLoader({async metadata(){return[r1,r2];},async download(){downloads++;return source(r1);}},
    new Map([['challenger',source(r2,fixture.secondTelemetry)]]));
  const result=await analyzeWorldScoring('challenger',fixture.secondRoad,[fixture.firstRoad],[coverage('a')],loader);
  assert.notEqual(result.state,'failure');assert.equal(downloads,1);
});
test("under 3km keeps geometric coverage and never loads/scores sources",async()=> {
  const c={...coverage('a'),comparisonEligible:false,commonDistanceMeters:2999};
  const loader=new RequestSourceLoader({async metadata(){throw new Error('must not call');},async download(){throw new Error('must not call');}});
  const result=await analyzeWorldScoring('challenger',fixture.secondRoad,[fixture.firstRoad],[c],loader);
  assert.notEqual(result.state,'failure');if(result.state!=='failure') {
    assert.equal(result.inputs[0].coverage.commonDistanceMeters,2999);
    assert.equal(result.inputs[0].scoring.status,'notEligible');
  }
});
for (const kind of ['missing','malformed','version','path','drive','download'] as const)
  test(`safe typed source failure: ${kind}`,async()=> {
    const r1=row('incumbent','first-drive'),r2=row('challenger','second-drive');
    if(kind==='version')r1.drive_score_algorithm_version=2;
    if(kind==='path')r1.source_path='different-owner/source.json';
    if(kind==='drive')r1.local_drive_id='another-drive';
    const loader=new RequestSourceLoader({async metadata(){return kind==='missing'?[r2]:[r1,r2];},
      async download(){if(kind==='download')throw new Error('SECRET Authorization user route');return kind==='malformed'?{}:source(r1);}});
    const result=await analyzeWorldScoring('challenger',fixture.secondRoad,[fixture.firstRoad],[coverage('a')],loader);
    assert.equal(result.state,'failure');assert.ok(!JSON.stringify(result).includes('SECRET'));
    assert.ok(!JSON.stringify(result).includes('Authorization'));
  });
test("non-empty stage cannot commit, mark failed/published or emit source data",()=> {
  const stage=readFileSync(new URL('world_scoring_stage.ts',import.meta.url),'utf8');
  assert.ok(!/\.rpc\(|\.insert\(|\.update\(|console\./.test(stage));
  const index=readFileSync(new URL('index.ts',import.meta.url),'utf8');
  const branch=index.slice(index.indexOf('if (overlapStage.state'),index.indexOf('const plan = planEmptyWorld'));
  assert.ok(!branch.includes('activate_empty_world_publish'));assert.ok(branch.includes('scoring.state'));
  assert.ok(!branch.includes('inputs:'));assert.ok(!branch.includes('canonical_telemetry'));
});
