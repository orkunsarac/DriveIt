import {createClient} from 'npm:@supabase/supabase-js@2.117.2';
import {canonicalJson,canonicalSha256,expectedDriveUpsertKey,ownerScope,sha256Hex} from '../supabase/phase8-dev/supabase/functions/_shared/common.ts';
import {cloudFixture} from '../supabase/prod/tests/hosted_drive_fixture.ts';

const url=Deno.env.get('R6B4_URL')??'',anon=Deno.env.get('R6B4_ANON')??'',service=Deno.env.get('R6B4_SERVICE')??'';
const container=Deno.env.get('R6B4_CONTAINER')??'',system=Deno.env.get('R6B4_SYSTEM')??'';
const stack=Deno.env.get('R6B4_STACK')??'';
function check(value:unknown,label:string):asserts value {if(!value)throw Error(label);}
check(/^http:\/\/127\.0\.0\.1:\d+$/.test(url),'local URL required');
check(/^pgr6a-[0-9a-f]{10}$/.test(stack)&&container.startsWith(`supabase-${stack}-${stack}-database-`),'isolated stack required');
check(anon.length>0&&service.length>0&&/^\d+$/.test(system),'local test configuration missing');
const options={auth:{persistSession:false,autoRefreshToken:false}};
const admin=createClient(url,service,options);
const sha=async(value:string)=>sha256Hex(new TextEncoder().encode(value));
const receipt=()=>[...crypto.getRandomValues(new Uint8Array(32))].map(x=>x.toString(16).padStart(2,'0')).join('');
type Person={email:string;password:string;id?:string;requestId:string;receiptToken:string;deleted:boolean};
const marker=crypto.randomUUID();
const people:Person[]=['a','b'].map(label=>({email:`r6b4-${label}-${marker}@example.invalid`,password:`Synthetic-${crypto.randomUUID()}!`,requestId:crypto.randomUUID(),receiptToken:receipt(),deleted:false}));
let state:{stack:string;marker:string;stage:string;people:Person[]}={stack,marker,stage:'planned',people};
async function journal(){
 const proc=new Deno.Command('pwsh',{args:['-NoProfile','-File','tool/r6b4_private_journal.ps1'],stdin:'piped',stdout:'piped',stderr:'piped'}).spawn();
 const writer=proc.stdin.getWriter();await writer.write(new TextEncoder().encode(JSON.stringify(state)));await writer.close();
 const result=await proc.output();check(result.success,'encrypted journal write failed');
}
async function readJournal(){
 const result=await new Deno.Command('pwsh',{args:['-NoProfile','-File','tool/r6b4_private_journal.ps1','-Read'],stdout:'piped',stderr:'piped'}).output();
 check(result.success,'encrypted journal read failed');
 const saved=JSON.parse(new TextDecoder().decode(result.stdout)) as typeof state;
 check(saved.stack===stack&&saved.people.length===2&&saved.people.every(p=>p.email.endsWith('@example.invalid')&&!!p.id&&/^[0-9a-f-]{36}$/.test(p.id)),'journal target mismatch');return saved;
}
async function step(name:string){state.stage=name;await journal();console.log(`PASS: ${name}`);}
async function sql(query:string){
 const result=await new Deno.Command('docker',{args:['exec',container,'psql','-U','postgres','-d','postgres','-X','-q','-At','-v','ON_ERROR_STOP=1','-c',query],stdout:'piped',stderr:'piped'}).output();
 check(result.success,'isolated catalog/owner query failed');return new TextDecoder().decode(result.stdout).trim();
}
async function invoke(name:string,token:string|null,body:unknown){
 const r=await fetch(`${url}/functions/v1/${name}`,{method:'POST',headers:{apikey:anon,'content-type':'application/json',...(token?{authorization:`Bearer ${token}`}:{})},body:JSON.stringify(body),signal:AbortSignal.timeout(60000)});
 const response=await r.json();return {status:r.status,body:response};
}
function request(p:Person,token:string,password=p.password,expectedOwner=p.id){return invoke('delete-account',token,{action:'request',requestId:p.requestId,receiptToken:p.receiptToken,expectedOwner,password,confirm:'DELETE_MY_ACCOUNT'});}
function run(p:Person,token=p.receiptToken){return invoke('delete-account',null,{action:'run',requestId:p.requestId,receiptToken:token});}
async function login(p:Person){const client=createClient(url,anon,options);const result=await client.auth.signInWithPassword({email:p.email,password:p.password});check(!result.error&&result.data.session,'synthetic login failed');return {client,token:result.data.session.access_token};}
async function drive(p:Person,session:Awaited<ReturnType<typeof login>>){
 check(p.id,'synthetic owner missing');const sourceIdentity=crypto.randomUUID(),driveId='r6b4-'+crypto.randomUUID();const payload=cloudFixture(p.id,sourceIdentity,driveId);
 const mutation={version:2,kind:'driveUpsert',ownerId:p.id,ownerScope:ownerScope(p.id),sourceIdentity,idempotencyKey:await expectedDriveUpsertKey(p.id,sourceIdentity),payloadFingerprint:await canonicalSha256(payload),payload};
 const bytes=new TextEncoder().encode(canonicalJson(mutation));const claim={ownerId:p.id,ownerScope:mutation.ownerScope,sourceIdentity,idempotencyKey:mutation.idempotencyKey,contractVersion:2,payloadFingerprint:mutation.payloadFingerprint,objectSha256:await sha256Hex(bytes),objectBytes:bytes.length};
 const begin=await invoke('phase8-drive-begin',session.token,claim);check(begin.status===200&&begin.body.state==='staging',`drive begin status ${begin.status}`);
 const path=`${p.id}/${begin.body.intentId}/envelope.json`;const uploaded=await session.client.storage.from('phase8-drive-staging').upload(path,bytes,{contentType:'application/json'});check(!uploaded.error,'staged Storage upload failed');
 const finalized=await invoke('phase8-drive-finalize',session.token,{intentId:begin.body.intentId});check(finalized.status===200,`drive finalize status ${finalized.status} error ${finalized.body.error??'none'}`);
 check(await sql(`select count(*) from public.phase8_drive_manifests where owner_id='${p.id}' and source_identity='${sourceIdentity}'`)==='1','finalized manifest missing');return {path,sourceIdentity};
}
async function privateRows(owner:string){
 check(/^[0-9a-f-]{36}$/.test(owner),'invalid synthetic owner');
 const tables=['phase8_drive_upload_intents','phase8_drive_owner_sequences','phase8_drive_manifests','phase8_drive_changes','phase8_drive_snapshots','phase8_drive_leases','phase8_drive_tombstones','phase8_drive_cancellations'];
 return Number(await sql('select '+tables.map(t=>`(select count(*) from public.${t} where owner_id=\'${owner}\')`).join('+')));
}
async function tombstone(p:Person,session:Awaited<ReturnType<typeof login>>,sourceIdentity:string){
 check(p.id,'owner missing');const observed=await invoke('phase8-drive-delete',session.token,{action:'observe',sourceIdentity});check(observed.status===200,'tombstone observation failed');
 const deletionId=crypto.randomUUID(),payload={deletionId,deletedAt:new Date().toISOString(),causalVersion:1,observedRemoteSequence:observed.body.change_sequence,observedPayloadFingerprint:observed.body.payload_fingerprint};
 const mutation={version:2,kind:'driveTombstone',ownerId:p.id,ownerScope:ownerScope(p.id),sourceIdentity,payload,payloadFingerprint:await canonicalSha256(payload),idempotencyKey:`owner-sync-v2:${await sha(`${ownerScope(p.id)}|${p.id}|driveTombstone|${deletionId}`)}`};
 const result=await invoke('phase8-drive-delete',session.token,{mutation});check(result.status===200,`tombstone status ${result.status}`);
 check(await sql(`select count(*) from public.phase8_drive_tombstones where owner_id='${p.id}' and source_identity='${sourceIdentity}'`)==='1','tombstone missing');
}
async function present(p:Person){check(p.id,'owner id missing');const result=await admin.auth.admin.getUserById(p.id);return !result.error&&!!result.data.user;}
async function finish(p:Person){
 for(let i=0;i<12;i++){const result=await run(p);if(result.status===200&&result.body.state==='completed'){p.deleted=true;await journal();return;}check(result.status===202&&result.body.state==='pending',`deletion run status ${result.status} state ${result.body.state??result.body.error??'none'}`);}
 throw Error('deletion did not complete; encrypted receipt retained');
}

Deno.test({name:'isolated real Auth, Storage, finalized drive and receipt deletion without bypass',sanitizeOps:false,sanitizeResources:false,fn:async()=>{
 check(await sql('select system_identifier from pg_control_system()')===system,'physical cluster identity mismatch');
 const settings=await fetch(`${url}/auth/v1/settings`,{headers:{apikey:anon}});check(settings.ok&&(await settings.json()).disable_signup===true,'signup must remain closed');
 if(Deno.env.get('R6B4_RESUME')==='true'){
  state=await readJournal();const [a,b]=state.people;check(a.id&&b.id&&a.deleted&&!b.deleted,'unexpected recovery stage');
  check(!(await present(a))&&await present(b),'recovery Auth state incorrect');
  check(await sql(`select count(*) from public.phase8_drive_manifests where owner_id='${a.id}'`)==='0','A manifest remains');
  const path=await sql(`select object_path from public.phase8_drive_manifests where owner_id='${b.id}'`);check(path.startsWith(`${b.id}/`),'B manifest path invalid');
  check(!(await admin.storage.from('phase8-drive-staging').download(path)).error,'B stored object missing');
  const sb=await login(b);const feed=await invoke('phase8-drive-download',sb.token,{action:'begin'});check(feed.status===200&&feed.body.changes.some((c:{mutation:{ownerId:string}})=>c.mutation.ownerId===b.id),'B official download failed');
  const accepted=await request(b,sb.token);check(accepted.status===202,`B official cleanup request status ${accepted.status}`);await finish(b);check(!(await present(b)),'B Auth cleanup failed');await step('recovered A/B state and B official cleanup');return;
 }
 await journal();
 for(const p of people){const result=await admin.auth.admin.createUser({email:p.email,password:p.password,email_confirm:true,user_metadata:{r6b4_marker:marker}});check(!result.error&&result.data.user,'synthetic account creation failed');p.id=result.data.user.id;await journal();}
 const [a,b]=people;check(a.id&&b.id,'account ids missing');
 for(const bucket of ['phase8-drive-staging','world-drive-sources']){const existing=await admin.storage.getBucket(bucket);if(existing.error){const made=await admin.storage.createBucket(bucket,{public:false});check(!made.error,'private test bucket creation failed');}}
 const sa=await login(a),sb=await login(b);const driveA=await drive(a,sa),driveB=await drive(b,sb),secondA=await drive(a,sa);
 const deviceId=crypto.randomUUID(),sessionId=crypto.randomUUID();
 const lease=await invoke('phase8-drive-lease',sb.token,{action:'acquire',sourceIdentity:driveB.sourceIdentity,deviceId,sessionId});check(lease.status===200&&lease.body.lease.fencing_token>=1,`lease acquire status ${lease.status}`);
 const heartbeat=await invoke('phase8-drive-lease',sb.token,{action:'heartbeat',sourceIdentity:driveB.sourceIdentity,deviceId,sessionId,fencingToken:lease.body.lease.fencing_token});check(heartbeat.status===200,'lease heartbeat failed');
 await tombstone(a,sa,secondA.sourceIdentity);
 const group=await sb.client.rpc('phase8_group_command',{p_action:'create'});check(group.error?.message==='group_feature_disabled','Group Drive server gate not closed');
 const extra=`${a.id}/${crypto.randomUUID()}.json`;check(!(await sa.client.storage.from('world-drive-sources').upload(extra,new Blob(['{}'],{type:'application/json'}))).error,'second bucket upload failed');
 check(!!(await sb.client.storage.from('phase8-drive-staging').download(driveA.path)).error,'other owner read accepted');await step('real finalized drives, lease, tombstone and Storage owner isolation');
 const wrong=await request(a,sa.token,'incorrect-password');check(wrong.status===403&&wrong.body.error==='reauthentication_failed',`wrong password status ${wrong.status}`);
 const foreign=await request(a,sa.token,a.password,b.id);check(foreign.status===403&&foreign.body.error==='account_context_changed',`different owner status ${foreign.status}`);
 const accepted=await request(a,sa.token);check(accepted.status===202,`request status ${accepted.status} error ${accepted.body.error??'none'}`);await step('password and owner checks; A deletion request accepted');
 const badReceipt=await run(a,await sha('wrong synthetic receipt'));check(badReceipt.status===403&&badReceipt.body.error==='receipt_unavailable',`wrong receipt status ${badReceipt.status}`);
 const first=await run(a);check(first.status===202&&first.body.state==='pending',`first resume status ${first.status} state ${first.body.state??first.body.error??'none'}`);
 check(await present(a),'Auth removed before Storage cleanup');check(await sql(`select count(*) from public.phase8_drive_manifests where owner_id='${a.id}'`)==='2','manifests removed before Storage cleanup');await step('wrong receipt rejected; first resume preserves Auth and drives');
 await finish(a);check(!(await present(a)),'A Auth remains');check(await privateRows(a.id)===0,'A owner-scoped private rows remain');
 for(const bucket of ['phase8-drive-staging','world-drive-sources']){const objects=await admin.storage.from(bucket).list(a.id,{limit:1000});check(!objects.error&&objects.data.length===0,'A Storage objects remain');}
 check(await present(b),'B Auth was removed');check(await sql(`select count(*) from public.phase8_drive_manifests where owner_id='${b.id}'`)==='1','B finalized manifest lost');check(await sql(`select count(*) from public.phase8_drive_leases where owner_id='${b.id}'`)==='1','B lease lost');check(!(await admin.storage.from('phase8-drive-staging').download(driveB.path)).error,'B stored object missing');
 const feed=await invoke('phase8-drive-download',sb.token,{action:'begin'});check(feed.status===200&&feed.body.changes.some((c:{mutation:{ownerId:string}})=>c.mutation.ownerId===b.id),'B official download failed');
 const retry=await run(a);check(retry.status===200&&retry.body.state==='completed','completed receipt must be idempotent');const repeated=await request(a,sa.token);check([401,403].includes(repeated.status),'deleted A must not start another request');await step('A terminal receipt; storage and finalized data removed; B preserved');
 const acceptedB=await request(b,sb.token);check(acceptedB.status===202,`B official cleanup request status ${acceptedB.status}`);await finish(b);check(!(await present(b)),'B Auth cleanup failed');check(await privateRows(b.id)===0,'B owner-scoped private rows remain');for(const bucket of ['phase8-drive-staging','world-drive-sources']){const objects=await admin.storage.from(bucket).list(b.id,{limit:1000});check(!objects.error&&objects.data.length===0,'B Storage objects remain');}await step('B cleaned through official request and receipt workflow');
}});
