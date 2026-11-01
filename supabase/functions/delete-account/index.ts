import {createClient} from 'npm:@supabase/supabase-js@2.117.2';
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{'content-type':'application/json','cache-control':'no-store'}});
const hash=async(s:string)=>[...new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(s)))].map(b=>b.toString(16).padStart(2,'0')).join('');
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
function serverKey(){
 try{const k=JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS')??'{}');if(typeof k.default==='string')return k.default;}catch{/* Legacy server key below. */}
 return Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
}
const clientOptions={auth:{persistSession:false,autoRefreshToken:false},global:{fetch:(input:RequestInfo|URL,init?:RequestInit)=>fetch(input,{...init,signal:init?.signal??AbortSignal.timeout(15000)})}};
async function boundedJson(request:Request){
 if(Number(request.headers.get('content-length')??'0')>4096)throw Error('body_too_large');
 const reader=request.body?.getReader();if(!reader)throw Error('body_required');
 const chunks:Uint8Array[]=[];let size=0;
 try{while(true){const part=await reader.read();if(part.done)break;size+=part.value.length;if(size>4096){await reader.cancel();throw Error('body_too_large');}chunks.push(part.value);}}finally{reader.releaseLock();}
 const bytes=new Uint8Array(size);let offset=0;for(const c of chunks){bytes.set(c,offset);offset+=c.length;}
 return JSON.parse(new TextDecoder().decode(bytes));
}
Deno.serve(async request=>{
 if(request.method!=='POST')return json({error:'method_not_allowed'},405);
 const url=Deno.env.get('SUPABASE_URL'),key=serverKey();
 if(!url||!key)return json({error:'server_not_configured'},503);
 let body;
 try{body=await boundedJson(request);}catch{return json({error:'request_invalid'},400);}
 const admin=createClient(url,key,clientOptions);
 let digest:string;
 if(body?.action==='worker'){
  const expected=Deno.env.get('ACCOUNT_DELETION_WORKER_TOKEN'),supplied=request.headers.get('x-driveit-deletion-worker');
  if(!expected||!/^[0-9a-f]{64}$/.test(expected)||!supplied||supplied.length!==expected.length)return json({error:'unauthorized'},401);
  let difference=0;for(let i=0;i<expected.length;i++)difference|=expected.charCodeAt(i)^supplied.charCodeAt(i);
  if(difference!==0)return json({error:'unauthorized'},401);
  const pruned=await admin.rpc('account_deletion_prune_receipts');
  if(pruned.error)return json({error:'worker_unavailable'},503);
  const next=await admin.rpc('account_deletion_worker_jobs');
  if(next.error||!Array.isArray(next.data))return json({error:'worker_unavailable'},503);
  if(next.data.length===0)return json({state:'idle'});
  body={action:'run',requestId:next.data[0].id};digest=next.data[0].receipt_hash;
 }else{
  if(!body||!uuid.test(body.requestId??'')||!/^[0-9a-f]{64}$/.test(body.receiptToken??''))return json({error:'receipt_invalid'},400);
  digest=await hash(body.receiptToken);
 }
 const rpc=async(name:string,args:Record<string,unknown>)=>{const r=await admin.rpc(name,args);if(r.error)throw Error(r.error.code??'rpc_failed');return r.data;};
 let lease:string|undefined;
 try{
  if(body.action==='request'){
   if(!/^[0-9a-f]{64}$/.test(Deno.env.get('ACCOUNT_DELETION_WORKER_TOKEN')??''))return json({error:'recovery_not_configured'},503);
   if(body.confirm!=='DELETE_MY_ACCOUNT'||typeof body.password!=='string'||body.password.length<1)return json({error:'confirmation_required'},400);
   const jwt=request.headers.get('authorization')?.match(/^Bearer (\S+)$/)?.[1];
   if(!jwt)return json({error:'unauthorized'},401);
   const verified=await admin.auth.getUser(jwt);const user=verified.data.user;
   if(verified.error||!user?.email||user.is_anonymous)return json({error:'unauthorized'},401);
   // UI/cache identity is only a precondition, never authority to select a subject.
   if(body.expectedOwner!==user.id)return json({error:'account_context_changed'},403);
   // A refreshed JWT is not reauthentication. Verify the current password against the exact same UID.
   const verifier=createClient(url,key,clientOptions);
   const proof=await verifier.auth.signInWithPassword({email:user.email,password:body.password});
   if(proof.error||proof.data.user?.id!==user.id)return json({error:'reauthentication_failed'},403);
   // Revoke the temporary proof session; never return its token.
   await verifier.auth.signOut({scope:'local'});
   await rpc('account_deletion_prune_receipts',{});
   const result=await rpc('account_deletion_request',{p_owner:user.id,p_id:body.requestId,p_hash:digest});
   // Fence is already durable. Ban failure must never be reported as completed; receipt resumes safely.
   const ban=await admin.auth.admin.updateUserById(user.id,{ban_duration:'876000h'});
   if(ban.error)return json({state:result.state,error:'session_revocation_pending'},202);
   return json({state:result.state},202);
  }
  if(body.action!=='run')return json({error:'action_invalid'},400);
  lease=crypto.randomUUID();
  const job=await rpc('account_deletion_claim',{p_id:body.requestId,p_hash:digest,p_lease:lease});
  if(job.state==='completed')return json({state:'completed'});
  if(job.state==='busy')return json({state:'busy'},202);
  const files=await rpc('account_deletion_objects',{p_id:body.requestId,p_lease:lease});
  if(!Array.isArray(files))throw Error('object_listing_invalid');
  const buckets=new Map<string,string[]>();
  for(const f of files){if(typeof f.bucket!=='string'||typeof f.name!=='string')throw Error('object_listing_invalid');buckets.set(f.bucket,[...(buckets.get(f.bucket)??[]),f.name]);}
  const firstBucket=buckets.entries().next();
  if(!firstBucket.done){const [bucket,paths]=firstBucket.value;if((await admin.storage.from(bucket).remove(paths)).error)throw Error('storage_remove_failed');}
  const state=await rpc('account_deletion_purge',{p_id:body.requestId,p_lease:lease});
  if(state!=='purged')return json({state},202);
  // Database and Storage are empty before Auth removal. If this boundary fails, the job remains retryable.
  const removed=await admin.auth.admin.deleteUser(job.owner);
  if(removed.error){
   const verify=await admin.auth.admin.getUserById(job.owner);
   if(!verify.error || ![404,'404','user_not_found'].includes(verify.error.code??verify.error.status??''))throw Error('auth_remove_unconfirmed');
  }
  await rpc('account_deletion_complete',{p_id:body.requestId,p_lease:lease});
  return json({state:'completed'});
 }catch(error){
  if(lease)await admin.rpc('account_deletion_failed',{p_id:body.requestId,p_lease:lease});
  return error instanceof Error&&error.message==='42501'?json({error:'receipt_unavailable'},403):json({error:'deletion_not_completed'},503);
 }
 finally{if(lease)await admin.rpc('account_deletion_release',{p_id:body.requestId,p_lease:lease});}
});
