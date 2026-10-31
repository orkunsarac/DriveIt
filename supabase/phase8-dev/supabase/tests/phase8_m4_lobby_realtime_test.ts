import { createClient, SupabaseClient, RealtimeChannel } from "npm:@supabase/supabase-js@2.117.2";

function check(value: unknown, reason: string) {
  if (!value) throw new Error(reason);
}
const delay = (ms: number) => new Promise((r) => setTimeout(r, ms));

Deno.test("local V2 lobby/start/Edge/private Realtime and old-channel revocation", async () => {
  const url = Deno.env.get("PHASE8_LOCAL_URL");
  if (url !== "http://127.0.0.1:24471" || Deno.env.get("PHASE8_TEST_STACK") !== "pgr1-44f7398d") throw new Error("explicit P-GR1 target required");
  const container = Deno.env.get("PHASE8_TEST_DB_CONTAINER") ?? "";
  check(/^supabase-phase8-dev-pgr1-44f7398d-database-[a-f0-9]+$/.test(container), "explicit P-GR1 container required");
  async function sql(statement: string) {
    const result = await new Deno.Command("docker", {args:["exec",container,"psql","-U","postgres","-d","postgres","-v","ON_ERROR_STOP=1","-c",statement],stdout:"piped",stderr:"piped"}).output();
    check(result.success, "P-GR1 administrative SQL failed");
    return new TextDecoder().decode(result.stdout);
  }
  const mount = await new Deno.Command("docker", {args:["inspect","--format","{{range .Mounts}}{{if eq .Destination \"/var/lib/postgresql/data\"}}{{.Name}}{{end}}{{end}}",container],stdout:"piped"}).output();
  check(mount.success && new TextDecoder().decode(mount.stdout).trim() === "supabase-db-8be209d2ef18cfad45c272ec67764692", "P-GR1 volume identity required");
  const anon = Deno.env.get("PHASE8_LOCAL_ANON_KEY")!;
  const anonJwt = Deno.env.get("PHASE8_LOCAL_ANON_BEARER")!;
  const adminKey = Deno.env.get("PHASE8_LOCAL_SERVICE_ROLE_KEY")!;
  const adminJwt = Deno.env.get("PHASE8_LOCAL_SERVICE_ROLE_BEARER")!;
  check(anon && anonJwt && adminKey && adminJwt, "local credentials required");
  const client = (key: string, jwt: string) => createClient(url, jwt, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { fetch: (input, init) => {
      const headers = new Headers(init?.headers);
      headers.set("apikey", key);
      if (!headers.has("authorization")) headers.set("authorization", `Bearer ${jwt}`);
      return fetch(input, { ...init, headers, signal: init?.signal ?? AbortSignal.timeout(12000) });
    } },
  });
  const admin = client(adminKey, adminJwt);
  const clients: SupabaseClient[] = [];
  const ids: string[] = [];
  const channels: {client: SupabaseClient; channel: RealtimeChannel}[] = [];
  let groupId: string | undefined;
  const command = async (c: SupabaseClient, action: string, extra = {}) => {
    const r = await c.rpc("phase8_group_command", {p_action: action, p_group_id: groupId, ...extra});
    check(!r.error, `command ${action} failed: ${r.error?.code}`);
    return r.data;
  };
  try {
    for (let i = 0; i < 3; i++) {
      const email = `v2-${crypto.randomUUID()}@example.invalid`;
      const password = `Local-${crypto.randomUUID()}!`;
      const user = await admin.auth.admin.createUser({email, password, email_confirm: true});
      check(!user.error && user.data.user, "create synthetic account");
      ids.push(user.data.user!.id);
      const c = client(anon, anonJwt);
      const login = await c.auth.signInWithPassword({email, password});
      check(!login.error, "synthetic login");
      clients.push(c);
    }
    const [a,b,c] = clients;
    check((await sql("select case when public.phase8_group_enabled() then 'OPEN' else 'CLOSED' end;")).includes("CLOSED"), "default disabled");
    for (const action of ["create","join","start","share_start"]) {
      check((await a.rpc("phase8_group_command",{p_action:action})).error?.message === "group_feature_disabled", `closed ${action}`);
    }
    check((await a.from("phase8_group_rollout").update({enabled:true}).eq("singleton",true)).error !== null,"client cannot enable");
    await sql("update public.phase8_group_rollout set enabled=true;");
    const created = await command(a,"create");
    groupId = created.id;
    check(created.phase === "lobby", "create must open lobby");
    await command(b,"join", {p_invite_code: created.inviteCode});
    const denied = await b.rpc("phase8_group_command", {p_action: "start",p_group_id:groupId});
    check(denied.error?.code === "42501", "member start denied");
    const lobbyGps = await a.rpc("phase8_group_command", {p_action: "share_start",p_group_id:groupId,p_consent:true});
    check(lobbyGps.error?.message === "ride_not_started", "lobby cannot grant publication");
    const running = await command(a,"start");
    const repeated = await command(a,"start");
    check(running.phase === "running" && repeated.revision === running.revision,"idempotent start");
    check((await command(b,"current")).phase === "running", "peer receives phase through existing snapshot RPC");
    check(running.members.every((m: {sharingStatus:string}) => m.sharingStatus === "off"),"no automatic GPS");
    const sharing = await command(a,"share_start",{p_consent:true});
    let topic = `driveit:group:${groupId}:${sharing.generation}`;
    let received = 0, unauthorizedReceived = 0;
    async function subscribe(who: SupabaseClient, callback: () => void, authorized = true) {
      const channel = who.channel(topic,{config:{private:true}}).on("broadcast",{event:"location"},callback);
      channels.push({client:who,channel});
      const status = await new Promise<string>((resolve) => {
        const t=setTimeout(()=>resolve("TIMEOUT"),5000);
        channel.subscribe((s)=> {if(["SUBSCRIBED","CHANNEL_ERROR","TIMED_OUT"].includes(s)){clearTimeout(t);resolve(s);}});
      });
      check(authorized ? status === "SUBSCRIBED" : status !== "SUBSCRIBED", `private channel membership authorization: ${status}`);
      return channel;
    }
    const memberChannel=await subscribe(b,()=>received++);
    const unauthorized = await subscribe(c,()=>unauthorizedReceived++,false);
    async function publish(snapshot: typeof sharing, sequence: number, overrides = {}) {
      return await fetch(`${url}/functions/v1/phase8-group-publish`,{
        method:"POST",headers:{apikey:anon,Authorization:`Bearer ${a.auth.getSession ? (await a.auth.getSession()).data.session!.access_token : anonJwt}`,"content-type":"application/json"},
        body:JSON.stringify({groupId,membershipId:snapshot.grant.membershipId,
          publicationId:snapshot.grant.publicationId,generation:snapshot.generation,
          latitude:10,longitude:20,accuracyMeters:5,sequence,recordedAt:new Date().toISOString(),...overrides}),
      });
    }
    const published = await publish(sharing,1);
    check(published.status===200,`Edge publish status ${published.status}`);
    for(let i=0;i<20 && received===0;i++) await delay(100);
    check(received===1 && unauthorizedReceived===0,"real private Realtime delivery");
    await sql("update public.phase8_group_rollout set enabled=false;");
    check((await publish(sharing,2)).status===403,"disabled Edge publish denied");
    await subscribe(a,()=>received++,false);
    await delay(300);
    check(received===1,"open channel receives no disabled publication");
    await sql("update public.phase8_group_rollout set enabled=true;");
    await memberChannel.send({type:"broadcast",event:"location",payload:{forged:true}});
    await delay(250);
    check(received===1,"authorized member cannot bypass Edge with direct broadcast");
    const badJwt=await fetch(`${url}/functions/v1/phase8-group-publish`,{
      method:"POST",headers:{apikey:anon,Authorization:"Bearer invalid-local-test-jwt","content-type":"application/json"},body:"{}",
    });
    check(badJwt.status===401,"invalid JWT rejected");
    await unauthorized.send({type:"broadcast",event:"location",payload:{forged:true}});
    await delay(250);
    check(received===1,"direct client broadcast cannot inject");
    await command(a,"share_pause");
    check((await publish(sharing,2)).status===409,"paused old generation rejected by Edge");
    const resumed = await command(a,"share_start",{p_consent:true});
    check((await publish(resumed,1)).status===200,"new consented grant publishes");
    await delay(400);
    check(received===1,"open old authorized channel gets no new-generation locations");
    topic=`driveit:group:${groupId}:${resumed.generation}`;
    await subscribe(b,()=>received++);
    await delay(300);
    check((await publish(resumed,2)).status===200,"new channel receives resumed publication");
    await delay(300);
    check(received===2,"resumed current channel receives");
    check((await publish(resumed,3,{recordedAt:new Date(Date.now()-16000).toISOString()})).status===409,"15s stale fix rejected");
    check((await publish(resumed,3,{accuracyMeters:76})).status===409,"75m accuracy enforced");
    await command(a,"ban",{p_member_id:sharing.members.find((m:{accountId:string})=>m.accountId!==ids[0]).membershipId});
    check(await command(b,"current")===null,"ban removes snapshot access");
    const bannedRejoin=await b.rpc("phase8_group_command",{p_action:"join",p_invite_code:created.inviteCode});
    check(bannedRejoin.error?.message==="membership_banned","banned account cannot rejoin");
    check((await b.rpc("phase8_group_command",{p_action:"start",p_group_id:groupId})).error?.code==="42501","revoked member denied");
    await delay(300);
    const afterBan={...resumed,generation:(await command(a,"current")).generation};
    check((await publish(afterBan,3)).status===200,"authorized publisher survives peer ban");
    await delay(300);
    check(received===2,"banned client with open current channel gets no new locations");
    const late=await command(c,"join",{p_invite_code:created.inviteCode});
    check(late.phase==="running","late join goes directly to running");
    topic=`driveit:group:${groupId}:${late.generation}`;
    let lateReceived=0;
    await subscribe(c,()=>lateReceived++);
    await delay(300);
    check((await publish({...resumed,generation:late.generation},4)).status===200,"late member publication");
    await delay(300);
    check(lateReceived===1,"late member receives current position");
    await command(c,"leave");
    await delay(300);
    check((await publish({...resumed,generation:(await command(a,"current")).generation},5)).status===200,"publisher survives peer leave");
    await delay(300);
    check(lateReceived===1,"left member open channel receives nothing new");
    const rejoined=await command(c,"join",{p_invite_code:created.inviteCode});
    check(rejoined.phase==="running" && rejoined.members.length===2,"same invite rejoins running without duplicate membership");
    const oldMember=late.members.find((m:{accountId:string})=>m.accountId===ids[2]);
    const freshMember=rejoined.members.find((m:{accountId:string})=>m.accountId===ids[2]);
    check(freshMember.membershipId!==oldMember.membershipId && freshMember.sharingStatus==="off","new membership never inherits old grant");
    topic=`driveit:group:${groupId}:${rejoined.generation}`;
    let rejoinReceived=0;
    await subscribe(c,()=>rejoinReceived++);
    await delay(300);
    check((await publish({...resumed,generation:rejoined.generation},6)).status===200,"publish after rejoin");
    await delay(300);
    check(rejoinReceived===1 && lateReceived===1,"new channel receives while old left channel stays revoked");
    await command(c,"leave");
    // Real concurrent joins exercise the group-row lock and colour allocation.
    const candidates: SupabaseClient[]=[];
    for(let i=0;i<10;i++){
      const email=`capacity-${crypto.randomUUID()}@example.invalid`,password=`Local-${crypto.randomUUID()}!`;
      const user=await admin.auth.admin.createUser({email,password,email_confirm:true});
      check(!user.error && user.data.user,"create capacity account"); ids.push(user.data.user!.id);
      const peer=client(anon,anonJwt); clients.push(peer); candidates.push(peer);
      check(!(await peer.auth.signInWithPassword({email,password})).error,"capacity login");
    }
    const joins=await Promise.all(candidates.map(peer=>peer.rpc("phase8_group_command",{
      p_action:"join",p_invite_code:created.inviteCode})));
    check(joins.filter(r=>!r.error).length===9,"exactly nine concurrent seats granted");
    check(joins.filter(r=>r.error?.message==="group_full").length===1,"eleventh member rejected");
    const full=await command(a,"current");
    check(new Set(full.members.map((m:{colorIndex:number})=>m.colorIndex)).size===10,"ten distinct server colors");
    await command(a,"end");
    check(await command(a,"current")===null,"end removes active membership");
    check((await publish(resumed,6)).status===409,"ended publication remains revoked");
  } finally {
    await sql("update public.phase8_group_rollout set enabled=false;");
    for(const {client,channel} of channels) await client.removeChannel(channel);
    for(const c of clients) await c.removeAllChannels();
    if(groupId && /^[0-9a-f-]{36}$/.test(groupId)) {
      // Exact synthetic group created in this test only; never reset the stack.
      const sql=`begin; delete from public.phase8_group_memberships where group_id='${groupId}'; delete from public.phase8_groups where id='${groupId}'; commit;`;
      const result=await new Deno.Command("docker",{args:["exec",container,"psql","-U","postgres","-d","postgres","-v","ON_ERROR_STOP=1","-c",sql],stdout:"piped",stderr:"piped"}).output();
      check(result.success,"synthetic group cleanup");
    }
    for(const id of ids) check(!(await admin.auth.admin.deleteUser(id)).error,"synthetic account cleanup");
  }
});
