// Bounded withdrawal replay. Reuse the same overlap, telemetry scoring and Dart
// mutation bridge as publication; never elect a winner by SQL geometry alone.
import {parseCandidateSnapshot, type CandidateSnapshot} from '../process-world-publish/active_world_overlap_stage.ts';
import {analyzeActiveCandidates} from '../process-world-publish/world_road_overlap.ts';
import {RequestSourceLoader, analyzeWorldScoring, type SourceGateway, type SourceRow} from '../process-world-publish/world_scoring_stage.ts';
import {planWorldMutation, type PlannedTrace, type PersistedTrace} from '../process-world-publish/world_mutation.ts';
import {rules} from '../process-world-publish/world_validation.ts';

export type RebuildContext = {state:string;generation:string;fingerprint:string;sources:{source:SourceRow;road:Record<string,unknown>;order:string;replay_time:string}[]};
export async function readPlanetSource(response:Response,remaining:number):Promise<{source:unknown;bytes:number}>{
 const limit=Math.min(4194304,remaining);
 if(!response.ok||limit<=0||Number(response.headers.get('content-length')??0)>limit){await response.body?.cancel();throw Error('planet_source_unavailable');}
 const reader=response.body?.getReader();if(!reader)throw Error('planet_source_unavailable');
 const decoder=new TextDecoder('utf-8',{fatal:true});let text='',bytes=0;
 try{while(true){const part=await reader.read();if(part.done)break;bytes+=part.value.length;
  if(bytes>limit){await reader.cancel();throw Error('planet_source_limit');}text+=decoder.decode(part.value,{stream:true});
 }text+=decoder.decode();}finally{reader.releaseLock();}
 return {source:JSON.parse(text),bytes};
}
export async function rebuildPlanet(context:RebuildContext,gateway:SourceGateway):Promise<PlannedTrace[]> {
 if(context.state!=='rebuild'||!Array.isArray(context.sources)||context.sources.length>32)throw Error('planet_rebuild_context');
 return (await advancePlanetReplay(context,gateway,{next:0,traces:[]},Math.max(1,context.sources.length))).traces;
}
export type ReplayCheckpoint={next:number;traces:PlannedTrace[]};
export async function advancePlanetReplay(context:RebuildContext,gateway:SourceGateway,checkpoint:ReplayCheckpoint,limit=2):Promise<ReplayCheckpoint>{
 if(context.state!=='rebuild'||!Array.isArray(context.sources)||context.sources.length>128||
  !Number.isInteger(checkpoint.next)||checkpoint.next<0||checkpoint.next>context.sources.length||checkpoint.traces.length>256||
  !Number.isInteger(limit)||limit<1||limit>32)throw Error('planet_rebuild_context');
 const canonicalRoads=parseCandidateSnapshot({generation:'0',is_empty:true,candidates:[],roads:context.sources.map(s=>s.road)}).roads;
 // Canonical SQL keys are (road ID, section key). The bridge's duplicate guard
 // uses section key alone. Namespace only in memory, then restore the exact
 // canonical key; never treat unrelated local offsets as the same road.
 const sectionKeys=new Map<string,string>();
 const roads=canonicalRoads.map(r=>({...r,sections:r.sections.map(s=>{
  const key=JSON.stringify([r.id,s.id]);sectionKeys.set(key,s.id);return {...s,id:key};
 })}));
 const loader=new RequestSourceLoader(gateway);
 const ids=context.sources.map(s=>s.source.id);
 if(new Set(ids).size!==ids.length)throw Error('planet_rebuild_duplicate_source');
 if(new Set(roads.map(r=>r.driveId)).size!==roads.length)throw Error('planet_rebuild_ambiguous_drive_identity');
 for(let i=0;i<roads.length;i++){
  if(roads[i].processingVersion!==rules.validatedRoadProcessingVersion||!roads[i].sections.length||
    roads[i].sections.some(s=>s.geometry.length<2||!Number.isFinite(s.distanceMeters)||s.distanceMeters<=0))throw Error('planet_rebuild_unsupported_road');
  if(i&&BigInt(context.sources[i].order)<=BigInt(context.sources[i-1].order))throw Error('planet_rebuild_order');
 }
 let traces:PersistedTrace[]=checkpoint.traces.map(t=>({
  ...t,matchedSectionId:JSON.stringify([t.validatedRoadId,t.matchedSectionId]),
  startOffsetMeters:Number(t.startOffsetMeters),endOffsetMeters:Number(t.endOffsetMeters),
  minLatitude:Number(t.minLatitude),maxLatitude:Number(t.maxLatitude),minLongitude:Number(t.minLongitude),maxLongitude:Number(t.maxLongitude),
  activeFromGeneration:String(checkpoint.next),activeToGeneration:null,
 }));
 const end=Math.min(roads.length,checkpoint.next+limit);
 for(let i=checkpoint.next;i<end;i++){
  const challenger=roads[i];
  const needed=new Set([challenger.id,...traces.map(t=>t.validatedRoadId)]);
  const working=roads.filter(r=>needed.has(r.id)),sections=working.flatMap(r=>r.sections);
  if(working.length>32||sections.length>512||sections.reduce((n,s)=>n+s.distanceMeters,0)>500000||
   sections.reduce((n,s)=>n+s.geometry.length,0)>50000||working.some(r=>r.sections.reduce((n,s)=>n+s.distanceMeters,0)>100000))throw Error('planet_rebuild_limit');
  await loader.prepare(context.sources.filter(s=>needed.has(String(s.road.id))).map(s=>s.source.id));
  await loader.load(ids[i],challenger.driveId); // Validate even non-overlapping sources.
  const snapshot:CandidateSnapshot={generation:String(i),isEmpty:traces.length===0,candidates:traces,roads:working.filter(r=>r.id!==challenger.id)};
  const overlaps=analyzeActiveCandidates(challenger,traces,snapshot.roads);
  const scored=await analyzeWorldScoring(ids[i],challenger,snapshot.roads,overlaps,loader);
  if(scored.state!=='scoring_completed')throw Error('planet_rebuild_source_unavailable');
  const plan=planWorldMutation(snapshot,challenger,ids[i],scored.inputs,context.sources[i].replay_time);
  const closed=new Set(plan.closeVersions.map(t=>t.id));
  traces=[...traces.filter(t=>!closed.has(t.id)),...plan.createTraces.map(t=>({
   id:t.id,sourcePublishId:t.sourcePublishId,sourceDriveId:t.sourceDriveId,validatedRoadId:t.validatedRoadId,
   matchedSectionId:t.matchedSectionId,directionKey:t.directionKey,processingVersion:t.processingVersion,
   startOffsetMeters:Number(t.startOffsetMeters),endOffsetMeters:Number(t.endOffsetMeters),
   minLatitude:Number(t.minLatitude),maxLatitude:Number(t.maxLatitude),minLongitude:Number(t.minLongitude),maxLongitude:Number(t.maxLongitude),
   createdAt:t.createdAt,updatedAt:t.updatedAt,activeFromGeneration:String(i+1),activeToGeneration:null,
  }))];
  if(traces.length>256)throw Error('planet_rebuild_limit');
 }
 return {next:end,traces:traces.map(t=>({id:t.id,sourcePublishId:t.sourcePublishId,sourceDriveId:t.sourceDriveId,
  validatedRoadId:t.validatedRoadId,matchedSectionId:sectionKeys.get(t.matchedSectionId)!,directionKey:t.directionKey,
  processingVersion:t.processingVersion,startOffsetMeters:String(t.startOffsetMeters),endOffsetMeters:String(t.endOffsetMeters),
  minLatitude:String(t.minLatitude),maxLatitude:String(t.maxLatitude),minLongitude:String(t.minLongitude),maxLongitude:String(t.maxLongitude),
  createdAt:t.createdAt,updatedAt:t.updatedAt}))};
}
