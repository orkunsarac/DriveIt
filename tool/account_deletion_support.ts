import { DatabaseSync } from 'node:sqlite';

type CaseState = 'verification_pending'|'consent_pending'|'revocation_pending'|'queued'|'processing'|'retry_pending'|'blocked_planet'|'completed'|'expired'|'locked'|'delivery_failed'|'needs_review';
type CaseRow = {id:string;fingerprint:string|null;owner_id:string|null;state:CaseState;challenge_hash:string|null;challenge_kind:string|null;expires_at:number|null;attempts:number;job_id:string|null;created_at:number;updated_at:number};
type User = {id:string;email?:string;email_confirmed_at?:string|null;is_anonymous?:boolean};
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const hex=(bytes:Uint8Array)=>[...bytes].map(x=>x.toString(16).padStart(2,'0')).join('');
const randomHex=(length=32)=>{const b=new Uint8Array(length);crypto.getRandomValues(b);return hex(b);};
const digest=async(value:string)=>hex(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(value))));
async function hmac(secret:string,value:string){const key=await crypto.subtle.importKey('raw',new TextEncoder().encode(secret),{name:'HMAC',hash:'SHA-256'},false,['sign']);return hex(new Uint8Array(await crypto.subtle.sign('HMAC',key,new TextEncoder().encode(value))));}
function equal(a:string,b:string){if(a.length!==b.length)return false;let n=0;for(let i=0;i<a.length;i++)n|=a.charCodeAt(i)^b.charCodeAt(i);return n===0;}
function requireLocal(url:string,label:string){const u=new URL(url);if(u.protocol!=='http:'||u.hostname!=='127.0.0.1'||!u.port)throw new Error(`${label}_must_be_loopback`);return u;}

export type SupportConfig={apiUrl:string;serviceKey:string;anonKey:string;operatorToken:string;fingerprintKey:string;workerToken:string;mailpitUrl:string;dbPath:string;now?:()=>number;fetcher?:typeof fetch};
export class DeletionSupportOperator {
  readonly db:DatabaseSync;readonly api:string;readonly mailpit:string;readonly now:()=>number;readonly fetcher:typeof fetch;
  constructor(readonly config:SupportConfig){
    this.api=requireLocal(config.apiUrl,'api').origin;this.mailpit=requireLocal(config.mailpitUrl,'mailpit').origin;
    if(!/^[0-9a-f]{64}$/i.test(config.operatorToken)||!/^[0-9a-f]{64}$/i.test(config.fingerprintKey)||!/^[0-9a-f]{64}$/i.test(config.workerToken))throw new Error('operator_configuration_invalid');
    this.db=new DatabaseSync(config.dbPath);this.now=config.now??Date.now;this.fetcher=config.fetcher??fetch;
    this.db.exec(`PRAGMA journal_mode=WAL;PRAGMA foreign_keys=ON;
      CREATE TABLE IF NOT EXISTS support_cases(id TEXT PRIMARY KEY,fingerprint TEXT,owner_id TEXT,state TEXT NOT NULL,challenge_hash TEXT,challenge_kind TEXT,expires_at INTEGER,attempts INTEGER NOT NULL DEFAULT 0,job_id TEXT,created_at INTEGER NOT NULL,updated_at INTEGER NOT NULL);
      CREATE UNIQUE INDEX IF NOT EXISTS support_one_open_per_address ON support_cases(fingerprint) WHERE fingerprint IS NOT NULL AND state IN('verification_pending','consent_pending','revocation_pending','queued','processing','retry_pending','blocked_planet','delivery_failed','needs_review');
      CREATE TABLE IF NOT EXISTS support_events(id INTEGER PRIMARY KEY,case_id TEXT NOT NULL,action TEXT NOT NULL,at INTEGER NOT NULL,FOREIGN KEY(case_id) REFERENCES support_cases(id));
      CREATE TABLE IF NOT EXISTS support_rate(fingerprint TEXT PRIMARY KEY,window_start INTEGER NOT NULL,count INTEGER NOT NULL);`);
  }
  close(){this.db.close();}
  private async adminRequest(path:string,method='GET',body?:unknown):Promise<{data:any;error:boolean}>{
    try{
      const response=await this.fetcher(`${this.api}${path}`,{method,headers:{apikey:this.config.serviceKey,authorization:`Bearer ${this.config.serviceKey}`,'content-type':'application/json'},...(body===undefined?{}:{body:JSON.stringify(body)}),signal:AbortSignal.timeout(15000)});
      let data:any=null;try{data=await response.json();}catch{await response.body?.cancel();}
      return {data,error:!response.ok};
    }catch{return {data:null,error:true};}
  }
  private async rpc(name:string,args:Record<string,unknown>){return await this.adminRequest(`/rest/v1/rpc/${name}`,'POST',args);}
  private authorize(value:string){if(!equal(value,this.config.operatorToken))throw new Error('operator_unauthorized');}
  private event(id:string,action:string){this.db.prepare('INSERT INTO support_events(case_id,action,at) VALUES(?,?,?)').run(id,action,this.now());}
  private get(id:string):CaseRow|null{return (this.db.prepare('SELECT * FROM support_cases WHERE id=?').get(id) as CaseRow|undefined)??null;}
  private async fingerprint(email:string){return await hmac(this.config.fingerprintKey,email.trim().toLowerCase());}
  private async verifiedUser(email:string):Promise<User|null>{
    const target=email.trim().toLowerCase();if(target.length>254||!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(target))return null;
    for(let page=1;page<=100;page++){
      const result=await this.adminRequest(`/auth/v1/admin/users?page=${page}&per_page=100`);if(result.error||!Array.isArray(result.data?.users))throw new Error('auth_directory_unavailable');
      const matches=(result.data.users as User[]).filter(u=>u.email?.toLowerCase()===target&&u.email_confirmed_at&&!u.is_anonymous);
      if(matches.length>1)throw new Error('auth_identity_ambiguous');if(matches.length===1)return matches[0] as User;if(result.data.users.length<100)break;
    }
    return null;
  }
  private async verifiedUserById(id:string,fingerprint:string):Promise<User|null>{
    const r=await this.adminRequest(`/auth/v1/admin/users/${encodeURIComponent(id)}`);const user=(r.data?.user??r.data) as User|null;
    if(r.error||!user?.email||!user.email_confirmed_at||user.is_anonymous)return null;
    return await this.fingerprint(user.email)===fingerprint?user:null;
  }
  private async send(to:string,caseId:string,code:string,kind:'ownership'|'consent'){
    const subject=kind==='ownership'?'DriveIt başvuru e-posta doğrulaması':'DriveIt hesap silme için açık onay';
    const text=kind==='ownership'
      ?`DriveIt destek başvurunuz için doğrulama kodu: ${code}\n\nBu kod 15 dakika içinde tek kullanımlıdır. Kodu yalnız DriveIt destek yazışmasına yanıt olarak verin. Bu doğrulama silme talebini başlatmaz. Parolanızı veya oturum bağlantınızı paylaşmayın. Vaka: ${caseId}`
      :`DriveIt hesabınızın silinmesini açıkça onaylamak için bu iletiye yalnız şu ifadeyle yanıt verin: DELETE MY DRIVEIT ACCOUNT ${code}\n\nKod 15 dakika içinde tek kullanımlıdır. Bu yanıt hesabın silme işlemine alınmasına izin verir. Parolanızı veya oturum bağlantınızı göndermeyin. Vaka: ${caseId}`;
    const response=await this.fetcher(`${this.mailpit}/api/v1/send`,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({From:{Email:'no-reply@driveit.local',Name:'DriveIt yerel başvuru testi'},To:[{Email:to}],Subject:subject,Text:text}),signal:AbortSignal.timeout(10000)});
    await response.body?.cancel();if(!response.ok)throw new Error('challenge_delivery_failed');
  }
  async openRequest(email:string,operatorToken:string){
    this.authorize(operatorToken);const fp=await this.fingerprint(email);const now=this.now();
    const active=this.db.prepare("SELECT * FROM support_cases WHERE fingerprint=? AND state IN('verification_pending','consent_pending','revocation_pending','queued','processing','retry_pending','blocked_planet','delivery_failed','needs_review')").get(fp) as CaseRow|undefined;
    if(active)return {accepted:true,duplicate:true,caseId:active.id,state:active.state};
    const rate=this.db.prepare('SELECT * FROM support_rate WHERE fingerprint=?').get(fp) as {fingerprint:string;window_start:number;count:number}|undefined;
    if(rate&&now-rate.window_start<3600000&&rate.count>=3)return {accepted:true,duplicate:false,caseId:null,state:'verification_pending' as const};
    this.db.prepare(`INSERT INTO support_rate(fingerprint,window_start,count) VALUES(?,?,1) ON CONFLICT(fingerprint) DO UPDATE SET window_start=CASE WHEN excluded.window_start-support_rate.window_start>=3600000 THEN excluded.window_start ELSE support_rate.window_start END,count=CASE WHEN excluded.window_start-support_rate.window_start>=3600000 THEN 1 ELSE support_rate.count+1 END`).run(fp,now);
    const user=await this.verifiedUser(email);
    // Same generic acknowledgement for absent, unverified, or valid addresses; no case is created for an unknown identity.
    if(!user?.email)return {accepted:true,duplicate:false,caseId:null,state:'verification_pending' as const};
    const id=crypto.randomUUID(),code=randomHex(),at=this.now();
    this.db.prepare('INSERT INTO support_cases(id,fingerprint,state,challenge_hash,challenge_kind,expires_at,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?)').run(id,fp,'verification_pending',await digest(code),'ownership',at+900000,at,at);
    this.event(id,'case_received');
    try{await this.send(user.email,id,code,'ownership');this.event(id,'ownership_challenge_sent');}
    catch{this.db.prepare("UPDATE support_cases SET state='delivery_failed',challenge_hash=NULL,challenge_kind='ownership',expires_at=NULL,updated_at=? WHERE id=?").run(this.now(),id);this.event(id,'challenge_delivery_failed');return {accepted:true,duplicate:false,caseId:id,state:'delivery_failed' as const};}
    return {accepted:true,duplicate:false,caseId:id,state:'verification_pending' as const};
  }
  async retryChallenge(caseId:string,operatorToken:string){
    this.authorize(operatorToken);const row=this.get(caseId);if(!row||row.state!=='delivery_failed'||!row.fingerprint||!['ownership','consent'].includes(String(row.challenge_kind)))return {state:row?.state??'unknown'};
    const rate=this.db.prepare('SELECT * FROM support_rate WHERE fingerprint=?').get(row.fingerprint) as {fingerprint:string;window_start:number;count:number}|undefined;const now=this.now();
    if(rate&&now-rate.window_start<3600000&&rate.count>=3)return {state:'delivery_rate_limited'};
    this.db.prepare(`INSERT INTO support_rate(fingerprint,window_start,count) VALUES(?,?,1) ON CONFLICT(fingerprint) DO UPDATE SET window_start=CASE WHEN excluded.window_start-support_rate.window_start>=3600000 THEN excluded.window_start ELSE support_rate.window_start END,count=CASE WHEN excluded.window_start-support_rate.window_start>=3600000 THEN 1 ELSE support_rate.count+1 END`).run(row.fingerprint,now);
    const kind=row.challenge_kind as 'ownership'|'consent';const user=kind==='ownership'?await this.findVerifiedUserByFingerprint(row.fingerprint):await this.verifiedUserById(row.owner_id??'',row.fingerprint);
    if(!user?.email){this.db.prepare("UPDATE support_cases SET state='needs_review',fingerprint=NULL,challenge_kind=NULL,updated_at=? WHERE id=?").run(this.now(),caseId);this.event(caseId,'challenge_identity_unavailable');return {state:'needs_review'};}
    const code=randomHex(),state=kind==='ownership'?'verification_pending':'consent_pending';this.db.prepare('UPDATE support_cases SET state=?,challenge_hash=?,challenge_kind=?,expires_at=?,attempts=0,updated_at=? WHERE id=?').run(state,await digest(code),kind,this.now()+900000,this.now(),caseId);
    try{await this.send(user.email,caseId,code,kind);this.event(caseId,`${kind}_challenge_resent`);return {state};}
    catch{this.db.prepare("UPDATE support_cases SET state='delivery_failed',challenge_hash=NULL,expires_at=NULL,updated_at=? WHERE id=?").run(this.now(),caseId);this.event(caseId,'challenge_delivery_failed');return {state:'delivery_failed'};}
  }
  private async consumeCode(row:CaseRow,code:string,kind:'ownership'|'consent'){
    const state=kind==='ownership'?'verification_pending':'consent_pending';
    if(row.state!==state||row.challenge_kind!==kind||!row.challenge_hash)return false;
    if(!row.expires_at||row.expires_at<=this.now()){
      this.db.prepare("UPDATE support_cases SET state='expired',fingerprint=NULL,challenge_hash=NULL,challenge_kind=NULL,expires_at=NULL,updated_at=? WHERE id=?").run(this.now(),row.id);this.event(row.id,'challenge_expired');return false;
    }
    if(row.attempts>=5){this.db.prepare("UPDATE support_cases SET state='locked',fingerprint=NULL,challenge_hash=NULL,challenge_kind=NULL,expires_at=NULL,updated_at=? WHERE id=?").run(this.now(),row.id);this.event(row.id,'challenge_locked');return false;}
    const valid=equal(await digest(code),row.challenge_hash);
    if(!valid){const count=row.attempts+1;this.db.prepare('UPDATE support_cases SET attempts=?,state=?,updated_at=? WHERE id=?').run(count,count>=5?'locked':row.state,this.now(),row.id);this.event(row.id,'challenge_rejected');return false;}
    this.db.prepare('UPDATE support_cases SET challenge_hash=NULL,challenge_kind=NULL,expires_at=NULL,attempts=0,updated_at=? WHERE id=?').run(this.now(),row.id);return true;
  }
  async verifyOwnership(caseId:string,code:string,operatorToken:string){
    this.authorize(operatorToken);if(!UUID.test(caseId)||!/^[0-9a-f]{64}$/i.test(code))return {verified:false,state:'verification_pending'};
    const row=this.get(caseId);if(!row||row.state!=='verification_pending')return {verified:false,state:row?.state??'verification_pending'};
    if(!await this.consumeCode(row,code,'ownership'))return {verified:false,state:this.get(caseId)?.state??'expired'};
    const user=await this.verifiedUserById((await this.verifiedUserForCode(row,code))?.id??'',row.fingerprint??'');
    if(!user?.email){this.db.prepare("UPDATE support_cases SET state='needs_review',fingerprint=NULL,updated_at=? WHERE id=?").run(this.now(),caseId);this.event(caseId,'identity_changed');return {verified:false,state:'needs_review'};}
    const next=randomHex();this.db.prepare("UPDATE support_cases SET owner_id=?,state='consent_pending',challenge_hash=?,challenge_kind='consent',expires_at=?,updated_at=? WHERE id=?").run(user.id,await digest(next),this.now()+900000,this.now(),caseId);this.event(caseId,'identity_verified');
    try{await this.send(user.email,caseId,next,'consent');this.event(caseId,'consent_challenge_sent');}
    catch{this.db.prepare("UPDATE support_cases SET state='delivery_failed',updated_at=? WHERE id=?").run(this.now(),caseId);this.event(caseId,'challenge_delivery_failed');return {verified:true,state:'delivery_failed'};}
    return {verified:true,state:'consent_pending'};
  }
  // Re-resolve the verified email before consuming its token; lookup remains server-side and is never returned.
  private async verifiedUserForCode(row:CaseRow,code:string):Promise<User|null>{
    // Called only after the challenge hash matched. The target address is intentionally not persisted.
    const users=[] as User[];
    for(let page=1;page<=100;page++){const r=await this.adminRequest(`/auth/v1/admin/users?page=${page}&per_page=100`);if(r.error||!Array.isArray(r.data?.users))throw new Error('auth_directory_unavailable');for(const u of r.data.users as User[])if(u.email&&u.email_confirmed_at&&!u.is_anonymous&&await this.fingerprint(u.email)===row.fingerprint)users.push(u);if(r.data.users.length<100)break;}
    return users.length===1?users[0]:null;
  }
  private async findVerifiedUserByFingerprint(fingerprint:string){
    const users=[] as User[];
    for(let page=1;page<=100;page++){const r=await this.adminRequest(`/auth/v1/admin/users?page=${page}&per_page=100`);if(r.error||!Array.isArray(r.data?.users))throw new Error('auth_directory_unavailable');for(const u of r.data.users as User[])if(u.email&&u.email_confirmed_at&&!u.is_anonymous&&await this.fingerprint(u.email)===fingerprint)users.push(u);if(r.data.users.length<100)break;}
    return users.length===1?users[0]:null;
  }
  async consent(caseId:string,code:string,explicitConsent:string,operatorToken:string){
    this.authorize(operatorToken);if(explicitConsent!=='DELETE MY DRIVEIT ACCOUNT'||!UUID.test(caseId)||!/^[0-9a-f]{64}$/i.test(code))return {accepted:false,state:this.get(caseId)?.state??'verification_pending'};
    const row=this.get(caseId);if(!row||row.state!=='consent_pending'||!row.owner_id)return {accepted:false,state:row?.state??'verification_pending'};
    if(!await this.consumeCode(row,code,'consent'))return {accepted:false,state:this.get(caseId)?.state??'expired'};
    const user=await this.verifiedUserById(row.owner_id,row.fingerprint??'');if(!user?.email){this.db.prepare("UPDATE support_cases SET state='needs_review',fingerprint=NULL,updated_at=? WHERE id=?").run(this.now(),caseId);this.event(caseId,'identity_changed');return {accepted:false,state:'needs_review'};}
    const requestId=crypto.randomUUID(),receipt=await hmac(this.config.workerToken,`support-account-deletion:${caseId}`),receiptHash=await digest(receipt);
    this.db.prepare("UPDATE support_cases SET state='revocation_pending',job_id=?,updated_at=? WHERE id=?").run(requestId,this.now(),caseId);this.event(caseId,'explicit_consent_verified');
    const created=await this.rpc('account_deletion_request',{p_owner:user.id,p_id:requestId,p_hash:receiptHash});
    if(created.error){this.db.prepare("UPDATE support_cases SET state='needs_review',updated_at=? WHERE id=?").run(this.now(),caseId);this.event(caseId,'deletion_job_rejected');return {accepted:false,state:'needs_review'};}
    const banned=await this.adminRequest(`/auth/v1/admin/users/${encodeURIComponent(user.id)}`,'PUT',{ban_duration:'876000h'});
    if(banned.error){this.event(caseId,'session_revocation_pending');return {accepted:true,state:'revocation_pending'};}
    this.db.prepare("UPDATE support_cases SET state='queued',updated_at=? WHERE id=?").run(this.now(),caseId);this.event(caseId,'deletion_job_queued');
    return await this.runJob(caseId,operatorToken);
  }
  private async runJob(caseId:string,operatorToken:string){
    this.authorize(operatorToken);const row=this.get(caseId);if(!row?.job_id)return {state:row?.state??'unknown'};
    const receipt=await hmac(this.config.workerToken,`support-account-deletion:${caseId}`);
    try{
      const response=await this.fetcher(`${this.api}/functions/v1/delete-account`,{method:'POST',headers:{apikey:this.config.anonKey,'content-type':'application/json'},body:JSON.stringify({action:'run',requestId:row.job_id,receiptToken:receipt}),signal:AbortSignal.timeout(60000)});
      let body:Record<string,unknown>={};try{body=await response.json();}catch{/* Sanitized failure below. */}
      if(response.status===200&&body.state==='completed'){
        this.db.prepare("UPDATE support_cases SET state='completed',owner_id=NULL,fingerprint=NULL,updated_at=? WHERE id=?").run(this.now(),caseId);this.event(caseId,'deletion_completed');return {state:'completed'};
      }
      if(response.status===202&&body.state==='blocked_planet'){
        this.db.prepare("UPDATE support_cases SET state='blocked_planet',updated_at=? WHERE id=?").run(this.now(),caseId);this.event(caseId,'blocked_planet');return {state:'blocked_planet'};
      }
      if(response.status===202&&['pending','busy'].includes(String(body.state))){this.db.prepare("UPDATE support_cases SET state='processing',updated_at=? WHERE id=?").run(this.now(),caseId);this.event(caseId,'deletion_pending');return {state:'processing'};}
      this.db.prepare("UPDATE support_cases SET state='retry_pending',updated_at=? WHERE id=?").run(this.now(),caseId);this.event(caseId,'worker_retry_pending');return {state:'retry_pending'};
    }catch{
      this.db.prepare("UPDATE support_cases SET state='retry_pending',updated_at=? WHERE id=?").run(this.now(),caseId);this.event(caseId,'worker_retry_pending');return {state:'retry_pending'};
    }
  }
  async retry(caseId:string,operatorToken:string){
    this.authorize(operatorToken);const row=this.get(caseId);if(!row?.job_id)return {state:row?.state??'unknown'};
    if(row.state==='blocked_planet')return {state:'blocked_planet_requires_review'};
    if(!['retry_pending','processing','revocation_pending','queued'].includes(row.state))return {state:row.state};
    if(row.state==='revocation_pending'&&row.owner_id){const ban=await this.adminRequest(`/auth/v1/admin/users/${encodeURIComponent(row.owner_id)}`,'PUT',{ban_duration:'876000h'});if(ban.error)return {state:'revocation_pending'};this.db.prepare("UPDATE support_cases SET state='queued',updated_at=? WHERE id=?").run(this.now(),caseId);}
    if(row.state==='retry_pending'){
      const requeued=await this.rpc('account_deletion_worker_retry',{p_id:row.job_id});if(requeued.error||requeued.data!=='requeued')return {state:'retry_pending'};
    }
    this.event(caseId,'operator_retry');return await this.runJob(caseId,operatorToken);
  }
  status(caseId:string,operatorToken:string){this.authorize(operatorToken);const row=this.get(caseId);if(!row)return null;const events=this.db.prepare('SELECT action,at FROM support_events WHERE case_id=? ORDER BY id').all(caseId) as Array<{action:string;at:number}>;return {caseId:row.id,state:row.state,createdAt:row.created_at,updatedAt:row.updated_at,events};}
}

function readLine(promptText:string){
  return (async()=>{console.log(promptText);const reader=Deno.stdin.readable.getReader();const chunks:Uint8Array[]=[];try{while(true){const {value,done}=await reader.read();if(done)break;const at=value.indexOf(10);if(at>=0){chunks.push(value.slice(0,at));break;}chunks.push(value);}}finally{reader.releaseLock();}return new TextDecoder().decode(chunks.reduce((a,b)=>{const n=new Uint8Array(a.length+b.length);n.set(a);n.set(b,a.length);return n;},new Uint8Array())).trim();})();
}
if(import.meta.main){
  const opToken=Deno.env.get('PGR6F_OPERATOR_TOKEN')??'',api=Deno.env.get('PGR6_LOCAL_URL')??'',serviceKey=Deno.env.get('PGR6_SERVICE')??'',anonKey=Deno.env.get('PGR6_ANON')??'',workerToken=Deno.env.get('ACCOUNT_DELETION_WORKER_TOKEN')??'',fingerprintKey=Deno.env.get('PGR6F_FINGERPRINT_KEY')??'',dbPath=Deno.env.get('PGR6F_CASE_DB')??'';
  const mailpit=Deno.env.get('PGR6F_MAILPIT_URL')??'';if(!dbPath)throw new Error('operator_case_store_not_configured');
  const addressKey=fingerprintKey||await hmac(opToken,'pgr6f-address-fingerprint-v1');
  const operator=new DeletionSupportOperator({apiUrl:api,serviceKey,anonKey,operatorToken:opToken,fingerprintKey:addressKey,workerToken,mailpitUrl:mailpit,dbPath});
  try{
    const [command,caseId]=Deno.args;
    let result:unknown;
    if(command==='open')result=await operator.openRequest(await readLine('Başvurudaki e-posta adresi:'),opToken);
    else if(command==='resend')result=await operator.retryChallenge(caseId??await readLine('Vaka numarası:'),opToken);
    else if(command==='verify')result=await operator.verifyOwnership(caseId??await readLine('Vaka numarası:'),await readLine('E-posta doğrulama kodu:'),opToken);
    else if(command==='consent')result=await operator.consent(caseId??await readLine('Vaka numarası:'),await readLine('Silme onay kodu:'),await readLine('Kullanıcının yanıtındaki tam onay ifadesi:'),opToken);
    else if(command==='retry')result=await operator.retry(caseId??await readLine('Vaka numarası:'),opToken);
    else if(command==='status')result=operator.status(caseId??await readLine('Vaka numarası:'),opToken);
    else throw new Error('command_invalid');
    console.log(JSON.stringify(result));
  }finally{operator.close();}
}
