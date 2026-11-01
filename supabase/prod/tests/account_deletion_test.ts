import {createClient,type SupabaseClient} from 'npm:@supabase/supabase-js@2.117.2';
function check(v:unknown,m:string):asserts v {if(!v)throw Error(m);}
const url=Deno.env.get('PGR6_LOCAL_URL')??'',container=Deno.env.get('PGR6_CONTAINER')??'';
const anon=Deno.env.get('PGR6_ANON')??'',service=Deno.env.get('PGR6_SERVICE')??'';
async function sql(q:string){
 check(/^supabase-pgr6a-[0-9a-f]{10}-pgr6a-[0-9a-f]{10}-database-[0-9a-f]+$/.test(container),'pinned disposable container');
 const r=await new Deno.Command('docker',{args:['exec',container,'psql','-U','postgres','-d','postgres','-X','-At','-v','ON_ERROR_STOP=1','-c',q],stdout:'piped',stderr:'piped'}).output();
 check(r.success,'local test SQL failed');return new TextDecoder().decode(r.stdout).trim();
}
async function target(){
 check(/^http:\/\/127\.0\.0\.1:\d+$/.test(url),'loopback only');
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
  for(const id of jobs)await sql(`begin;delete from public.account_deletion_events where job_id='${id}';delete from public.account_deletion_jobs where id='${id}';commit;`);
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
 const viewport=await b.client.rpc('read_planet_viewport',{p_south:-0.1,p_north:0.1,p_west:-0.1,p_east:0.1,p_zoom:15});check(viewport.error,'ambiguous public Planet output closed');
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

Deno.test('account deletion: final synthetic dataset is clean and gates remain closed',async()=>{
 await target();
 for(const table of ['account_deletion_jobs','account_deletion_events','profiles','world_publishes','world_validated_roads','world_active_world_traces','phase8_groups','phase8_group_memberships','phase8_drive_manifests','phase8_drive_upload_intents']){
  check(await sql(`select count(*) from public.${table};`)==='0','synthetic application rows cleaned');
 }
 check(await sql('select count(*) from auth.users;')==='0','synthetic Auth cleaned');
 check(await sql('select count(*) from storage.objects;')==='0','synthetic Storage cleaned');
});
