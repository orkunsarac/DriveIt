import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import {planWorldMutation,commitWorldMutation} from './world_mutation.ts';
const cases=JSON.parse(readFileSync(new URL('../../../test/fixtures/active_world_mutation.json',import.meta.url),'utf8'));
const oracle=JSON.parse(readFileSync(new URL('../../../test/fixtures/active_world_mutation_oracle.json',import.meta.url),'utf8'));
for(const [i,c] of cases.entries()) test(`native Dart/server mutation parity: ${c.name}`,()=>{
  const p=planWorldMutation(c.snapshot,c.challenger,c.publishId,c.inputs,c.now);
  assert.equal(p.operationId,oracle[i].operationId);
  assert.equal(p.generation,(BigInt(c.snapshot.generation)+1n).toString());
  const closed=new Set(p.closeVersions.map(t=>t.id));
  const result=[...c.snapshot.candidates.filter((t:{id:string})=>!closed.has(t.id)),...p.createTraces];
  const canonical=(ts:Record<string,unknown>[])=>ts.map(t=>({id:t.id,sourceDriveId:t.sourceDriveId,
    validatedRoadId:t.validatedRoadId,matchedSectionId:t.matchedSectionId,directionKey:t.directionKey,
    start:Number(t.startOffsetMeters),end:Number(t.endOffsetMeters),version:t.processingVersion,
    bounds:[t.minLatitude,t.maxLatitude,t.minLongitude,t.maxLongitude].map(Number)})).sort((a,b)=>String(a.id).localeCompare(String(b.id)));
  assert.deepEqual(canonical(result),canonical(oracle[i].traces));
  assert.deepEqual(planWorldMutation(c.snapshot,c.challenger,c.publishId,c.inputs,c.now),p);
  if(c.name==='no-win'){assert.equal(p.closeVersions.length,0);assert.equal(p.createTraces.length,0);}
  for(const t of p.createTraces) assert.equal(t.sourcePublishId,t.sourceDriveId==='challenger-drive'?c.publishId:'owner-publish');
});
test('middle split has incumbent 4km remainders, 2km challenger',()=>{
  const c=cases.find((c:{name:string})=>c.name==='middle');
  const p=planWorldMutation(c.snapshot,c.challenger,c.publishId,c.inputs,c.now);
  assert.equal(p.closeVersions.length,1);assert.equal(p.createTraces.length,3);
  assert.deepEqual(p.createTraces.map(t=>Number(t.endOffsetMeters)-Number(t.startOffsetMeters)).sort((a,b)=>a-b),[2000,4000,4000]);
});
test('commit exact publish and string bigint; stale and response-lost retries use authoritative RPC',async()=>{
  const c=cases[0],p=planWorldMutation(c.snapshot,c.challenger,c.publishId,c.inputs,c.now);
  let committed=false,calls=0;
  const rpc=async(name:string,args:Record<string,unknown>)=>{
    assert.equal(name,'commit_active_world_mutation');assert.equal(args.p_publish_id,c.publishId);
    assert.equal(args.p_expected_generation,'1');calls++;
    if(!committed){committed=true;return {data:null,error:new Error('lost response')};}
    return {data:{state:'already_processed',generation:'2'},error:null};
  };
  await assert.rejects(()=>commitWorldMutation(p,c.publishId,rpc));
  assert.equal((await commitWorldMutation(p,c.publishId,rpc)).state,'already_processed');assert.equal(calls,2);
  assert.equal((await commitWorldMutation(p,c.publishId,async()=>({data:{state:'stale_generation'},error:null}))).state,'stale_generation');
});
test('RPC contract locks pointer, checks CAS, provenance, canonical bounds, service-only and final pointer order',()=>{
  const sql=readFileSync(new URL('../../migrations/202610060002_active_world_mutation.sql',import.meta.url),'utf8');
  assert.match(sql,/where singleton for update/);assert.match(sql,/v_current <> p_expected_generation/);
  assert.ok(sql.indexOf("state','already_processed")<sql.indexOf('v_current <> p_expected_generation'));
  for(const code of ['invalid_trace_provenance','invalid_incumbent_remainder','trace_outside_canonical_section','duplicate_active_interval'])assert.ok(sql.includes(code));
  assert.match(sql,/from public,anon,authenticated/);assert.match(sql,/to service_role/);
  assert.ok(sql.indexOf("set status='published'")<sql.indexOf('set current_generation=v_next'));
});
