// Synthetic only; no actual user route, UUID or source telemetry.
import type { MutationInput } from '../supabase/functions/process-world-publish/world_scoring_stage.ts';
import type { PersistedTrace } from '../supabase/functions/process-world-publish/world_mutation.ts';
import type { Road, Match } from '../supabase/functions/process-world-publish/world_road_overlap.ts';
export const now='2026-10-06T00:00:00.000Z';
function road(id:string,length=10000):Road {return {id,driveId:id+'-drive',directionKey:'east',processingVersion:3,
  sections:[{id:id+'-section',distanceMeters:length,geometry:[{latitude:0,longitude:0},{latitude:0,longitude:.1}]}]};}
function trace(r:Road,start=0,end=r.sections[0].distanceMeters):PersistedTrace {
  return {id:`${r.driveId}:${r.id}:${r.sections[0].id}:${start.toFixed(3)}:${end.toFixed(3)}`,
    sourceDriveId:r.driveId,sourcePublishId:r.id+'-publish',validatedRoadId:r.id,matchedSectionId:r.sections[0].id,
    startOffsetMeters:start,endOffsetMeters:end,directionKey:'east',processingVersion:3,
    activeFromGeneration:'1',activeToGeneration:null,minLatitude:0,maxLatitude:0,minLongitude:0,maxLongitude:.1,
    createdAt:now,updatedAt:now};
}
function input(t:PersistedTrace,c:Road,winners:[number,number][],secondStart=0):MutationInput {
  const start=t.startOffsetMeters,end=t.endOffsetMeters;
  const m:Match={firstDriveId:t.sourceDriveId,secondDriveId:c.driveId,firstSectionId:t.matchedSectionId,
    secondSectionId:c.sections[0].id,firstStartOffsetMeters:start,firstEndOffsetMeters:end,
    secondStartOffsetMeters:secondStart,secondEndOffsetMeters:secondStart+end-start,
    commonDistanceMeters:end-start,directionCompatible:true,ownershipCovered:true,comparisonEligible:end-start>=3000,
    geometryConfidence:1,commonStart:{latitude:0,longitude:0},commonEnd:{latitude:0,longitude:.1},
    referenceGeometry:[{latitude:0,longitude:0},{latitude:0,longitude:.1}]};
  return {traceId:t.id,sourcePublishId:t.sourcePublishId,
    coverage:{trace:t,match:m,activeStartOffsetMeters:start,activeEndOffsetMeters:end,
      challengerStartOffsetMeters:secondStart,challengerEndOffsetMeters:secondStart+end-start,
      commonDistanceMeters:end-start,comparisonEligible:end-start>=3000},scoring:{status:'success',windows:[],winningRegions:[]},
    regions:winners.map(([a,b])=>({existingDriveId:t.sourceDriveId,challengerDriveId:c.driveId,
      startOffsetOnExistingMeters:a,endOffsetOnExistingMeters:b,startOffsetOnChallengerMeters:secondStart+a-start,
      endOffsetOnChallengerMeters:secondStart+b-start,commonStartOffsetMeters:a-start,commonEndOffsetMeters:b-start,
      winningDistanceMeters:b-a,algorithmVersion:1,confidence:1,supportingWindowCount:Math.floor((b-a)/100),
      winnerDriveId:c.driveId,comparisonEligible:true,bridgedDistanceMeters:0,comparisons:[]}))};
}
const incumbent=road('owner'),challenger=road('challenger'),t=trace(incumbent);
export const cases:{name:string;snapshot:{generation:string;isEmpty:boolean;candidates:PersistedTrace[];roads:Road[]};
  challenger:Road;publishId:string;inputs:MutationInput[];now:string}[]=[];
function add(name:string,c=challenger,traces=[t],inputs=[input(t,c,[])]):void {
  cases.push({name,snapshot:{generation:'1',isEmpty:false,candidates:traces,roads:[incumbent]},challenger:c,
    publishId:'challenger-publish',inputs,now});
}
for(const [name,w] of [ ['no-win',[]],['full',[[0,10000]]],['start',[[0,2000]]],['end',[[8000,10000]]],
  ['middle',[[4000,6000]]],['multiple',[[2000,4000],[6000,8000]]],['remainder999',[[999,9000]]],
  ['remainder1000',[[1000,9000]]],['winning1999',[[4000,5999]]],['winning2000',[[4000,6000]]]] as [string,[number,number][]][]) {
  add(name,challenger,[t],[input(t,challenger,w)]);
}
const partial=trace(incumbent,2000,8000);add('partial',challenger,[partial],[input(partial,challenger,[[4000,6000]],2000)]);
const short=trace(incumbent,0,2999);add('under3km',challenger,[short],[input(short,challenger,[])]);
add('opposite',challenger,[t],[]);
const owner2=road('owner2'),t2=trace(owner2,0,5000),t1=trace(incumbent,0,5000);
add('multiple-incumbents',challenger,[t1,t2],[input(t1,challenger,[[0,5000]]),input(t2,challenger,[[0,5000]],5000)]);
const multi=structuredClone(challenger); multi.sections=[{...multi.sections[0],distanceMeters:5000},
  {id:'later',distanceMeters:5000,geometry:[{latitude:1,longitude:0},{latitude:1,longitude:.1}]}];
add('multi-section',multi,[t1],[input(t1,multi,[])]);
const f=trace(incumbent,2400.123456789,7600.987654321);add('fractional-offset',challenger,[f],
  [input(f,challenger,[[3500.123456789,6000.987654321]],2400.123456789)]);
// Two separate matches for one trace must be grouped, not overwrite splits.
add('multiple-matches-one-trace',challenger,[t],[input(t,challenger,[[2000,4000]]),input(t,challenger,[[6000,8000]])]);
const big=structuredClone(cases[0]);big.name='bigint-generation';big.snapshot.generation='9007199254740993';cases.push(big);
add('adjacent-incumbent-merge',challenger,[trace(incumbent,0,5000),trace(incumbent,5000,10000)],
  [input(trace(incumbent,0,5000),challenger,[]),input(trace(incumbent,5000,10000),challenger,[],5000)]);
await Deno.writeTextFile('test/fixtures/active_world_mutation.json',JSON.stringify(cases)+'\n');
