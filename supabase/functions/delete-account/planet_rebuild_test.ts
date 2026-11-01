import assert from 'node:assert/strict';
import {rebuildPlanet,advancePlanetReplay,readPlanetSource,type RebuildContext,type ReplayCheckpoint} from './planet_rebuild.ts';
import type {SourceGateway} from '../process-world-publish/world_scoring_stage.ts';

const forbidden:SourceGateway={metadata:()=>{throw Error('unexpected source I/O');},download:()=>{throw Error('unexpected source I/O');}};
function context(distance='6000'):RebuildContext {
 return {state:'rebuild',generation:'3',fingerprint:'synthetic',sources:[{
  source:{id:'publish',local_drive_id:'drive',user_id:'owner',source_path:'owner/publish.json',source_ready_at:'2026-01-01',
   source_schema_version:1,telemetry_version:1,drive_score_algorithm_version:1,world_rules_version:6,raw_route_point_count:2,telemetry_point_count:2},
  order:'1',replay_time:'2026-01-01T00:00:00Z',road:{id:'road',drive_id:'drive',direction_key:'east',processing_version:6,
   sections:[{section_key:'section',section_order:0,distance_meters:distance,geometry:{type:'LineString',coordinates:[[0,0],[.06,0]]}}]},
 }]};
}
Deno.test('withdrawal replay bounds source count before downloading',async()=>{
 const c=context();c.sources=Array.from({length:33},()=>c.sources[0]);
 await assert.rejects(()=>rebuildPlanet(c,forbidden),/planet_rebuild_context/);
});
Deno.test('withdrawal replay bounds sampling distance before downloading',async()=>{
 await assert.rejects(()=>rebuildPlanet(context('100001'),forbidden),/planet_rebuild_limit/);
});
Deno.test('withdrawal replay rejects malformed canonical geometry before downloading',async()=>{
 const c=context();c.sources[0].road.sections=[{section_key:'section',section_order:0,distance_meters:'6000',geometry:{type:'LineString',coordinates:[[0,999],[.06,999]]}}];
 await assert.rejects(()=>rebuildPlanet(c,forbidden),/candidate_snapshot_invalid/);
});
Deno.test('withdrawal replay refuses ambiguous cross-account drive identities',async()=>{
 const c=context();c.sources.push({...c.sources[0],source:{...c.sources[0].source,id:'other-publish'},order:'2',road:{...c.sources[0].road,id:'other-road'}});
 await assert.rejects(()=>rebuildPlanet(c,forbidden),/planet_rebuild_ambiguous_drive_identity/);
});
Deno.test('withdrawal source streaming cancels oversized bodies without buffering the file',async()=>{
 let cancelled=false;
 const response=new Response(new ReadableStream({pull(c){c.enqueue(new Uint8Array(64));},cancel(){cancelled=true;}}));
 await assert.rejects(()=>readPlanetSource(response,100),/planet_source_limit/);
 assert.equal(cancelled,true);
});
Deno.test('withdrawal source streaming decodes bounded JSON',async()=>{
 assert.deepEqual(await readPlanetSource(new Response('{"ok":true}'),100),{source:{ok:true},bytes:11});
});

function replayFixture(count:number,distance='6000'){
 const c=context(distance);
 c.sources=Array.from({length:count},(_,i)=>({
  ...c.sources[0],source:{...c.sources[0].source,id:`publish-${i}`,local_drive_id:`drive-${i}`,source_path:`owner/publish-${i}.json`},
  order:String(i+1),road:{...c.sources[0].road,id:`road-${i}`,drive_id:`drive-${i}`},
 }));
 const gateway:SourceGateway={metadata:async(ids)=>c.sources.filter(s=>ids.includes(s.source.id)).map(s=>s.source),download:async(path)=>{
  const row=c.sources.find(s=>s.source.source_path===path)!.source;
  const points=[{latitude:0,longitude:0},{latitude:0,longitude:.06}];
  return {publish_id:row.id,local_drive_id:row.local_drive_id,schema_version:1,telemetry_version:1,drive_score_algorithm_version:1,world_rules_version:6,
   started_at:'2026-01-01T00:00:00Z',ended_at:'2026-01-01T00:10:00Z',recorded_distance_meters:Number(distance),raw_route:points,
   canonical_telemetry:points.map((p,i)=>({...p,timestamp:i?'2026-01-01T00:10:00Z':'2026-01-01T00:00:00Z',speed_mps:10,heading_degrees:90,altitude_meters:0,accuracy_meters:3,distance_from_previous_meters:i?Number(distance):0,acceleration_mps2:0}))};
 }};
 return {c,gateway};
}
Deno.test('checkpoint replay equals uninterrupted planner after JSON round trips',async()=>{
 const {c,gateway}=replayFixture(6);
 const expected=await rebuildPlanet(c,gateway);let p:ReplayCheckpoint={next:0,traces:[]};
 while(p.next<c.sources.length)p=JSON.parse(JSON.stringify(await advancePlanetReplay(c,gateway,p)));
 assert.deepEqual(p.traces,expected);
});
Deno.test('33 roads and 594km replay in bounded prefix batches without raising working limits',async()=>{
 const {c,gateway}=replayFixture(33,'18000');let p:ReplayCheckpoint={next:0,traces:[]},steps=0;
 while(p.next<c.sources.length){const before=p.next;p=await advancePlanetReplay(c,gateway,p);assert.ok(p.next-before<=2);steps++;}
 assert.equal(steps,17);assert.equal(p.traces.length,1);assert.equal(p.traces[0].sourcePublishId,'publish-0');
});
