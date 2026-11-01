import {createClient,type SupabaseClient} from 'npm:@supabase/supabase-js@2.117.2';
import {rebuildPlanet,type RebuildContext} from '../../functions/delete-account/planet_rebuild.ts';
function check(v:unknown,m:string):asserts v {if(!v)throw Error(m);}
const url=Deno.env.get('PGR6_LOCAL_URL')??'';
let container=Deno.env.get('PGR6_CONTAINER')??'';
const anon=Deno.env.get('PGR6_ANON')??'',service=Deno.env.get('PGR6_SERVICE')??'';
async function sql(q:string){
 check(/^supabase-pgr6a-[0-9a-f]{10}-pgr6a-[0-9a-f]{10}-database-[0-9a-f]+$/.test(container),'pinned disposable container');
 const r=await new Deno.Command('docker',{args:['exec',container,'psql','-U','postgres','-d','postgres','-X','-At','-v','ON_ERROR_STOP=1','-c',q],stdout:'piped',stderr:'piped'}).output();
 check(r.success,'local test SQL failed');return new TextDecoder().decode(r.stdout).trim();
}
async function target(){
 check(/^http:\/\/127\.0\.0\.1:\d+$/.test(url),'loopback only');
 const prefix=container.slice(0,container.lastIndexOf('-database-'))+'-database-';
 const inventory=await new Deno.Command('docker',{args:['ps','--format','{{.Names}}'],stdout:'piped',stderr:'piped'}).output();
 check(inventory.success,'local DB inventory');
 const candidates=new TextDecoder().decode(inventory.stdout).trim().split(/\r?\n/).filter(n=>n.startsWith(prefix)&&/^[a-f0-9]+$/.test(n.slice(prefix.length)));
 check(candidates.length===1,'one DB in pinned stack');
 // Container names are ephemeral; physical identity below never changes.
 container=candidates[0];
 const r=await new Deno.Command('docker',{args:['inspect','--format','{{range .HostConfig.Mounts}}{{if eq .Target "/var/lib/postgresql/data"}}{{.VolumeOptions.Subpath}}{{end}}{{end}}',container],stdout:'piped',stderr:'piped'}).output();
 check(r.success&&new TextDecoder().decode(r.stdout).trim()===Deno.env.get('PGR6_SUBPATH'),'physical identity');
 check(await sql('select system_identifier from pg_control_system();')===Deno.env.get('PGR6_SYSTEM'),'system identity');
 const settings=await fetch(`${url}/auth/v1/settings`,{headers:{apikey:anon},signal:AbortSignal.timeout(10000)});
 check(settings.ok&&(await settings.json()).disable_signup===true,'test signup remains closed');
 check(await sql('select enabled from public.phase8_group_rollout where singleton;')==='f','test Group Drive gate remains closed');
}
const client=(key:string)=>createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false},global:{fetch:(i,o)=>fetch(i,{...o,signal:o?.signal??AbortSignal.timeout(30000)})}});
type User={id:string;email:string;password:string;client:SupabaseClient;token:string};
async function fixture(run:(admin:SupabaseClient,create:()=>Promise<User>,receipt:()=>{requestId:string;receiptToken:string})=>Promise<void>){
 await target();const admin=client(service),users:User[]=[],jobs:string[]=[];
 try{
  for(const id of ['phase8-drive-staging','world-drive-sources']){const b=await admin.storage.getBucket(id);if(b.error)check(!(await admin.storage.createBucket(id,{public:false})).error,'create local bucket');}
  await run(admin,async()=>{
   const password=`Synthetic-${crypto.randomUUID()}!`,email=`pgr6a-${crypto.randomUUID()}@example.invalid`;
   const result=await admin.auth.admin.createUser({email,password,email_confirm:true});check(!result.error&&result.data.user,'synthetic create');
   const c=client(anon),s=await c.auth.signInWithPassword({email,password});check(!s.error&&s.data.session,'synthetic login');
   const u={id:result.data.user.id,email,password,client:c,token:s.data.session.access_token};users.push(u);return u;
  },()=>{const id=crypto.randomUUID();jobs.push(id);return {requestId:id,receiptToken:[...crypto.getRandomValues(new Uint8Array(32))].map(x=>x.toString(16).padStart(2,'0')).join('')};});
 }finally{
  await target();
  for(const u of users){
   for(const bucket of ['phase8-drive-staging','world-drive-sources']){
    const list=await admin.storage.from(bucket).list(u.id,{limit:1000});check(!list.error,'fixture list');
    for(const f of list.data){if(f.id){check(!(await admin.storage.from(bucket).remove([`${u.id}/${f.name}`])).error,'fixture file cleanup');}else{const nested=await admin.storage.from(bucket).list(`${u.id}/${f.name}`,{limit:1000});check(!nested.error,'nested fixture list');const paths=nested.data.map(x=>`${u.id}/${f.name}/${x.name}`);if(paths.length)check(!(await admin.storage.from(bucket).remove(paths)).error,'nested fixture cleanup');}}
   }
   await sql(`begin;set local session_replication_role=replica;delete from public.account_deletion_jobs where owner_id='${u.id}';delete from public.world_validated_road_sections where validated_road_id in(select id from public.world_validated_roads where user_id='${u.id}');do $$declare r record;begin for r in select table_name,column_name from information_schema.columns where table_schema='public' and column_name in('owner_id','user_id','account_id','administrator_id') and table_name<>'account_deletion_jobs' loop execute format('delete from public.%I where %I=$1',r.table_name,r.column_name) using '${u.id}'::uuid;end loop;end$$;commit;`);
   const deleted=await admin.auth.admin.deleteUser(u.id);if(deleted.error){check((await admin.auth.admin.getUserById(u.id)).error,'fixture already absent');}
   await sql(`delete from auth.audit_log_entries where payload::text like '%${u.id}%';`);
  }
  for(const id of jobs)await sql(`begin;delete from public.account_deletion_replays where job_id='${id}';delete from public.account_deletion_events where job_id='${id}';delete from public.account_deletion_jobs where id='${id}';commit;`);
 }
}
async function call(body:unknown,token?:string){const r=await fetch(`${url}/functions/v1/delete-account`,{method:'POST',headers:{apikey:anon,'content-type':'application/json',...(token?{authorization:`Bearer ${token}`}:{})},body:JSON.stringify(body),signal:AbortSignal.timeout(60000)});return {status:r.status,body:await r.json()};}
const request=(u:User,r:Record<string,string>,extra:Record<string,unknown>={})=>call({...r,action:'request',expectedOwner:u.id,confirm:'DELETE_MY_ACCOUNT',password:u.password,...extra},u.token);

async function seedPrivateDrive(u:User){
 const intent=crypto.randomUUID(),source=crypto.randomUUID(),key='owner-sync-v2:'+'c'.repeat(64),path=`${u.id}/${intent}/envelope.json`;
 await sql(`begin;
 insert into public.phase8_drive_upload_intents(id,owner_id,idempotency_key,source_identity,owner_scope,contract_version,payload_fingerprint,object_sha256,object_bytes,staging_path,state,receipt,finalized_at)
 values('${intent}','${u.id}','${key}','${source}','["local_account_store_v1","account","${u.id}"]',2,repeat('a',64),repeat('b',64),2,'${path}','finalized','{}',now());
 insert into public.phase8_drive_owner_sequences(owner_id,high_water) values('${u.id}',1);
 insert into public.phase8_drive_manifests(owner_id,source_identity,drive_id,idempotency_key,contract_version,payload_fingerprint,object_sha256,object_bytes,object_path,change_sequence)
 values('${u.id}','${source}','synthetic','${key}',2,repeat('a',64),repeat('b',64),2,'${path}',1);
 insert into public.phase8_drive_changes(owner_id,sequence,source_identity,operation,idempotency_key,payload_fingerprint,object_sha256,object_path)
 values('${u.id}',1,'${source}','drive_upsert','${key}',repeat('a',64),repeat('b',64),'${path}');
 insert into public.phase8_drive_snapshots(owner_id,high_water) values('${u.id}',1);commit;`);
}

Deno.test('account deletion: populated private cloud and administrator group purge preserves B',()=>fixture(async(_admin,create,receipt)=>{
 const a=await create(),b=await create(),r=receipt(),group=crypto.randomUUID(),invite=crypto.randomUUID();
 await seedPrivateDrive(a);await seedPrivateDrive(b);
 await sql(`begin;insert into public.phase8_groups(id,administrator_id,invite_code,invite_hash) values('${group}','${a.id}','${invite}',extensions.digest('${invite}','sha256'));
 insert into public.phase8_group_memberships(group_id,account_id,role,join_order,color_index) values('${group}','${a.id}','administrator',1,1),('${group}','${b.id}','member',2,2);commit;`);
 check((await request(a,r)).status===202,'request');
 check(await sql(`select status from public.phase8_groups where id='${group}';`)==='ended','admin group ended on request');
 check(await sql(`select sharing_state from public.phase8_group_memberships where group_id='${group}' and account_id='${b.id}';`)==='off','other member grant revoked without deleting their drive');
 const result=await call({...r,action:'run'});check(result.status===200&&result.body.state==='completed','full private cloud deletion completes');
 for(const table of ['phase8_drive_upload_intents','phase8_drive_owner_sequences','phase8_drive_manifests','phase8_drive_changes','phase8_drive_snapshots']){
  check(await sql(`select count(*) from public.${table} where owner_id='${a.id}';`)==='0','A private row erased');
  check(await sql(`select count(*) from public.${table} where owner_id='${b.id}';`)==='1','B private row preserved');
 }
 check(await sql(`select count(*) from public.phase8_groups where id='${group}';`)==='0','group metadata removed');
 check(await sql('select enabled from public.phase8_group_rollout where singleton;')==='f','Group gate remains closed');
}));

Deno.test('account deletion: unshared Planet data is erased, neutral generation ordering retained',()=>fixture(async(admin,create,receipt)=>{
 const a=await create(),r=receipt(),publish=crypto.randomUUID(),road=crypto.randomUUID();
 const generation=Number(await sql('select current_generation from public.world_active_world_state where singleton;'))+1;
 const path=`${a.id}/${publish}.json`;
 check(!(await a.client.storage.from('world-drive-sources').upload(path,new Blob(['{}'],{type:'application/json'}))).error,'synthetic route source');
 await sql(`begin;
 insert into public.world_publishes(id,user_id,local_drive_id,started_at,ended_at,distance_meters,world_rules_version) values('${publish}','${a.id}','synthetic-solo',now(),now(),6000,6);
 insert into public.world_validated_roads(id,publish_id,user_id,provider_id,processing_version,valid_distance_meters,validation_status,direction_key,section_count,geometry) values('${road}','${publish}','${a.id}','fixture',3,6000,'validated','east',1,extensions.ST_Multi(extensions.ST_GeomFromText('LINESTRING(0 0,0.06 0)',4326)));
 insert into public.world_active_world_generations(generation,base_generation,operation_id,operation_reason,source_publish_id,source_drive_session_id,drive_score_algorithm_version,validated_road_processing_version,valid_distance_meters,trace_count,created_at) values(${generation},${generation-1},'synthetic-solo','recordProcessing','${publish}','synthetic-solo',1,3,6000,1,now());
 insert into public.world_active_world_traces(trace_id,active_from_generation,source_publish_id,source_drive_session_id,validated_road_id,matched_section_id,start_offset_meters,end_offset_meters,direction_key,min_latitude,max_latitude,min_longitude,max_longitude,bounds,processing_version,created_at,updated_at)
 values('synthetic-trace',${generation},'${publish}','synthetic-solo','${road}','section-0',0,6000,'east',0,0,0,0.06,extensions.ST_MakeEnvelope(0,0,0.06,0,4326),3,now(),now());
 update public.world_active_world_state set current_generation=${generation} where singleton;commit;`);
 try{
  check((await request(a,r)).status===202,'Planet deletion accepted');
  const result=await call({...r,action:'run'});check(result.status===200&&result.body.state==='completed','solo Planet deletion completes');
  check(await sql(`select count(*) from public.world_publishes where id='${publish}';`)==='0','publish removed');
  check(await sql(`select count(*) from public.world_validated_roads where id='${road}';`)==='0','road geometry removed');
  check(await sql(`select count(*) from public.world_active_world_traces where source_publish_id='${publish}';`)==='0','trace geometry removed');
  check(await sql(`select source_publish_id is null and source_drive_session_id is null and valid_distance_meters is null from public.world_active_world_generations where generation=${generation};`)==='t','generation identity/distance links erased');
  check(await sql('select current_generation from public.world_active_world_state where singleton;')===String(generation+1),'deletion invalidates old Planet mutation generation');
  check((await admin.storage.from('world-drive-sources').download(path)).error,'raw GPS source erased');
 }finally{
  await sql(`begin;delete from public.world_active_world_traces where source_publish_id='${publish}';update public.world_active_world_state set current_generation=${generation-1} where singleton and current_generation in(${generation},${generation+1});delete from public.world_active_world_generations where generation=${generation+1} and operation_id='account-deletion-generation:${generation+1}';delete from public.world_active_world_generations where generation=${generation};commit;`);
 }
}));

Deno.test('account deletion: explicit confirmation, password reauthentication and A/B authority',()=>fixture(async(_admin,create,receipt)=>{
 const a=await create(),b=await create(),r=receipt();
 check((await call({...r,action:'request',password:a.password,confirm:'DELETE_MY_ACCOUNT'})).status===401,'missing JWT denied');
 check((await request(a,r,{password:'wrong-password'})).status===403,'wrong reauthentication denied');
 check((await request(a,r,{confirm:'NO'})).status===400,'explicit confirmation required');
 check((await request(a,r,{expectedOwner:b.id})).status===403,'stale client identity cannot delete the JWT account');
 check(await sql('select count(*) from public.account_deletion_jobs;')==='0','no mutation before authorization');
 const res=await request(a,r,{ownerId:b.id});check(res.status===202,'request accepted');
 check(await sql(`select owner_id from public.account_deletion_jobs where id='${r.requestId}';`)===a.id,'body cannot choose another account');
 check((await b.client.rpc('account_deletion_request',{p_owner:a.id,p_id:r.requestId,p_hash:'a'.repeat(64)})).error,'client cannot call service RPC');
 check((await call({...r,receiptToken:'b'.repeat(64),action:'run'})).status!==200,'wrong receipt denied');
 check(await sql(`select count(*) from auth.users where id='${b.id}';`)==='1','B preserved');
}));

Deno.test('account deletion: real Storage paging, frozen sessions, retry and complete ACK',()=>fixture(async(admin,create,receipt)=>{
 const a=await create(),b=await create(),r=receipt();
 const files=Array.from({length:101},(_,i)=>`${a.id}/${i}.json`);
 for(let i=0;i<files.length;i+=10){await Promise.all(files.slice(i,i+10).map(async path=>check(!(await a.client.storage.from('world-drive-sources').upload(path,new Blob(['{}'],{type:'application/json'}))).error,'synthetic storage upload')));}
 const bpath=`${b.id}/keep.json`;check(!(await b.client.storage.from('world-drive-sources').upload(bpath,new Blob(['{}'],{type:'application/json'}))).error,'B own file');
 check((await request(a,r)).status===202,'deletion durable');
 check((await a.client.storage.from('world-drive-sources').upload(`${a.id}/late.json`,new Blob(['{}'],{type:'application/json'}))).error,'old JWT cannot create content');
 const blocked=await admin.rpc('phase8_begin_drive_snapshot',{p_owner_id:a.id});check(blocked.error,'sync read fenced');
 const first=await call({...r,action:'run'});check(first.status===202&&first.body.state==='pending','one bounded 100-file page');
 check(await sql(`select count(*) from auth.users where id='${a.id}';`)==='1','Auth survives incomplete Storage cleanup');
 const second=await call({...r,action:'run'});check(second.status===200&&second.body.state==='completed',`completion ${second.status}`);
 check((await call({...r,action:'run'})).body.state==='completed','lost response retry returns same completion');
 check(await sql(`select count(*) from auth.users where id='${a.id}';`)==='0','Auth gone');
 check(await sql(`select count(*) from public.profiles where id='${a.id}';`)==='0','profile gone');
 check(await sql(`select count(*) from storage.objects where name like '${a.id}/%';`)==='0','Storage gone');
 check(!(await admin.storage.from('world-drive-sources').download(bpath)).error,'B Storage preserved');
 check((await a.client.auth.refreshSession()).error,'deleted refresh session rejected');
 check(await sql(`select owner_id is null from public.account_deletion_jobs where id='${r.requestId}';`)==='t','completed audit has no owner identity');
 const late=await fetch(`${url}/storage/v1/object/world-drive-sources/${a.id}/after-delete.json`,{method:'POST',headers:{apikey:anon,authorization:`Bearer ${a.token}`,'content-type':'application/json'},body:'{}'});
 check(late.status>=400,'cryptographically valid old access token cannot resurrect Storage after completion');await late.arrayBuffer();
 const audit=await sql(`select string_agg(state,',' order by id) from public.account_deletion_events where job_id='${r.requestId}';`);
 check(audit==='pending,purged,completed','durable transition audit');
}));

Deno.test('account deletion: single-flight lease and resume after Auth response loss',()=>fixture(async(admin,create,receipt)=>{
 const a=await create(),r=receipt();check((await request(a,r)).status===202,'request');
 const hash=[...new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(r.receiptToken)))].map(x=>x.toString(16).padStart(2,'0')).join('');
 const lease=crypto.randomUUID();check(!(await admin.rpc('account_deletion_claim',{p_id:r.requestId,p_hash:hash,p_lease:lease})).error,'lease claim');
 check((await call({...r,action:'run'})).body.state==='busy','parallel worker denied');
 const purged=await admin.rpc('account_deletion_purge',{p_id:r.requestId,p_lease:lease});check(!purged.error&&purged.data==='purged','purge durable');
 check(!(await admin.auth.admin.deleteUser(a.id)).error,'simulate Auth success with response lost');
 await admin.rpc('account_deletion_release',{p_id:r.requestId,p_lease:lease});
 const completed=await call({...r,action:'run'});check(completed.status===200&&completed.body.state==='completed','retry handles already removed Auth');
}));

Deno.test('account deletion: real Storage outage preserves Auth and retry completes',()=>fixture(async(_admin,create,receipt)=>{
 const a=await create(),r=receipt(),path=`${a.id}/outage.json`;
 check(!(await a.client.storage.from('world-drive-sources').upload(path,new Blob(['{}'],{type:'application/json'}))).error,'outage fixture upload');
 check((await request(a,r)).status===202,'request');
 const prefix=container.replace(/-database-[a-f0-9]+$/,'-storage-');
 const list=await new Deno.Command('docker',{args:['ps','--format','{{.Names}}'],stdout:'piped',stderr:'piped'}).output();
 const matches=new TextDecoder().decode(list.stdout).trim().split(/\r?\n/).filter(n=>n.startsWith(prefix));check(matches.length===1,'exact isolated Storage container');
 let stopped=false;
 try{
  const stop=await new Deno.Command('docker',{args:['pause',matches[0]],stdout:'piped',stderr:'piped'}).output();check(stop.success,'pause only disposable Storage');stopped=true;
  const failure=await call({...r,action:'run'});check(failure.status===503,'Storage outage cannot report success');
  check(await sql(`select count(*) from auth.users where id='${a.id}';`)==='1','Auth retained when Storage removal fails');
  check(await sql(`select count(*) from storage.objects where name='${path}';`)==='1','file metadata retained on outage');
 }finally{
  if(stopped){const start=await new Deno.Command('docker',{args:['unpause',matches[0]],stdout:'piped',stderr:'piped'}).output();check(start.success,'resume same disposable Storage');}
 }
 const admin=client(service);let ready=false;
 for(let i=0;i<30;i++){try{if(!(await admin.storage.listBuckets()).error){ready=true;break;}}catch{/* bounded health retry */}await new Promise(r=>setTimeout(r,1000));}
 check(ready,'Storage healthy after restart');
 const complete=await call({...r,action:'run'});check(complete.status===200&&complete.body.state==='completed','retry after real outage completes');
}));

Deno.test('account deletion: crashed worker lease expires and receipt resumes without password',()=>fixture(async(admin,create,receipt)=>{
 const a=await create(),r=receipt();check((await request(a,r)).status===202,'request');
 const digest=[...new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(r.receiptToken)))].map(x=>x.toString(16).padStart(2,'0')).join('');
 check(!(await admin.rpc('account_deletion_claim',{p_id:r.requestId,p_hash:digest,p_lease:crypto.randomUUID()})).error,'simulate crashed worker');
 await sql(`update public.account_deletion_jobs set lease_until=clock_timestamp()-interval '1 second' where id='${r.requestId}';`);
 const complete=await call({...r,action:'run'});check(complete.status===200&&complete.body.state==='completed','expired lease can safely resume');
}));

Deno.test('account deletion: unresolved common Planet geometry stays fail closed',()=>fixture(async(_admin,create,receipt)=>{
 const a=await create(),b=await create(),r=receipt();
 for(const u of [a,b])await sql(`with p as(insert into public.world_publishes(user_id,local_drive_id,started_at,ended_at,distance_meters,world_rules_version) values('${u.id}','synthetic',now(),now(),6000,6) returning id) insert into public.world_validated_roads(publish_id,user_id,provider_id,processing_version,valid_distance_meters,validation_status,direction_key,section_count,geometry) select id,'${u.id}','fixture',3,6000,'validated','east',1,extensions.ST_Multi(extensions.ST_GeomFromText('LINESTRING(0 0,0.06 0)',4326)) from p;`);
 check((await request(a,r)).status===202,'Planet deletion request accepted');
 const state=await call({...r,action:'run'});check(state.status===202&&state.body.state==='blocked_planet','no unverified shared erasure');
 const viewport=await b.client.rpc('read_planet_viewport',{p_south:-0.1,p_north:0.1,p_west:-0.1,p_east:0.1,p_zoom:15});check(!viewport.error&&viewport.data.traces.length===0,'affected component withheld without exposing partial replay');
 const late=await b.client.from('world_publishes').insert({local_drive_id:'synthetic-late',started_at:new Date().toISOString(),ended_at:new Date().toISOString(),distance_meters:6000,world_rules_version:6});
 check(late.error,'new Planet mutations cannot derive from a withdrawing source');
 check(await sql(`select count(*) from public.world_publishes where user_id='${b.id}';`)==='1','B data preserved');
 check(await sql(`select count(*) from auth.users where id='${a.id}';`)==='1','blocked job does not claim Auth deleted');
 check((await a.client.from('world_publishes').select('id')).data?.length===0,'deleting account publications hidden');
}));

Deno.test('account deletion: private server worker recovers a lost device receipt',()=>fixture(async(_admin,create,receipt)=>{
 const a=await create(),b=await create(),r=receipt();
 check((await request(a,r)).status===202,'consented durable request');
 const denied=await call({action:'worker'},a.token);check(denied.status===401,'user JWT cannot authorize server worker');
 check((await b.client.rpc('account_deletion_worker_jobs')).error,'client cannot list recovery hashes');
 const worker=await fetch(`${url}/functions/v1/delete-account`,{method:'POST',headers:{apikey:anon,'content-type':'application/json','x-driveit-deletion-worker':Deno.env.get('PGR6_WORKER_TOKEN')!},body:JSON.stringify({action:'worker'}),signal:AbortSignal.timeout(60000)});
 const result=await worker.json();check(worker.status===200&&result.state==='completed','server recovers without device receipt');
 check(await sql(`select count(*) from auth.users where id='${a.id}';`)==='0','A erased by worker');
 check(await sql(`select count(*) from auth.users where id='${b.id}';`)==='1','B preserved by worker');
}));

Deno.test('account deletion: contradictory Storage ownership cannot erase another subject',()=>fixture(async(admin,create,receipt)=>{
 const a=await create(),b=await create(),r=receipt(),path=`${a.id}/contradiction.json`;
 check(!(await a.client.storage.from('world-drive-sources').upload(path,new Blob(['{}'],{type:'application/json'}))).error,'create isolated contradiction fixture');
 await sql(`update storage.objects set owner_id='${b.id}',owner='${b.id}' where bucket_id='world-drive-sources' and name='${path}';`);
 check((await request(a,r)).status===202,'request accepted');
 const failed=await call({...r,action:'run'});check(failed.status===503,'ambiguous object ownership cannot report completion');
 check(await sql(`select count(*) from auth.users where id='${a.id}';`)==='1','A Auth retained');
 check(!(await admin.storage.from('world-drive-sources').download(path)).error,'contradictory object preserved');
 check(await sql(`select count(*) from public.account_deletion_events where job_id='${r.requestId}' and state='retry_required';`)==='1','sanitized failure audit recorded');
}));

Deno.test('account deletion: Auth audit subject erasure preserves a different actor and target',()=>fixture(async(_admin,create,receipt)=>{
 const a=await create(),b=await create(),r=receipt(),ownLog=crypto.randomUUID(),otherActor=crypto.randomUUID(),otherTarget=crypto.randomUUID();
 await sql(`insert into auth.audit_log_entries(instance_id,id,payload,created_at,ip_address) values
 ('00000000-0000-0000-0000-000000000000','${ownLog}',json_build_object('actor_id','${a.id}','actor_username','${a.email}','action','login'),now(),'192.0.2.1'),
 ('00000000-0000-0000-0000-000000000000','${otherActor}',json_build_object('actor_id','${b.id}','actor_username','${b.email}','action','user_modified','traits',json_build_object('user_id','${a.id}','user_email','${a.email}')),now(),'192.0.2.2'),
 ('00000000-0000-0000-0000-000000000000','${otherTarget}',json_build_object('actor_id','${a.id}','actor_username','${a.email}','action','user_modified','traits',json_build_object('user_id','${b.id}','user_email','${b.email}')),now(),'192.0.2.1');`);
 check((await request(a,r)).status===202,'request');
 const done=await call({...r,action:'run'});check(done.status===200&&done.body.state==='completed','Auth audit erasure confirmed before complete');
 check(await sql(`select count(*) from auth.audit_log_entries where id='${ownLog}';`)==='0','own IP/actor log erased');
 check(await sql(`select (payload->>'actor_id'='${b.id}') and payload->'traits' is null from auth.audit_log_entries where id='${otherActor}';`)==='t','B actor preserved, A traits removed');
 check(await sql(`select payload->>'actor_id' is null and payload->'traits'->>'user_id'='${b.id}' and ip_address='' from auth.audit_log_entries where id='${otherTarget}';`)==='t','B target preserved, A actor/IP removed');
 check(await sql(`select owner_email is null from public.account_deletion_jobs where id='${r.requestId}';`)==='t','transient subject email cleared');
}));

Deno.test('account deletion: unknown Auth audit link blocks completion until reviewed',()=>fixture(async(_admin,create,receipt)=>{
 const a=await create(),r=receipt(),entry=crypto.randomUUID();
 await sql(`insert into auth.audit_log_entries(instance_id,id,payload,created_at,ip_address) values('00000000-0000-0000-0000-000000000000','${entry}',json_build_object('action','synthetic_unknown','custom_reference','${a.id}'),now(),'');`);
 check((await request(a,r)).status===202,'request');
 check((await call({...r,action:'run'})).status===503,'unrecognized identity link is not declared complete');
 check(await sql(`select state from public.account_deletion_jobs where id='${r.requestId}';`)==='purged','durable work remains resumable after Auth removal');
 await sql(`delete from auth.audit_log_entries where id='${entry}';`); // Explicit local review of this run's synthetic unknown field only.
 const done=await call({...r,action:'run'});check(done.status===200&&done.body.state==='completed','receipt recovers after explicit review');
}));

Deno.test('account deletion: ordinary member revokes old topic generation but preserves administrator data',()=>fixture(async(_admin,create,receipt)=>{
 const a=await create(),b=await create(),r=receipt(),group=crypto.randomUUID(),invite=crypto.randomUUID();
 await sql(`begin;insert into public.phase8_groups(id,administrator_id,invite_code,invite_hash) values('${group}','${b.id}','${invite}',extensions.digest('${invite}','sha256'));
 insert into public.phase8_group_memberships(group_id,account_id,role,join_order,color_index) values('${group}','${b.id}','administrator',1,1),('${group}','${a.id}','member',2,2);commit;`);
 const before=Number(await sql(`select generation from public.phase8_groups where id='${group}';`));
 check((await request(a,r)).status===202,'member deletion request accepted');
 check(Number(await sql(`select generation from public.phase8_groups where id='${group}';`))>before,'old cached topic generation invalidated');
 const done=await call({...r,action:'run'});check(done.status===200&&done.body.state==='completed','member account removed');
 check(await sql(`select status from public.phase8_groups where id='${group}';`)==='active','other administrator group preserved');
 check(await sql(`select count(*) from public.phase8_group_memberships where group_id='${group}' and account_id='${b.id}' and state='active';`)==='1','other administrator membership preserved');
}));

// Provider-free canonical fixtures: real Auth/Storage/SQL/Edge, synthetic geometry
// and telemetry only. The published order is B, C, A (A is being withdrawn).
async function planetFixture(run:(admin:SupabaseClient,a:User,b:User,c:User,r:Record<string,string>,rows:PlanetRow[],base:number)=>Promise<void>,partial=false,shiftSurvivors=false,privateC=true){
 await fixture(async(admin,create,receipt)=>{
  const a=await create(),b=await create(),c=await create(),r=receipt(),rows:PlanetRow[]=[];
  const base=Number(await sql('select current_generation from public.world_active_world_state where singleton;'));
  check(await sql('select count(*) from public.world_publishes;')==='0','exclusive empty synthetic Planet fixture');
  try{
   for(const [i,u] of [b,c,a].entries())rows.push(await seedPlanet(u,i<2&&shiftSurvivors ? .02 : i===1&&partial ? .03 : 0,base+i+1,i===2));
   await seedPrivateDrive(b);if(privateC)await seedPrivateDrive(c);
   await run(admin,a,b,c,r,rows,base);
  }finally{
   const ids=rows.map(x=>`'${x.publish}'`).join(',');
   if(ids)await sql(`begin;set local session_replication_role=replica;
   delete from public.world_active_world_traces where source_publish_id in(${ids});
   update public.world_active_world_state set current_generation=${base} where singleton;
   delete from public.world_active_world_generations where generation>${base} and generation<=${base+rows.length+4};commit;`);
  }
 });
}
type PlanetRow={publish:string;road:string;path:string;source:Record<string,unknown>};
async function seedPlanet(u:User,start:number,generation:number,active:boolean,meters=6000):Promise<PlanetRow>{
 const publish=crypto.randomUUID(),road=crypto.randomUUID(),drive=`synthetic-${publish}`,path=`${u.id}/${publish}.json`;
 const route=Array.from({length:601},(_,i)=>({latitude:0,longitude:start+i*.0001*(meters/6000)}));
 const end=start+.06*(meters/6000);
 const source={publish_id:publish,local_drive_id:drive,schema_version:1,telemetry_version:1,drive_score_algorithm_version:1,world_rules_version:6,
 started_at:'2026-01-01T00:00:00Z',ended_at:'2026-01-01T00:10:00Z',recorded_distance_meters:meters,raw_route:route,
 canonical_telemetry:route.map((p,i)=>({...p,timestamp:new Date(Date.parse('2026-01-01T00:00:00Z')+i*1000).toISOString(),speed_mps:meters/600,heading_degrees:90,altitude_meters:0,accuracy_meters:3,distance_from_previous_meters:i?meters/600:0,acceleration_mps2:0}))};
 check(!(await u.client.storage.from('world-drive-sources').upload(path,new Blob([JSON.stringify(source)],{type:'application/json'}))).error,'canonical surviving source upload');
 await sql(`begin;
 insert into public.world_publishes(id,user_id,local_drive_id,started_at,ended_at,distance_meters,world_rules_version,status,processed_at,source_path,source_ready_at,source_schema_version,telemetry_version,drive_score_algorithm_version,raw_route_point_count,telemetry_point_count)
 values('${publish}','${u.id}','${drive}','2026-01-01','2026-01-01 00:10:00+00',${meters},6,'published',now(),'${path}',now(),1,1,1,601,601);
 insert into public.world_validated_roads(id,publish_id,user_id,provider_id,processing_version,valid_distance_meters,validation_status,direction_key,section_count,geometry)
 values('${road}','${publish}','${u.id}','synthetic',6,${meters},'validated','east',1,extensions.ST_Multi(extensions.ST_GeomFromText('LINESTRING(${start} 0,${end} 0)',4326)));
 insert into public.world_validated_road_sections(validated_road_id,section_key,section_order,distance_meters,source_trace_index,source_chunk_index,geometry)
 values('${road}','section-0',0,${meters},0,0,extensions.ST_GeomFromText('LINESTRING(${start} 0,${end} 0)',4326));
 insert into public.world_active_world_generations(generation,base_generation,operation_id,operation_reason,source_publish_id,source_drive_session_id,drive_score_algorithm_version,validated_road_processing_version,valid_distance_meters,trace_count,created_at)
 values(${generation},${generation-1},'world:${drive}:v1','recordProcessing','${publish}','${drive}',1,6,${meters},${active?1:0},now());
 ${active?`insert into public.world_active_world_traces(trace_id,active_from_generation,source_publish_id,source_drive_session_id,validated_road_id,matched_section_id,start_offset_meters,end_offset_meters,direction_key,min_latitude,max_latitude,min_longitude,max_longitude,bounds,processing_version,created_at,updated_at)
 values('trace-${publish}',${generation},'${publish}','${drive}','${road}','section-0',0,${meters},'east',0,0,${start},${end},extensions.ST_MakeEnvelope(${start},0,${end},0,4326),6,now(),now());`:''}
 update public.world_active_world_state set current_generation=${generation} where singleton;commit;`);
 return {publish,road,path,source};
}

Deno.test('Planet withdrawal: A/B/C overlap restores surviving winner without retaining A',()=>planetFixture(async(admin,a,b,c,r,rows,base)=>{
 await sql(`insert into public.world_active_world_traces(trace_id,active_from_generation,active_to_generation,source_publish_id,source_drive_session_id,validated_road_id,matched_section_id,start_offset_meters,end_offset_meters,direction_key,min_latitude,max_latitude,min_longitude,max_longitude,bounds,processing_version,created_at,updated_at)
 select 'synthetic-A-influenced-cut',${base+1},${base+3},source_publish_id,source_drive_session_id,'${rows[0].road}','section-0',1000,2000,'east',0,0,0,.06,extensions.ST_MakeEnvelope(0,0,.06,0,4326),6,now(),now()
 from public.world_active_world_generations where generation=${base+1};`);
 const before=await sql(`select jsonb_agg(to_jsonb(p) order by id)::text from public.world_publishes p where user_id in('${b.id}','${c.id}');`);
 const geometryBefore=await sql(`select jsonb_agg(to_jsonb(r) order by id)::text from public.world_validated_roads r where user_id in('${b.id}','${c.id}');`);
 check((await request(a,r)).status===202,'withdrawal consent');
 const done=await call({...r,action:'run'});check(done.status===200&&done.body.state==='completed','shared withdrawal completes');
 check(await sql(`select count(*) from public.world_active_world_traces where active_to_generation is null and source_publish_id='${rows[0].publish}';`)==='1','equal score restores earlier B source');
 check(await sql(`select count(*) from public.world_active_world_traces where source_publish_id='${rows[2].publish}';`)==='0','all A historical/current traces erased');
 check(await sql(`select count(*) from public.world_active_world_traces where trace_id='synthetic-A-influenced-cut';`)==='0','old survivor boundary influenced by A is not retained');
 check(await sql(`select jsonb_agg(to_jsonb(p) order by id)::text from public.world_publishes p where user_id in('${b.id}','${c.id}');`)===before,'B/C publish metadata byte equivalent');
 check(await sql(`select jsonb_agg(to_jsonb(r) order by id)::text from public.world_validated_roads r where user_id in('${b.id}','${c.id}');`)===geometryBefore,'B/C canonical road geometry unchanged');
 for(const [i,u] of [[0,b],[1,c]] as const){
  check(!(await admin.storage.from('world-drive-sources').download(rows[i].path)).error,'surviving source preserved');
  check(await sql(`select count(*) from public.phase8_drive_manifests where owner_id='${u.id}';`)==='1','surviving private history preserved');
 }
 check((await call({...r,action:'run'})).body.state==='completed','response-lost retry is idempotent');
 const page=await b.client.rpc('read_planet_viewport',{p_south:-.01,p_north:.01,p_west:-.01,p_east:.1,p_zoom:15});
 check(!page.error&&page.data.traces.length>0,'Planet readable after durable withdrawal');
}));

Deno.test('Planet withdrawal: partial overlap retains B and C unique intervals',()=>planetFixture(async(_admin,a,_b,_c,r,rows)=>{
 check((await request(a,r)).status===202,'request');
 const done=await call({...r,action:'run'});
 check(done.status===200&&done.body.state==='completed',`partial overlap completes: HTTP ${done.status}, ${done.body.state??done.body.error}`);
 for(const source of rows.slice(0,2))check(Number(await sql(`select count(*) from public.world_active_world_traces where active_to_generation is null and source_publish_id='${source.publish}';`))>0,'both surviving sources own valid intervals');
 check(await sql(`select count(*) from public.world_validated_road_sections where validated_road_id='${rows[2].road}';`)==='0','A canonical section geometry erased');
},true));

Deno.test('Planet withdrawal: A-only geometry has no invented replacement',()=>planetFixture(async(_admin,a,_b,_c,r,rows)=>{
 check((await request(a,r)).status===202,'request');
 const done=await call({...r,action:'run'});check(done.status===200&&done.body.state==='completed','withdrawal completes');
 check(await sql(`select count(*) from public.world_active_world_traces where active_to_generation is null and min_longitude<.02;`)==='0','A-only physical tail removed, not anonymized');
 check(await sql(`select count(*) from public.world_active_world_traces where source_publish_id='${rows[2].publish}';`)==='0','A history erased as well');
},false,true));

Deno.test('Planet withdrawal: missing surviving GPS fails closed, restored source retries',()=>planetFixture(async(admin,a,b,_c,r,rows)=>{
 check(!(await admin.storage.from('world-drive-sources').remove([rows[0].path])).error,'local partial source failure');
 check((await request(a,r)).status===202,'request');
 const blocked=await call({...r,action:'run'});check(blocked.status===202&&blocked.body.state==='blocked_planet','no invented source or false completion');
 check(await sql(`select count(*) from auth.users where id='${a.id}';`)==='1','Auth retained until recovery');
 check(!(await b.client.storage.from('world-drive-sources').upload(rows[0].path,new Blob([JSON.stringify(rows[0].source)],{type:'application/json'}))).error,'owner restores its exact synthetic source');
 const recovered=await call({...r,action:'run'});check(recovered.status===200&&recovered.body.state==='completed','same receipt safely retries');
}));

Deno.test('Planet withdrawal: stale snapshot, invalid plan rollback and lost commit response',()=>planetFixture(async(admin,a,_b,_c,r,rows,base)=>{
 check((await request(a,r)).status===202,'request');
 const lease=crypto.randomUUID();
 const digest=[...new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(r.receiptToken)))].map(x=>x.toString(16).padStart(2,'0')).join('');
 check(!(await admin.rpc('account_deletion_claim',{p_id:r.requestId,p_hash:digest,p_lease:lease})).error,'lease');
 const args={p_id:r.requestId,p_lease:lease};
 const context=(await admin.rpc('account_deletion_planet_context',args)).data as RebuildContext;
 const plan=await rebuildPlanet(context,{metadata:async(ids)=>context.sources.filter(s=>ids.includes(s.source.id)).map(s=>s.source),download:async(path)=>{const s=await admin.storage.from('world-drive-sources').download(path);check(!s.error,'test source');return JSON.parse(await s.data!.text());}});
 const commit={...args,p_fingerprint:context.fingerprint,p_traces:plan};
 check((await a.client.rpc('account_deletion_planet_commit',commit)).error,'client cannot rewrite Planet');
 check((await admin.rpc('account_deletion_planet_commit',{...commit,p_traces:plan.map(t=>({...t,sourcePublishId:rows[2].publish}))})).error,'forged A provenance refused');
 check((await admin.rpc('account_deletion_planet_commit',{...commit,p_traces:plan.map(t=>({...t,createdAt:'not-a-date'}))})).error,'failure after generation insert rolls back');
 check(await sql('select current_generation from public.world_active_world_state where singleton;')===String(base+3),'invalid transaction left pointer unchanged');
 check(await sql(`select count(*) from public.world_active_world_generations where generation=${base+4};`)==='0','partial replacement generation rolled back');
 check(await sql(`select count(*) from public.world_active_world_traces where source_publish_id='${rows[2].publish}' and active_to_generation is null;`)==='1','partial retirement rolled back');
 // Change only this synthetic object's version; old content-plan proof must fail.
 await sql(`update storage.objects set updated_at=clock_timestamp() where bucket_id='world-drive-sources' and name='${rows[0].path}';`);
 check((await admin.rpc('account_deletion_planet_commit',commit)).error,'stale Storage version proof refused');
 const fresh=(await admin.rpc('account_deletion_planet_context',args)).data as RebuildContext;
 const result=await admin.rpc('account_deletion_planet_commit',{...commit,p_fingerprint:fresh.fingerprint});check(!result.error&&result.data==='ready',`atomic rebuild: ${result.error?.code??''} ${result.error?.message??''}`);
 check(!(await admin.rpc('account_deletion_planet_commit',{...commit,p_fingerprint:fresh.fingerprint})).error,'lost reply commit retry returns ready');
 check(await sql('select current_generation from public.world_active_world_state where singleton;')===String(base+4),'replay commit applied once');
 check(!(await admin.rpc('account_deletion_release',args)).error,'release simulated worker');
 const done=await call({...r,action:'run'});check(done.status===200&&done.body.state==='completed','Edge resumes committed rebuild and finishes A');
}));

Deno.test('Planet withdrawal: contradictory road and publish ownership fails closed',()=>planetFixture(async(_admin,a,b,_c,r,rows)=>{
 await sql(`update public.world_validated_roads set user_id='${b.id}' where id='${rows[2].road}';`);
 check((await request(a,r)).status===202,'request accepted but ownership not assumed');
 const result=await call({...r,action:'run'});check(result.status===202&&result.body.state==='blocked_planet','ambiguous withdrawing source is not purged');
 check(await sql(`select count(*) from auth.users where id='${a.id}';`)==='1','Auth not removed with ambiguous provenance');
 check(await sql(`select count(*) from public.world_validated_roads where id='${rows[2].road}';`)==='1','contradictory geometry retained for review');
 check(await sql(`select count(*) from public.phase8_drive_manifests where owner_id='${b.id}';`)==='1','B private data preserved');
}));

async function worker(action='worker',jobId?:string){
 const response=await fetch(`${url}/functions/v1/delete-account`,{method:'POST',headers:{apikey:anon,'content-type':'application/json','x-driveit-deletion-worker':Deno.env.get('PGR6_WORKER_TOKEN')!},body:JSON.stringify({action,jobId}),signal:AbortSignal.timeout(60000)});
 return {status:response.status,body:await response.json()};
}
async function restartLocalEdge(){
 await target();
 // Docker restart alone does not restore the experimental stack's routes.
 // The guarded runner uses the documented stack-id restart and verifies PGDATA.
 const restarted=await new Deno.Command('pwsh',{args:['-NoProfile','-File','tool/run_pgr6a.ps1','-RestartLocal','-PrepareOnly'],stdout:'piped',stderr:'piped'}).output();
 check(restarted.success,'restart only pinned local stack without deleting state');
 for(let i=0;i<10;i++){
  try{if((await worker('worker_status')).status===200){await target();return;}}catch{/* bounded on-demand startup */}
  await new Promise(resolve=>setTimeout(resolve,1000));
 }
 throw Error('isolated Edge runtime did not recover');
}

Deno.test('P-GR6C worker: 33 survivors over 500km checkpoint, invalidate, crash and resume',()=>planetFixture(async(admin,a,b,c,r,rows,base)=>{
 for(let i=0;i<31;i++)rows.push(await seedPlanet(b,0,base+4+i,false,18000));
 const initial=base+34;
 await sql(`update public.world_active_world_generations set trace_count=1 where generation=${initial};`);
 check((await request(a,r)).status===202,'durable consent');
 const initialWorkers=await Promise.all([worker(),worker()]);
 check(initialWorkers.filter(x=>x.body.state==='pending').length===1&&initialWorkers.filter(x=>x.body.state==='idle').length===1,'same job has one worker and no duplicate computation');
 check(await sql(`select next_index from public.account_deletion_replays where job_id='${r.requestId}';`)==='2','prefix checkpoint durable');
 check((await admin.rpc('account_deletion_replay_finish',{p_id:r.requestId,p_lease:crypto.randomUUID()})).error,'invalid lease cannot publish partial index');
 check((await b.client.from('account_deletion_replays').select('*')).error,'no client access to staged geometry');
 check(await sql('select current_generation from public.world_active_world_state where singleton;')===String(initial),'partial prefix not public');
 await sql(`update storage.objects set updated_at=clock_timestamp() where bucket_id='world-drive-sources' and name='${rows[0].path}';`);
 check((await worker()).body.state==='pending','changed input restarts safely');
 check(await sql(`select next_index from public.account_deletion_replays where job_id='${r.requestId}';`)==='2','stale checkpoint reset before new prefix');
 check(await sql(`select count(*) from public.account_deletion_events where job_id='${r.requestId}' and state='replay_invalidated';`)==='1','input change observable without route logs');
 const hash=[...new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(r.receiptToken)))].map(x=>x.toString(16).padStart(2,'0')).join('');
 const deadLease=crypto.randomUUID();check(!(await admin.rpc('account_deletion_claim',{p_id:r.requestId,p_hash:hash,p_lease:deadLease})).error,'simulate worker disappearance with claimed lease');
 check((await admin.rpc('account_deletion_replay_finish',{p_id:r.requestId,p_lease:deadLease})).error,'valid lease still cannot publish incomplete prefix');
 await sql(`update public.account_deletion_jobs set lease_until=clock_timestamp()-interval '1 second',next_attempt_at=clock_timestamp()-interval '1 second' where id='${r.requestId}';`);
 await restartLocalEdge();
 let result=await worker(),calls=3;
 while(result.body.state==='pending'&&calls++<25){
  await sql(`update public.account_deletion_jobs set next_attempt_at=clock_timestamp()-interval '1 second' where id='${r.requestId}';`); // Synthetic scheduler clock tick.
  result=await worker();
 }
 check(result.status===200&&result.body.state==='completed','new invocations resume and finish 33-source replay');
 check(calls>16&&calls<26,'bounded number of invocations');
 check(await sql(`select count(*) from public.account_deletion_replays where job_id='${r.requestId}';`)==='0','sensitive checkpoint erased at completion');
 check(await sql(`select count(*) from auth.users where id='${a.id}';`)==='0','A Auth removed last');
 check(await sql(`select count(*) from public.world_publishes where user_id in('${b.id}','${c.id}');`)==='33','all surviving publishes preserved');
 check(await sql(`select count(*) from public.phase8_drive_manifests where owner_id='${b.id}';`)==='1','B private history preserved');
}));

Deno.test('P-GR6C worker: concurrent A/B requests isolate leases and preserve C',()=>planetFixture(async(_admin,a,b,c,r,_rows)=>{
 const other={requestId:crypto.randomUUID(),receiptToken:[...crypto.getRandomValues(new Uint8Array(32))].map(x=>x.toString(16).padStart(2,'0')).join('')};
 try{
  check((await request(a,r)).status===202,'A consent');check((await request(b,other)).status===202,'B consent');
  const results=await Promise.all([worker(),worker()]);check(results.every(x=>[200,202,503].includes(x.status)),'concurrent workers terminate safely');
  for(let i=0;i<6;i++){
   if(await sql(`select count(*) from auth.users where id in('${a.id}','${b.id}');`)==='0')break;
   await worker('worker_retry',r.requestId);await worker('worker_retry',other.requestId);await worker();
  }
  check(await sql(`select count(*) from auth.users where id in('${a.id}','${b.id}');`)==='0','both consented jobs finish');
  check(await sql(`select count(*) from auth.users where id='${c.id}';`)==='1','C Auth preserved');
  check(await sql(`select count(*) from public.world_active_world_traces t join public.world_publishes p on p.id=t.source_publish_id where p.user_id='${c.id}' and active_to_generation is null;`)==='1','C is sole valid remaining owner');
 }finally{await sql(`delete from public.account_deletion_replays where job_id='${other.requestId}';delete from public.account_deletion_events where job_id='${other.requestId}';delete from public.account_deletion_jobs where id='${other.requestId}';`);}
}));

Deno.test('P-GR6C worker: retry ceiling, private status and explicit review recovery',()=>fixture(async(admin,create,receipt)=>{
 const a=await create(),b=await create(),r=receipt(),path=`${a.id}/injected-conflict.json`;
 check(!(await a.client.storage.from('world-drive-sources').upload(path,new Blob(['{}']))).error,'isolated malformed object');
 await sql(`update storage.objects set owner_id='${b.id}',owner='${b.id}' where bucket_id='world-drive-sources' and name='${path}';`);
 check((await request(a,r)).status===202,'consent');
 check((await worker()).status===503,'real inconsistent object causes retry, never completed');
 check((await worker()).body.state==='idle','backoff prevents immediate automatic retry');
 const digest=[...new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(r.receiptToken)))].map(x=>x.toString(16).padStart(2,'0')).join('');
 for(let i=0;i<7;i++){
  const lease=crypto.randomUUID();check(!(await admin.rpc('account_deletion_claim',{p_id:r.requestId,p_hash:digest,p_lease:lease})).error,'synthetic failure lease');
  check(!(await admin.rpc('account_deletion_failed',{p_id:r.requestId,p_lease:lease})).error,'bounded failure callback');
  await admin.rpc('account_deletion_release',{p_id:r.requestId,p_lease:lease});
 }
 await sql(`update public.account_deletion_jobs set next_attempt_at=clock_timestamp()-interval '1 second' where id='${r.requestId}';`);
 check((await worker()).body.state==='idle','eight failures require review even when due');
 const status=await worker('worker_status'),serialized=JSON.stringify(status.body);
 check(status.status===200&&status.body.review===1,'operator can observe review queue');
 for(const secret of [a.id,b.id,a.email,b.email,r.receiptToken,path])check(!serialized.includes(secret),'status excludes identity, GPS path and receipt');
 check((await call({action:'worker_retry',jobId:r.requestId},b.token)).status===401,'JWT cannot authorize review retry');
 check((await b.client.rpc('account_deletion_worker_status')).error,'RPC not public');
 // Explicit local review removes only the injected malformed synthetic object.
 check(!(await admin.storage.from('world-drive-sources').remove([path])).error,'local fixture repair');
 check((await worker('worker_retry',r.requestId)).body.state==='requeued','authorized operator requeue');
 check((await worker()).body.state==='completed','same durable job recovers');
 check(await sql(`select count(*) from auth.users where id='${b.id}';`)==='1','B never deleted');
}));

Deno.test('P-GR6C worker: failed local component does not hide unrelated committed Planet',()=>planetFixture(async(admin,a,b,c,r,rows,base)=>{
 const far=await seedPlanet(c,.5,base+4,true);rows.push(far);
 check(!(await admin.storage.from('world-drive-sources').remove([rows[0].path])).error,'missing near source');
 check((await request(a,r)).status===202,'consent');check((await worker()).body.state==='blocked_planet','missing input awaits review');
 const near=await b.client.rpc('read_planet_viewport',{p_south:-.01,p_north:.01,p_west:-.01,p_east:.1,p_zoom:15});
 const distant=await b.client.rpc('read_planet_viewport',{p_south:-.01,p_north:.01,p_west:.4,p_east:.7,p_zoom:15});
 check(!near.error&&near.data.traces.length===0,'affected component hidden');check(!distant.error&&distant.data.traces.length===1,'unrelated committed trace remains available');
 const hiddenDetail=await admin.rpc('read_planet_trace_detail_context',{p_trace_id:await sql(`select md5('trace-${rows[2].publish}');`)});
 const visibleDetail=await admin.rpc('read_planet_trace_detail_context',{p_trace_id:await sql(`select md5('trace-${far.publish}');`)});
 check(!hiddenDetail.error&&hiddenDetail.data===null,'old related detail/cache cannot disclose withdrawn source');check(!visibleDetail.error&&visibleDetail.data,'unaffected detail still available');
 const publish=await b.client.from('world_publishes').insert({local_drive_id:`synthetic-${crypto.randomUUID()}`,started_at:new Date().toISOString(),ended_at:new Date().toISOString(),distance_meters:6000,world_rules_version:6});
 check(publish.error,'new publication cannot invalidate a pending withdrawal');
 const cloud=await fetch(`${url}/functions/v1/phase8-drive-download`,{method:'POST',headers:{apikey:anon,authorization:`Bearer ${c.token}`,'content-type':'application/json'},body:JSON.stringify({action:'begin'}),signal:AbortSignal.timeout(30000)});
 const feed=await cloud.json();check(cloud.status===200&&feed.ok&&feed.changes.length===0,'unrelated authenticated personal cloud Edge remains available');
 check(await sql(`select count(*) from public.phase8_drive_manifests where owner_id='${b.id}';`)==='1','B existing private history preserved');
},false,false,false));

Deno.test('P-GR6C worker: repeated expired leases stop for review and recover',()=>fixture(async(admin,create,receipt)=>{
 const a=await create(),b=await create(),r=receipt();check((await request(a,r)).status===202,'consent');
 check(!(await admin.rpc('account_deletion_worker_claim',{p_lease:crypto.randomUUID()})).error,'first worker claim');
 for(let i=0;i<8;i++){
  await sql(`update public.account_deletion_jobs set lease_until=clock_timestamp()-interval '1 second',next_attempt_at=clock_timestamp()-interval '1 second' where id='${r.requestId}';`);
  const claimed=await admin.rpc('account_deletion_worker_claim',{p_lease:crypto.randomUUID()});check(!claimed.error,'expired lease recovery transaction');
  if(i===7)check(claimed.data.state==='idle','repeated crashes stop automatically');
 }
 const status=await worker('worker_status');check(status.body.review===1&&status.body.jobs[0].crashes===8,'stalled job observable');
 check(await sql(`select count(*) from auth.users where id='${a.id}';`)==='1','crash is never reported deleted');
 await worker('worker_retry',r.requestId);check((await worker()).body.state==='completed','review retry retains consent and finishes');
 check(await sql(`select count(*) from auth.users where id='${b.id}';`)==='1','other account remains');
}));

Deno.test('P-GR6C worker: oversized metadata retains review and global read fencing',()=>planetFixture(async(admin,a,b,_c,r,_rows)=>{
 await sql(`begin;
 insert into public.world_publishes(user_id,local_drive_id,started_at,ended_at,distance_meters,world_rules_version)
 select '${b.id}','synthetic-oversize-'||n,now(),now(),6000,6 from generate_series(1,127)n;
 insert into public.world_validated_roads(publish_id,user_id,provider_id,processing_version,valid_distance_meters,validation_status,direction_key,section_count,geometry)
 select id,user_id,'synthetic',6,6000,'validated','east',1,extensions.ST_Multi(extensions.ST_GeomFromText('LINESTRING(0 0,.06 0)',4326)) from public.world_publishes where user_id='${b.id}' and local_drive_id like 'synthetic-oversize-%';commit;`);
 check((await request(a,r)).status===202,'consent');check((await worker()).body.state==='blocked_planet','metadata budget cannot be bypassed');
 const hidden=await admin.rpc('account_deletion_planet_hidden_roads');check(!hidden.error&&hidden.data===null,'unknown component proof is fail closed');
 const viewport=await b.client.rpc('read_planet_viewport',{p_south:-.01,p_north:.01,p_west:-.01,p_east:.1,p_zoom:15});
 check(!viewport.error&&viewport.data.traces.length===0,'oversize fallback exposes no affected geometry');
 check(await sql(`select count(*) from auth.users where id='${a.id}';`)==='1','not falsely completed');
}));

Deno.test('P-GR6C worker: private-only failure cannot block a large unrelated Planet',()=>fixture(async(admin,create,receipt)=>{
 const a=await create(),b=await create(),r=receipt();
 const base=Number(await sql('select current_generation from public.world_active_world_state where singleton;'));
 const row=await seedPlanet(b,.5,base+1,true),path=`${a.id}/private-conflict.json`;
 try{
  await sql(`begin;insert into public.world_publishes(user_id,local_drive_id,started_at,ended_at,distance_meters,world_rules_version)
  select '${b.id}','synthetic-private-world-'||n,now(),now(),6000,6 from generate_series(1,128)n;
  insert into public.world_validated_roads(publish_id,user_id,provider_id,processing_version,valid_distance_meters,validation_status,direction_key,section_count,geometry)
  select id,user_id,'synthetic',6,6000,'validated','east',1,extensions.ST_Multi(extensions.ST_GeomFromText('LINESTRING(0 0,.06 0)',4326)) from public.world_publishes where user_id='${b.id}' and local_drive_id like 'synthetic-private-world-%';commit;`);
  check(!(await a.client.storage.from('world-drive-sources').upload(path,new Blob(['{}']))).error,'private failure fixture');
  await sql(`update storage.objects set owner_id='${b.id}',owner='${b.id}' where bucket_id='world-drive-sources' and name='${path}';`);
  check((await request(a,r)).status===202,'private-only consent');check((await worker()).status===503,'private Storage failure waits');
  const hidden=await admin.rpc('account_deletion_planet_hidden_roads');check(!hidden.error&&Array.isArray(hidden.data)&&hidden.data.length===0,'no invented Planet influence');
  const viewport=await b.client.rpc('read_planet_viewport',{p_south:-.01,p_north:.01,p_west:.4,p_east:.7,p_zoom:15});
  check(!viewport.error&&viewport.data.traces.length===1,'large unrelated committed Planet remains visible');
 }finally{
  await sql(`begin;set local session_replication_role=replica;delete from public.world_active_world_traces where source_publish_id='${row.publish}';update public.world_active_world_state set current_generation=${base} where singleton;delete from public.world_active_world_generations where generation=${base+1} and source_publish_id='${row.publish}';commit;`);
 }
}));

Deno.test('account deletion: final synthetic dataset is clean and gates remain closed',async()=>{
 await target();
 for(const table of ['account_deletion_jobs','account_deletion_events','account_deletion_replays','profiles','world_publishes','world_validated_roads','world_active_world_traces','phase8_groups','phase8_group_memberships','phase8_drive_manifests','phase8_drive_upload_intents']){
  check(await sql(`select count(*) from public.${table};`)==='0','synthetic application rows cleaned');
 }
 check(await sql('select count(*) from auth.users;')==='0','synthetic Auth cleaned');
 check(await sql('select count(*) from storage.objects;')==='0','synthetic Storage cleaned');
});
