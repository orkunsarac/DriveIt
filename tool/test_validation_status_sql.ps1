# DEV-only isolated copies of the live validation RPC/tables; all DDL/DML rolls back.
param([string]$ProjectRef='viqngnjfgknpxtoapzcg')
$ErrorActionPreference='Stop'
if($ProjectRef -ne 'viqngnjfgknpxtoapzcg'){throw 'DEV-only test'}
$taskToken=$env:SUPABASE_ACCESS_TOKEN
if(-not $taskToken){$taskToken=[Environment]::GetEnvironmentVariable('SUPABASE_ACCESS_TOKEN','User')}
if(-not $taskToken){throw 'Management authentication unavailable'}
$taskDeno=Join-Path $PSScriptRoot '../tmp/supabase-cli-npm-cache/_npx/05b6ef7b13673c57/node_modules/@deno/win32-x64/deno.exe'
$taskGenerate=@'
import {matchRoad} from './supabase/functions/process-world-publish/world_validation.ts';
import {roadPayload} from './supabase/functions/process-world-publish/validation_payload.ts';
const cases=JSON.parse(await Deno.readTextFile('test/fixtures/validation_status_contract.json'));
const output=[];
for(const c of cases){const result=await matchRoad(c.route.map(([latitude,longitude])=>({latitude,longitude})),[],'synthetic',async()=>({status:200,body:JSON.stringify({code:'Ok',matchings:c.matchings.map(coordinates=>({geometry:{type:'LineString',coordinates},confidence:.9}))})}));output.push({...c,payload:roadPayload(result)});}
console.log(JSON.stringify(output));
'@
$taskFixtures=(& $taskDeno eval $taskGenerate) -join "`n"
if($LASTEXITCODE -ne 0){throw 'Synthetic payload generation failed'}
$null=$taskFixtures|ConvertFrom-Json
$taskSql=@'
begin;
set local search_path=pg_catalog,extensions,public,pg_temp;
create schema driveit_validation_status_test;
create table driveit_validation_status_test.world_publishes(like public.world_publishes including all);
create table driveit_validation_status_test.world_validated_roads(like public.world_validated_roads including all);
create table driveit_validation_status_test.world_validated_road_sections(like public.world_validated_road_sections including all);
do $$ declare def text;begin
 def:=pg_get_functiondef('public.finish_world_publish_validation(uuid,uuid,uuid,jsonb,jsonb)'::regprocedure);
 execute replace(replace(def,'public.world_','driveit_validation_status_test.world_'),'public.finish_world_publish_validation','driveit_validation_status_test.finish_world_publish_validation');
 def:=pg_get_functiondef('public.fail_world_publish_validation(uuid,uuid,uuid,boolean,text)'::regprocedure);
 execute replace(replace(def,'public.world_','driveit_validation_status_test.world_'),'public.fail_world_publish_validation','driveit_validation_status_test.fail_world_publish_validation');
end $$;
create temp table validation_status_results(name text,passed boolean);
do $$ declare c jsonb; pub uuid; usr uuid:='00000000-0000-4000-8000-000000000020';claim uuid:='00000000-0000-4000-8000-000000000030';result jsonb;idx int:=0;bad jsonb;begin
 for c in select value from jsonb_array_elements($fixtures$/* FIXTURES */$fixtures$::jsonb) loop
  idx:=idx+1;pub:=('00000000-0000-4000-8000-'||lpad(idx::text,12,'0'))::uuid;
  insert into driveit_validation_status_test.world_publishes(id,user_id,local_drive_id,started_at,ended_at,distance_meters,world_rules_version,status,validation_claim_token,validation_claimed_at)
  values(pub,usr,'synthetic-'||idx,now()-interval '1 minute',now(),7000,6,'processing',claim,now());
  result:=driveit_validation_status_test.finish_world_publish_validation(pub,usr,claim,c#>'{payload,road}',c#>'{payload,sections}');
  if result->>'state'<>'created' or (select validation_status from driveit_validation_status_test.world_validated_roads where publish_id=pub)<>c->>'persisted' then raise exception 'canonical persistence failed';end if;
  if (select count(*) from driveit_validation_status_test.world_validated_road_sections where validated_road_id=(result->>'validated_road_id')::uuid)<>jsonb_array_length(c#>'{payload,sections}') then raise exception 'section persistence failed';end if;
  result:=driveit_validation_status_test.finish_world_publish_validation(pub,usr,claim,c#>'{payload,road}',c#>'{payload,sections}');
  if result->>'state'<>'exists' then raise exception 'idempotency failed';end if;
  insert into validation_status_results values(c->>'internal'||' provider payload -> live RPC/check + idempotency',true);
 end loop;
 pub:='00000000-0000-4000-8000-000000000003';
 insert into driveit_validation_status_test.world_publishes(id,user_id,local_drive_id,started_at,ended_at,distance_meters,world_rules_version,status,validation_claim_token,validation_claimed_at)
 values(pub,usr,'synthetic-failure',now()-interval '1 minute',now(),7000,6,'processing',claim,now());
 bad:=jsonb_set(c#>'{payload,road}','{validation_status}','"partiallyValidated"');
 begin
  perform driveit_validation_status_test.finish_world_publish_validation(pub,usr,claim,bad,c#>'{payload,sections}');
  raise exception 'old camelCase unexpectedly accepted';
 exception when check_violation then null;end;
 if exists(select 1 from driveit_validation_status_test.world_validated_roads where publish_id=pub) then raise exception 'partial persistence survived failure';end if;
 if not driveit_validation_status_test.fail_world_publish_validation(pub,usr,claim,true,'validation_persist_failed') then raise exception 'claim release failed';end if;
 if not exists(select 1 from driveit_validation_status_test.world_publishes where id=pub and status='pending' and error_code='validation_persist_failed' and validation_claim_token is null) then raise exception 'retryable state failed';end if;
 insert into validation_status_results values('old camelCase rejected + atomic rollback + retryable claim release',true);
end $$;
select * from validation_status_results;
rollback;
'@
$taskSql=$taskSql.Replace('/* FIXTURES */',$taskFixtures)
try {
 $taskResult=Invoke-RestMethod -Method Post -Uri "https://api.supabase.com/v1/projects/$ProjectRef/database/query" -Headers @{Authorization=('Bearer '+$taskToken)} -ContentType 'application/json' -Body (@{query=$taskSql}|ConvertTo-Json -Compress)
 $taskResult|ConvertTo-Json -Compress
}catch{Write-Output 'Isolated validation contract test failed; transaction rolls back.';if($_.ErrorDetails.Message){try{($_.ErrorDetails.Message|ConvertFrom-Json).message}catch{}};exit 1}
