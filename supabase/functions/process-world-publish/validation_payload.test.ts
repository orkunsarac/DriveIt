import assert from "node:assert/strict";
import test from "node:test";
import { readFileSync } from "node:fs";
import { matchRoad, type MatchingResult } from "./world_validation.ts";
import { roadPayload, serializeValidationStatus } from "./validation_payload.ts";

const cases = JSON.parse(readFileSync(new URL('../../../test/fixtures/validation_status_contract.json',import.meta.url),'utf8'));
for(const c of cases) {
  test(`explicit persisted status mapping: ${c.internal}`,()=>assert.equal(serializeValidationStatus(c.internal),c.persisted));
  test(`provider -> real roadPayload contract: ${c.internal}`,async()=>{
    const result=await matchRoad(c.route.map(([latitude,longitude]:number[])=>({latitude,longitude})),[],"synthetic",async()=>({status:200,body:JSON.stringify({code:"Ok",matchings:c.matchings.map((coordinates:number[][])=>({geometry:{type:"LineString",coordinates},confidence:.9}))})}));
    assert.equal(result.status,c.internal);
    const payload=roadPayload(result);
    assert.equal(payload.road.validation_status,c.persisted);
    assert.doesNotMatch(JSON.stringify(payload),/partiallyValidated/);
    assert.equal(payload.sections.length,c.matchings.length);
    assert.equal(payload.road.geometry.type,'MultiLineString');
  });
}
test('failed and unknown runtime statuses cannot create a DB payload',()=>{
  for(const status of ['failed','unexpected','partially_validated',null]) {
    assert.throws(()=>serializeValidationStatus(status as MatchingResult['status']),/^Error: validation_status_invalid$/);
  }
});

test('real entrypoint sends canonical finish RPC payload and preserves safe persistence recovery',async()=>{
  const runtime=Deno as unknown as {serve:(handler:unknown)=>unknown};
  const oldServe=runtime.serve, oldFetch=globalThis.fetch, oldLog=console.info;
  const envKeys=['SUPABASE_URL','SUPABASE_SECRET_KEYS','MAPBOX_ACCESS_TOKEN'];
  const oldEnv=envKeys.map(k=>Deno.env.get(k));
  let handler:((r:Request)=>Promise<Response>)|undefined;
  runtime.serve=h=>{handler=h as typeof handler;return {}};
  console.info=()=>{};
  Deno.env.set('SUPABASE_URL','https://synthetic.invalid');
  Deno.env.set('SUPABASE_SECRET_KEYS',JSON.stringify({default:'synthetic-server-key'}));
  Deno.env.set('MAPBOX_ACCESS_TOKEN','synthetic-provider-key');
  const publishId='00000000-0000-4000-8000-000000000010',userId='00000000-0000-4000-8000-000000000020';
  try {
    await import('./index.ts?validation-status-regression');
    assert.ok(handler);
    for(const c of cases) for(const failPersist of [false,true]) {
      let persisted=false;const calls:string[]=[],bodies:Record<string,any>[]=[];
      const route=c.route.map(([latitude,longitude]:number[])=>({latitude,longitude}));
      const source={schema_version:1,publish_id:publishId,local_drive_id:'synthetic-drive',telemetry_version:1,drive_score_algorithm_version:1,world_rules_version:6,
        started_at:'2026-01-01T00:00:00Z',ended_at:'2026-01-01T00:01:00Z',recorded_distance_meters:7000,raw_route:route,
        canonical_telemetry:route.map((p:object,i:number)=>({...p,timestamp:`2026-01-01T00:00:0${i}Z`,speed_mps:8,heading_degrees:90,altitude_meters:50,accuracy_meters:5,distance_from_previous_meters:0,acceleration_mps2:0}))};
      const publish={id:publishId,user_id:userId,local_drive_id:'synthetic-drive',source_path:`${userId}/${publishId}.json`,source_ready_at:'2026-01-01T00:00:00Z',source_schema_version:1,telemetry_version:1,drive_score_algorithm_version:1,world_rules_version:6,raw_route_point_count:2,telemetry_point_count:2};
      globalThis.fetch=async(input,init)=>{
        const uri=typeof input==='string'?input:input instanceof URL?input.href:input.url;
        const path=new URL(uri).pathname;calls.push(path);
        const reply=(v:unknown,status=200)=>new Response(JSON.stringify(v),{status,headers:{'content-type':'application/json'}});
        if(path==='/auth/v1/user') return reply({id:userId});
        if(path==='/rest/v1/world_publishes')return reply(publish);
        if(path==='/rest/v1/world_validated_roads') return reply(persisted?{id:publishId,valid_distance_meters:7000,section_count:c.matchings.length,processing_version:3,direction_key:'east'}:null);
        if(path==='/rest/v1/world_active_world_generations') return reply({generation:'1',operation_id:'synthetic',trace_count:1});
        if(path.endsWith('/claim_world_publish_validation'))return reply({state:'claimed',claim_token:publishId});
        if(path.endsWith('/finish_world_publish_validation')) {
          const body=JSON.parse(String(init?.body));bodies.push(body);
          assert.equal(body.p_road.validation_status,c.persisted);
          assert.doesNotMatch(JSON.stringify(body),/partiallyValidated/);
          if(failPersist)return reply({code:'23514',message:'synthetic DB failure',details:'must-not-leak'},400);
          persisted=true;return reply({state:'created'});
        }
        if(path.endsWith('/fail_world_publish_validation')) {bodies.push(JSON.parse(String(init?.body)));return reply(true)}
        if(path.startsWith('/storage/v1/object/'))return reply(source);
        if(path.startsWith('/matching/v5/'))return reply({code:'Ok',matchings:c.matchings.map((coordinates:number[][])=>({geometry:{type:'LineString',coordinates},confidence:.9}))});
        throw Error('Unmocked request prohibited');
      };
      const response=await handler!(new Request('https://synthetic.invalid/',{method:'POST',headers:{authorization:'Bearer synthetic-user-token','content-type':'application/json'},body:JSON.stringify({publish_id:publishId})}));
      assert.equal(response.status,failPersist?503:200);
      const body=await response.json();
      if(failPersist){assert.deepEqual(body,{ok:false,error_code:'validation_persist_failed'});const release=bodies.at(-1)!;assert.equal(release.p_retryable,true);assert.equal(release.p_error_code,'validation_persist_failed');}
      else assert.equal(body.ok,true);
      assert.equal(calls.filter(p=>p.endsWith('/finish_world_publish_validation')).length,1);
      assert.doesNotMatch(JSON.stringify(body),/must-not-leak|synthetic-user-token|synthetic-server-key/);
    }
  } finally {
    runtime.serve=oldServe;globalThis.fetch=oldFetch;console.info=oldLog;
    envKeys.forEach((k,i)=>oldEnv[i]===undefined?Deno.env.delete(k):Deno.env.set(k,oldEnv[i]!));
  }
});
