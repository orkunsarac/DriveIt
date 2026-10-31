import {createClient} from 'npm:@supabase/supabase-js@2.117.2';
import {assertCanonicalTarget,localSql} from './local_acceptance_target.ts';
function check(v:unknown,m:string):asserts v {if(!v)throw Error(m);}
Deno.test('Planet real Auth/profile, private source, publish/retry, viewport/detail and cross-owner denial (provider fixture)',async()=>{
 await assertCanonicalTarget();
 const url=Deno.env.get('PHASE8_LOCAL_URL')!;
 const anon=Deno.env.get('PHASE8_LOCAL_ANON_KEY')!, service=Deno.env.get('PHASE8_LOCAL_SERVICE_ROLE_KEY')!;
 const client=(key:string)=>createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false},global:{fetch:(i,o)=>fetch(i,{...o,signal:o?.signal??AbortSignal.timeout(30000)})}});
 const admin=client(service),a=client(anon),b=client(anon),ids:string[]=[];
 let publishId:string|undefined,path:string|undefined;
 const base=await localSql('select current_generation from public.world_active_world_state where singleton;');
 check(/^\d+$/.test(base),'valid base generation');
 try{
  const password=`Local-${crypto.randomUUID()}!`;
  for(const c of [a,b]){
   const email=`pgr5b-${crypto.randomUUID()}@example.invalid`;
   const created=await admin.auth.admin.createUser({email,password,email_confirm:true});
   check(!created.error&&created.data.user,'create synthetic Auth user');ids.push(created.data.user.id);
   check(!(await c.auth.signInWithPassword({email,password})).error,'synthetic login');
  }
  const profile=await a.from('profiles').select('id').eq('id',ids[0]).single();
  check(!profile.error&&profile.data.id===ids[0],'profile trigger');
  const started=new Date('2026-01-01T00:00:00Z'), ended=new Date(started.getTime()+599000),driveId=`synthetic-${crypto.randomUUID()}`;
  const row=await a.from('world_publishes').insert({local_drive_id:driveId,started_at:started.toISOString(),ended_at:ended.toISOString(),distance_meters:6660,world_rules_version:6}).select('id').single();
  check(!row.error&&row.data,'pending publish');publishId=row.data.id;path=`${ids[0]}/${publishId}.json`;
  const route=Array.from({length:600},(_,i)=>({latitude:0,longitude:i*0.0001}));
  const source={publish_id:publishId,local_drive_id:driveId,schema_version:1,telemetry_version:1,drive_score_algorithm_version:1,world_rules_version:6,started_at:started.toISOString(),ended_at:ended.toISOString(),recorded_distance_meters:6660,raw_route:route,canonical_telemetry:route.map((p,i)=>({...p,timestamp:new Date(started.getTime()+i*1000).toISOString(),speed_mps:11.12,heading_degrees:90,altitude_meters:0,accuracy_meters:3,distance_from_previous_meters:i?11.12:0,acceleration_mps2:0}))};
  check(!(await a.storage.from('world-drive-sources').upload(path,new Blob([JSON.stringify(source)],{type:'application/json'}))).error,'private source upload');
  check((await b.storage.from('world-drive-sources').download(path)).error,'cross-owner source denied');
  check(!(await a.rpc('attach_world_publish_source',{p_publish_id:publishId,p_source_schema_version:1,p_telemetry_version:1,p_drive_score_algorithm_version:1,p_raw_route_point_count:600,p_telemetry_point_count:600})).error,'source attachment');
  const invoke=async(c:typeof a,name:string,body:unknown)=>{
   const session=await c.auth.getSession();
   const r=await fetch(`${url}/functions/v1/${name}`,{method:'POST',headers:{apikey:anon,authorization:`Bearer ${session.data.session!.access_token}`,'content-type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(60000)});
   return {status:r.status,body:await r.json()};
  };
  const forbidden=await invoke(b,'process-world-publish',{publish_id:publishId});
  check(forbidden.status===404,`cross-owner publish denied: HTTP ${forbidden.status}, ${forbidden.body.error_code??''}`);
  const first=await invoke(a,'process-world-publish',{publish_id:publishId});
  check(first.status===200&&first.body.ok,`publish failed ${first.status} ${first.body.error_code??''}`);
  const retry=await invoke(a,'process-world-publish',{publish_id:publishId});check(retry.status===200&&retry.body.ok,'publish idempotent retry');
  const viewport=await b.rpc('read_planet_viewport',{p_south:-0.01,p_north:0.01,p_west:-0.01,p_east:0.08,p_zoom:15});
  check(!viewport.error&&viewport.data.traces?.length>0,'public Planet viewport reads published trace');
  const trace=viewport.data.traces[0];const traceId=trace.trace_id??trace.id;
  check(typeof traceId==='string','trace identity');
  const detail=await invoke(b,'planet-trace-detail',{trace_id:traceId});check(detail.status===200,'published detail read');
  check(await localSql(`select count(*) from public.world_validated_roads where publish_id='${publishId}';`)==='1','retry does not duplicate road');
 }finally{
  await assertCanonicalTarget();
  if(path)check(!(await admin.storage.from('world-drive-sources').remove([path])).error,'source cleanup');
  if(publishId){check(/^[0-9a-f-]{36}$/.test(publishId),'safe fixture id');
   await localSql(`begin; update public.world_active_world_state set current_generation=${base} where singleton and current_generation in(select generation from public.world_active_world_generations where source_publish_id='${publishId}'); delete from public.world_active_world_traces where source_publish_id='${publishId}'; delete from public.world_active_world_generations where source_publish_id='${publishId}'; delete from public.world_validated_road_sections where validated_road_id in(select id from public.world_validated_roads where publish_id='${publishId}'); delete from public.world_validated_roads where publish_id='${publishId}'; delete from public.world_publishes where id='${publishId}'; commit;`);
  }
  for(const id of ids)check(!(await admin.auth.admin.deleteUser(id)).error,'Auth fixture cleanup');
 }
});
