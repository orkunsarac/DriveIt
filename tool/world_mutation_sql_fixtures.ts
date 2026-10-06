import {cases} from './world_mutation_fixtures.ts';
import {planWorldMutation} from '../supabase/functions/process-world-publish/world_mutation.ts';
const roadIds:Record<string,string>={owner:'00000000-0000-4000-8000-000000000011',
  owner2:'00000000-0000-4000-8000-000000000012',challenger:'00000000-0000-4000-8000-000000000013'};
const pubIds:Record<string,string>={'owner-publish':'00000000-0000-4000-8000-000000000021',
  'owner2-publish':'00000000-0000-4000-8000-000000000022','challenger-publish':'00000000-0000-4000-8000-000000000023'};
const output=cases.filter(c=>c.name!=='bigint-generation').map(raw=>{
  const c=structuredClone(raw);
  c.challenger.id=roadIds.challenger;
  c.publishId=pubIds['challenger-publish'];
  for(const t of c.snapshot.candidates){t.validatedRoadId=roadIds[t.validatedRoadId];t.sourcePublishId=pubIds[t.sourcePublishId];
    t.id=`${t.sourceDriveId}:${t.validatedRoadId}:${t.matchedSectionId}:${t.startOffsetMeters.toFixed(3)}:${t.endOffsetMeters.toFixed(3)}`;}
  for(let i=0;i<c.inputs.length;i++){
    const v=c.inputs[i],old=raw.inputs[i].traceId;
    v.traceId=c.snapshot.candidates[raw.snapshot.candidates.findIndex(t=>t.id===old)].id;
    v.coverage.trace=c.snapshot.candidates.find(t=>t.id===v.traceId)!;
  }
  return {...c,plan:planWorldMutation(c.snapshot,c.challenger,c.publishId,c.inputs,c.now)};
});
await Deno.writeTextFile('test/fixtures/active_world_mutation_sql.json',JSON.stringify(output)+'\n');
