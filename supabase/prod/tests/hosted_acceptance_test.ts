import {createClient} from 'npm:@supabase/supabase-js@2.117.2';
import {canonicalJson,canonicalSha256,expectedDriveUpsertKey,ownerScope,sha256Hex} from '../../phase8-dev/supabase/functions/_shared/common.ts';
import {cloudFixture} from './hosted_drive_fixture.ts';
import {distanceMeters} from '../../functions/process-world-publish/world_validation.ts';
import {sourceMatches} from '../../functions/process-world-publish/source_contract.ts';

const url='https://arwnbogcswisfesayosy.supabase.co';
const runId=Deno.env.get('DRIVEIT_HOSTED_RUN_ID')??'';
function check(value:unknown,name:string):asserts value{if(!value)throw Error('hosted_assertion:'+name);}
const pause=(ms:number)=>new Promise(r=>setTimeout(r,ms));
type Person={email:string;password:string;id?:string;requestId:string;receipt:string;requested?:boolean;deleted?:boolean};
type Journal={runId:string;state:string;people:Person[];steps:string[];publishes?:string[]};
async function journalIo(value?:Journal):Promise<Journal|null>{
 const command=new Deno.Command('pwsh',{args:['-NoProfile','-File','tool/hosted_test_journal.ps1','-RunId',runId,...(value?[]:['-Read'])],stdin:value?'piped':'null',stdout:'piped',stderr:'piped'});
 if(!value){const result=await command.output();check(result.success,'encrypted_journal_read');return JSON.parse(new TextDecoder().decode(result.stdout));}
 const child=command.spawn(),writer=child.stdin.getWriter();await writer.write(new TextEncoder().encode(JSON.stringify(value)));await writer.close();const result=await child.output();check(result.success,'encrypted_journal_write');return value;
}
Deno.test({name:'approved PROD synthetic Auth/cloud/Planet/deletion service acceptance',sanitizeResources:false,sanitizeOps:false,fn:async()=>{
 check(Deno.env.get('DRIVEIT_HOSTED_APPROVAL')==='APPROVED_TWO_SYNTHETIC_USERS'&&/^[a-f0-9-]{36}$/.test(runId),'explicit_approved_run');
 const publicKey=Deno.env.get('DRIVEIT_HOSTED_PUBLIC_KEY')!,serviceKey=Deno.env.get('DRIVEIT_HOSTED_SERVICE_KEY')!,mapbox=Deno.env.get('DRIVEIT_HOSTED_MAPBOX')!;
 check(publicKey&&serviceKey&&mapbox,'server_side_test_credentials');
 const options={auth:{persistSession:false,autoRefreshToken:false},global:{fetch:(input:RequestInfo|URL,init?:RequestInit)=>fetch(input,{...init,signal:init?.signal??AbortSignal.timeout(100000)})}};
 const admin=createClient(url,serviceKey,options),a=createClient(url,publicKey,options),b=createClient(url,publicKey,options),second=createClient(url,publicKey,options);
 let journal=await journalIo();
 if(!journal){
  const people=['a','b'].map(label=>({email:`driveit-hosted-${label}-${runId}@example.invalid`,password:`Test-${crypto.randomUUID()}-OnlySynthetic!`,requestId:crypto.randomUUID(),receipt:[...crypto.getRandomValues(new Uint8Array(32))].map(x=>x.toString(16).padStart(2,'0')).join('')}));
  journal={runId,state:'planned',people,steps:[]};await journalIo(journal);
 }
 check(journal.runId===runId&&journal.people.length===2,'journal_scope');
 const state=journal;
 async function step(name:string){state.steps.push(name);await journalIo(state);console.info('PASS: '+name);}
 async function invoke(name:string,token:string|null,body:unknown){
  const response=await fetch(`${url}/functions/v1/${name}`,{method:'POST',headers:{apikey:publicKey,'content-type':'application/json',...(token?{authorization:`Bearer ${token}`}:{})},body:JSON.stringify(body),signal:AbortSignal.timeout(100000)});
  return {status:response.status,body:await response.json()};
 }
 async function login(person:Person,client= a){const result=await client.auth.signInWithPassword({email:person.email,password:person.password});check(!result.error&&result.data.session,'synthetic_login');return result.data.session.access_token;}
 async function owned(person:Person){
  check(person.id&&person.email===`driveit-hosted-${person===state.people[0]?'a':'b'}-${runId}@example.invalid`,'synthetic_identity_shape');
  const found=await admin.auth.admin.getUserById(person.id);
  if(found.error&&(found.error.status===404||found.error.code==='user_not_found'))return false;
  check(!found.error&&found.data.user?.user_metadata.driveit_acceptance_run===runId&&found.data.user.email===person.email,'synthetic_owner_marker');return true;
 }
 async function erase(person:Person){
  if(!person.id||person.deleted)return;
  const exists=await owned(person);
  const receiptBody={action:'run',requestId:person.requestId,receiptToken:person.receipt};
  let response=await invoke('delete-account',null,receiptBody);
  if(!exists){check(response.status===200&&response.body.state==='completed','missing_auth_requires_terminal_receipt');person.deleted=true;await journalIo(state);return;}
  if(!person.requested&&![200,202].includes(response.status)){
   const jwt=await login(person,person===state.people[0]?a:b);
   response=await invoke('delete-account',jwt,{...receiptBody,action:'request',expectedOwner:person.id,password:person.password,confirm:'DELETE_MY_ACCOUNT'});
   check(response.status===202,'deletion_request_ack');person.requested=true;await journalIo(state);
  }
  for(let attempt=0;attempt<12;attempt++){
   response=await invoke('delete-account',null,receiptBody);
   if(response.status===200&&response.body.state==='completed'){
    const gone=await admin.auth.admin.getUserById(person.id);check(gone.error&&(gone.error.status===404||gone.error.code==='user_not_found'),'auth_removed_after_terminal_ack');
    // Private tables intentionally have no direct service-role SELECT grant.
    // The PowerShell driver independently verifies owner-row counts through
    // its read-only Management query after terminal receipt confirmation.
    for(const bucket of ['world-drive-sources','phase8-drive-staging']){const files=await admin.storage.from(bucket).list(person.id,{limit:1000});check(!files.error&&files.data.length===0,'owned_storage_removed');}
    person.deleted=true;await journalIo(state);return;
   }
   check(response.body.state!=='blocked_planet','deletion_blocked_planet_preserved_for_review');
   check([202,503].includes(response.status),'deletion_retryable_response');await pause(500);
  }
  throw Error('deletion_not_terminal_receipt_retained');
 }
 let failed=false;
 try {
  if(Deno.env.get('DRIVEIT_HOSTED_CLEANUP_ONLY')==='true'){return;}
  check(state.state==='planned'&&state.people.every(p=>!p.id),'fresh_run_or_explicit_cleanup_required');
  // Only the two accounts in the encrypted planned journal may be created.
  for(const person of state.people){
   const result=await admin.auth.admin.createUser({email:person.email,password:person.password,email_confirm:true,user_metadata:{driveit_acceptance_run:runId}});
   check(!result.error&&result.data.user,'create_synthetic_account');person.id=result.data.user.id;await journalIo(state);
  }
  const [pa,pb]=state.people,tokenA=await login(pa,a),tokenB=await login(pb,b);state.state='running';await journalIo(state);
  const profile=await a.from('profiles').select('id').eq('id',pa.id!).single();check(!profile.error&&profile.data.id===pa.id,'auth_profile_trigger');
  const forbidden=await b.from('profiles').update({display_name:'forbidden-test'}).eq('id',pa.id!).select('id');check(!forbidden.error&&forbidden.data.length===0,'profile_write_owner_isolation');
  await step('Auth/profile and A/B owner isolation');
  const sourceIdentity=crypto.randomUUID(),driveId='synthetic-cloud-'+runId,payload=cloudFixture(pa.id!,sourceIdentity,driveId);
  const mutation={version:2,kind:'driveUpsert',ownerId:pa.id,ownerScope:ownerScope(pa.id!),sourceIdentity,idempotencyKey:await expectedDriveUpsertKey(pa.id!,sourceIdentity),payloadFingerprint:await canonicalSha256(payload),payload};
  const bytes=new TextEncoder().encode(canonicalJson(mutation));
  const beginBody={ownerId:pa.id,ownerScope:mutation.ownerScope,sourceIdentity,idempotencyKey:mutation.idempotencyKey,contractVersion:2,payloadFingerprint:mutation.payloadFingerprint,objectSha256:await sha256Hex(bytes),objectBytes:bytes.length};
  const begin=await invoke('phase8-drive-begin',tokenA,beginBody);check(begin.status===200&&begin.body.state==='staging','cloud_begin');
  const objectPath=`${pa.id}/${begin.body.intentId}/envelope.json`;
  check(!(await a.storage.from('phase8-drive-staging').upload(objectPath,bytes,{contentType:'application/json',upsert:false})).error,'cloud_private_upload');
  check(!!(await b.storage.from('phase8-drive-staging').download(objectPath)).error,'B_private_source_read_denied');
  const finalized=await invoke('phase8-drive-finalize',tokenA,{intentId:begin.body.intentId});check(finalized.status===200,'cloud_finalize');
  const retry=await invoke('phase8-drive-begin',tokenA,beginBody);check(retry.status===200&&retry.body.state==='finalized'&&JSON.stringify(retry.body.receipt)===JSON.stringify(finalized.body.receipt),'lost_ack_idempotency');
  const conflict=await invoke('phase8-drive-begin',tokenA,{...beginBody,objectSha256:'f'.repeat(64)});check(conflict.status===409,'conflicting_retry_rejected');
  const secondToken=await login(pa,second);
  const downloaded=await invoke('phase8-drive-download',secondToken,{action:'begin',limit:1});check(downloaded.status===200&&downloaded.body.changes.length===1&&canonicalJson(downloaded.body.changes[0].mutation)===canonicalJson(mutation),'second_client_exact_download');
  const other=await invoke('phase8-drive-download',tokenB,{action:'begin'});check(other.status===200&&other.body.changes.length===0,'B_download_no_A_records');
  await step('Private Storage, upload/finalize, retry/conflict and second-client download');
  const observed=await invoke('phase8-drive-delete',tokenA,{action:'observe',sourceIdentity});check(observed.status===200,'cloud_delete_observation');
  const deletionId=crypto.randomUUID(),tombstonePayload={deletionId,deletedAt:new Date().toISOString(),causalVersion:1,observedRemoteSequence:observed.body.change_sequence,observedPayloadFingerprint:observed.body.payload_fingerprint};
  const tombstone={version:2,kind:'driveTombstone',ownerId:pa.id,ownerScope:ownerScope(pa.id!),sourceIdentity,payload:tombstonePayload,payloadFingerprint:await canonicalSha256(tombstonePayload),idempotencyKey:'owner-sync-v2:'+await sha256Hex(new TextEncoder().encode(`${ownerScope(pa.id!)}|${pa.id}|driveTombstone|${deletionId}`))};
  check((await invoke('phase8-drive-delete',tokenB,{mutation:tombstone})).status===422,'B_cannot_delete_A');
  const deleted=await invoke('phase8-drive-delete',tokenA,{mutation:tombstone});check(deleted.status===200&&canonicalJson(deleted.body.mutation)===canonicalJson(tombstone),'cloud_tombstone_ack');
  check((await invoke('phase8-drive-delete',tokenA,{mutation:tombstone})).status===200,'cloud_delete_idempotent_retry');
  const deletionFeed=await invoke('phase8-drive-download',tokenA,{action:'begin',limit:10});check(deletionFeed.status===200&&deletionFeed.body.changes.some((c:{mutation:{kind:string}})=>c.mutation.kind==='driveTombstone'),'deletion_tombstone_downloaded');
  await step('Cloud record deletion and duplicate protection');
  const group=await a.rpc('phase8_group_command',{p_action:'create'});check(group.error?.message==='group_feature_disabled','Group_Drive_stays_disabled');
  await step('Group Drive server gate remains closed');
  // Public, synthetic Berlin route; never imports a device or user GPS file.
  const directions=await fetch('https://api.mapbox.com/directions/v5/mapbox/driving/13.377704,52.516275;13.278,52.509?overview=full&geometries=geojson&access_token='+encodeURIComponent(mapbox),{signal:AbortSignal.timeout(30000)});
  check(directions.ok,'Mapbox_synthetic_directions_auth');const route=await directions.json();check(route.code==='Ok'&&route.routes?.[0]?.geometry?.coordinates?.length>2,'synthetic_route');
  const coordinates=route.routes[0].geometry.coordinates as number[][];
  const points:{latitude:number;longitude:number}[]=[];
  for(let i=1;i<coordinates.length;i++){
   const first={latitude:coordinates[i-1][1],longitude:coordinates[i-1][0]},last={latitude:coordinates[i][1],longitude:coordinates[i][0]},pieces=Math.max(1,Math.ceil(distanceMeters(first,last)/12));
   for(let j=0;j<pieces;j++){const p={latitude:first.latitude+(last.latitude-first.latitude)*j/pieces,longitude:first.longitude+(last.longitude-first.longitude)*j/pieces};if(!points.length||distanceMeters(points.at(-1)!,p)>=8)points.push(p);}
  }
  const last=coordinates.at(-1)!;points.push({latitude:last[1],longitude:last[0]});check(points.length>=100&&points.length<=2500,'bounded_synthetic_route_points');
  const start=Date.UTC(2026,0,1),distances=points.map((p,i)=>i?distanceMeters(points[i-1],p):0),total=distances.reduce((x,y)=>x+y,0);check(total>=5000,'Planet_minimum_5km');
  const publishes:string[]=[];
  for(const [person,client,token] of [[pa,a,tokenA],[pb,b,tokenB]] as const){
   let id='';const localDrive='synthetic-planet-'+crypto.randomUUID(),started=new Date(start).toISOString(),ended=new Date(start+(points.length-1)*2000).toISOString();
   const source={schema_version:2,publish_id:id,local_drive_id:localDrive,telemetry_version:1,drive_score_algorithm_version:1,world_rules_version:6,score_calculation_mode:'reliable_intervals',score_calculation_version:1,telemetry_reliability:{reliabilityPolicyVersion:1,startedAtMicros:start*1000,stopRequestedAtMicros:(start+(points.length-1)*2000)*1000},started_at:started,ended_at:ended,recorded_distance_meters:total,raw_route:points.map(p=>({...p,break_before:false})),canonical_telemetry:points.map((p,i)=>({...p,timestamp:new Date(start+i*2000).toISOString(),timestamp_micros:String((start+i*2000)*1000),speed_mps:i?distances[i]/2:distances[1]/2,heading_degrees:270,altitude_meters:0,accuracy_meters:3,distance_from_previous_meters:distances[i],acceleration_mps2:0,break_before:false,gap_duration_micros:0,speed_source:'native',acceleration_reliable:true}))};
   const inserted=await client.from('world_publishes').insert({local_drive_id:localDrive,started_at:started,ended_at:ended,distance_meters:total,world_rules_version:6}).select('id').single();check(!inserted.error,'explicit_synthetic_publish_'+String(inserted.error?.code??'ok'));id=inserted.data!.id;source.publish_id=id;publishes.push(id);state.publishes??=[];state.publishes.push(id);await journalIo(state);
   check(sourceMatches(source,{id,local_drive_id:localDrive,source_schema_version:2,telemetry_version:1,drive_score_algorithm_version:1,world_rules_version:6,raw_route_point_count:points.length,telemetry_point_count:points.length}),'schema2_source_contract');
   check(!(await client.storage.from('world-drive-sources').upload(`${person.id}/${id}.json`,new Blob([JSON.stringify(source)],{type:'application/json'}),{upsert:false})).error,'immutable_schema2_source');
   check(!!(await (person===pa?b:a).storage.from('world-drive-sources').download(`${person.id}/${id}.json`)).error,'Planet_private_GPS_isolation');
   const attached=await client.rpc('attach_world_publish_source',{p_publish_id:id,p_source_schema_version:2,p_telemetry_version:1,p_drive_score_algorithm_version:1,p_raw_route_point_count:points.length,p_telemetry_point_count:points.length});check(!attached.error,'source_attach_ack');
   const processed=await invoke('process-world-publish',token,{publish_id:id});check(processed.status===200&&processed.body.ok===true,'Planet_processing_'+String(processed.body.error_code??processed.status));
   const row=await client.from('world_publishes').select('status').eq('id',id).single();check(!row.error&&row.data.status==='published','authoritative_published_status');
   check((await invoke('process-world-publish',token,{publish_id:id})).status===200,'publication_retry');
  }
  await step('Two schema2 Planet publications, real Mapbox and shared-road processing');
  const viewport=await b.rpc('read_planet_viewport',{p_south:52.45,p_north:52.56,p_west:13.2,p_east:13.45,p_zoom:14});check(!viewport.error&&viewport.data.traces?.length>0,'Planet_map_read');
  const detail=await invoke('planet-trace-detail',tokenB,{trace_id:viewport.data.traces[0].id});check(detail.status===200,'Planet_detail_read');
  check(!JSON.stringify(detail.body).includes('canonical_telemetry')&&!JSON.stringify(detail.body).includes('source_path'),'private_source_absent_from_detail');
  await step('Planet viewport/detail and private-source projection');
  await erase(pa);check(!(await b.from('profiles').select('id').eq('id',pb.id!).single()).error,'B_survives_A_deletion');
  const surviving=await b.from('world_publishes').select('status').eq('id',publishes[1]).single();check(!surviving.error&&surviving.data.status==='published','B_Planet_publication_survives');
  await step('Account A deletion, receipt recovery and surviving B contribution');
 }catch(error){failed=true;console.error(error instanceof Error&&error.message.startsWith('hosted_assertion:')?error.message:'Hosted test failed; raw error suppressed');throw Error('hosted_acceptance_failed_see_named_checkpoint');}
 finally {
  const errors:string[]=[];
  for(const person of state.people){try{
   if(!person.id){
    const listed=await admin.auth.admin.listUsers({page:1,perPage:1000});check(!listed.error,'lost_create_ack_lookup');
    const matching=listed.data.users.filter(u=>u.email===person.email&&u.user_metadata.driveit_acceptance_run===runId);
    check(matching.length<=1,'unique_synthetic_marker');if(matching.length){person.id=matching[0].id;await journalIo(state);}
   }
   await erase(person);
  }catch(error){console.error(error instanceof Error&&error.message.startsWith('hosted_assertion:')?error.message:'Synthetic cleanup needs review; raw response suppressed');errors.push('synthetic_cleanup_pending');}}
  state.state=errors.length?'cleanup_pending':Deno.env.get('DRIVEIT_HOSTED_CLEANUP_ONLY')==='true'?'cleanup_completed':failed?'failed_cleaned':'completed';await journalIo(state);
  await Promise.all([a,b,second,admin].map(c=>c.removeAllChannels()));
  if(errors.length)throw Error('synthetic_cleanup_pending_encrypted_receipts_preserved');
  console.info('PASS: all test account/private source cleanup acknowledged; minimized deletion audit retained by policy');
 }
}});
