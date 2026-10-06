# Two real DB transactions race ONLY in an owned synthetic schema.
# Real public pointer/traces are never touched. Schema is removed in finally.
$ErrorActionPreference='Stop'
$taskSchema='driveit_2c_race_20261006'
$taskUri='https://api.supabase.com/v1/projects/viqngnjfgknpxtoapzcg/database/query'
$taskHeaders=@{Authorization=('Bearer '+$env:SUPABASE_ACCESS_TOKEN)}
function Invoke-TestQuery([string]$query) {
  Invoke-RestMethod -Method Post -Uri $taskUri -Headers $taskHeaders -ContentType 'application/json' -Body (@{query=$query}|ConvertTo-Json -Compress)
}
$taskSetup=Get-Content -Raw (Join-Path $PSScriptRoot 'world_mutation_sql_integration.sql')
$taskMigration=Get-Content -Raw (Join-Path $PSScriptRoot '../supabase/migrations/202610060002_active_world_mutation.sql')
$taskStart=$taskMigration.IndexOf('create or replace function public.commit_active_world_mutation(')
$taskFn=$taskMigration.Substring($taskStart,$taskMigration.IndexOf('notify pgrst',$taskStart)-$taskStart)
$taskFn=$taskFn.Replace('public.world_','driveit_2c_test.world_').Replace('public.commit_active_world_mutation','driveit_2c_test.commit_active_world_mutation').Replace('driveit_2c_test.world_section_geometry_length_meters','public.world_section_geometry_length_meters')
$taskCase=(Get-Content -Raw (Join-Path $PSScriptRoot '../test/fixtures/active_world_mutation_sql.json')|ConvertFrom-Json)[0]
$taskJson=$taskCase|ConvertTo-Json -Depth 60 -Compress
$taskPrefix=$taskSetup.Substring(0,$taskSetup.IndexOf('do $test$')).Replace('/* FUNCTION */',$taskFn)
$taskSeedStart=$taskSetup.IndexOf('    truncate driveit_2c_test')
$taskSeed=$taskSetup.Substring($taskSeedStart,$taskSetup.IndexOf('    v_plan:=')-$taskSeedStart)
$taskInit=$taskPrefix + ('do $seed$ declare c jsonb := $fixture$'+$taskJson+'$fixture$::jsonb; t jsonb; r jsonb; s jsonb; v_id uuid; v_pub uuid; v_order integer; begin '+$taskSeed+' end; $seed$;')
$taskInit+=@'
insert into driveit_2c_test.world_publishes select (jsonb_populate_record(null::driveit_2c_test.world_publishes,
  to_jsonb(p)||jsonb_build_object('id','00000000-0000-4000-8000-000000000029',
    'local_drive_id','challenger2-drive','source_path','synthetic-second.json'))).*
  from driveit_2c_test.world_publishes p where id='00000000-0000-4000-8000-000000000023';
insert into driveit_2c_test.world_validated_roads select (jsonb_populate_record(null::driveit_2c_test.world_validated_roads,
  to_jsonb(p)||jsonb_build_object('id','00000000-0000-4000-8000-000000000019',
    'publish_id','00000000-0000-4000-8000-000000000029'))).*
  from driveit_2c_test.world_validated_roads p where id='00000000-0000-4000-8000-000000000013';
create function driveit_2c_test.race_commit(p_id uuid,p_plan jsonb) returns jsonb language plpgsql as $$
begin
  perform 1 from driveit_2c_test.world_active_world_state where singleton for update;
  perform pg_sleep(.5);
  return driveit_2c_test.commit_active_world_mutation(p_id,1,p_plan);
end; $$;
revoke all on function driveit_2c_test.race_commit(uuid,jsonb) from public,anon,authenticated;
commit;
'@
$taskInit=$taskInit.Replace('driveit_2c_test',$taskSchema)
$taskCreated=$false
try {
  Invoke-TestQuery $taskInit | Out-Null
  $taskCreated=$true
  $taskPlan1=$taskCase.plan|ConvertTo-Json -Depth 60 -Compress
  $taskCase.plan.operationId='world:challenger2-drive:v1'
  $taskPlan2=$taskCase.plan|ConvertTo-Json -Depth 60 -Compress
  $taskQueries=@(
    ('select '+$taskSchema+'.race_commit(''00000000-0000-4000-8000-000000000023'',$plan$'+$taskPlan1+'$plan$::jsonb) as result'),
    ('select '+$taskSchema+'.race_commit(''00000000-0000-4000-8000-000000000029'',$plan$'+$taskPlan2+'$plan$::jsonb) as result'))
  $taskClient=[System.Net.Http.HttpClient]::new()
  $taskClient.DefaultRequestHeaders.Authorization=[System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer',$env:SUPABASE_ACCESS_TOKEN)
  $taskPending=@($taskQueries|ForEach-Object {
    $taskPayload=@{query=$_}|ConvertTo-Json -Compress
    $taskContent=[System.Net.Http.StringContent]::new($taskPayload,[Text.Encoding]::UTF8,'application/json')
    $taskClient.PostAsync($taskUri,$taskContent)
  })
  $taskStates=@($taskPending|ForEach-Object {
    $taskResponse=$_.GetAwaiter().GetResult()
    $taskText=$taskResponse.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    if(-not $taskResponse.IsSuccessStatusCode){throw 'Race SQL request failed.'}
    (($taskText|ConvertFrom-Json)[0].result).state
  })
  $taskClient.Dispose()
  if(($taskStates|Where-Object {$_ -eq 'committed'}).Count -ne 1 -or ($taskStates|Where-Object {$_ -eq 'stale_generation'}).Count -ne 1){throw 'Concurrent CAS failed.'}
  Invoke-TestQuery ('select current_generation as generation, (select count(*) from '+$taskSchema+'.world_active_world_generations) as generations from '+$taskSchema+'.world_active_world_state')|ConvertTo-Json -Compress
  Write-Output ('concurrent_results='+($taskStates -join ','))
} finally {
  if($taskCreated) {
    # Exact fixed namespace just created by this test. No computed public target.
    Invoke-TestQuery 'drop schema driveit_2c_race_20261006 cascade;'|Out-Null
    Write-Output 'synthetic_race_schema_removed=true'
  }
}
