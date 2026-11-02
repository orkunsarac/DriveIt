param([switch]$Initialize,[switch]$BootstrapEmpty,[switch]$PrepareOnly,[switch]$RestartLocal,[switch]$SupportTest,[string]$Filter='',
 [ValidateSet('test','once','status','retry')][string]$WorkerMode='test',[string]$ReviewJob='')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Push-Location (Join-Path $PSScriptRoot '..')
$saved=@{}
$savedWorker=[Environment]::GetEnvironmentVariable('ACCOUNT_DELETION_WORKER_TOKEN')
function Set-LocalWorkerEnvironment([string]$work){
 if($work -notmatch '^tmp/pgr6a-[0-9a-f]{10}$'){throw 'Wrong worker workspace'}
 Set-Content ($work+'/.gitignore') '*'
 $path=$work+'/supabase/functions/.env'
 if(!(Test-Path -LiteralPath $path)){
  $bytes=New-Object byte[] 32;$rng=[Security.Cryptography.RandomNumberGenerator]::Create();try{$rng.GetBytes($bytes)}finally{$rng.Dispose()}
  $workerHex=[BitConverter]::ToString($bytes).Replace('-','').ToLowerInvariant()
  [IO.File]::WriteAllText((Join-Path (Get-Location) $path),'ACCOUNT_DELETION_WORKER_TOKEN='+$workerHex)
 }
 $env:ACCOUNT_DELETION_WORKER_TOKEN=((Get-Content $path -Raw)-split '=',2)[1].Trim()
 $config=$work+'/supabase/config.toml';$text=Get-Content $config -Raw
 if($text -notmatch '\[edge_runtime.secrets\]'){Add-Content $config "`n[edge_runtime.secrets]`nACCOUNT_DELETION_WORKER_TOKEN = `"env(ACCOUNT_DELETION_WORKER_TOKEN)`""}
}
function Get-PostgresDataIdentity([string]$containerName){
 $raw=docker inspect --format '{{json .HostConfig.Mounts}}' $containerName
 if($LASTEXITCODE -ne 0){throw 'Database mount inspection failed'}
 $targetCount=([regex]::Matches($raw,'"Target":"/var/lib/postgresql/data"')).Count
 $sourceMatch=[regex]::Match($raw,'"Source":"([^"]+)","Target":"/var/lib/postgresql/data"')
 $subpathMatch=[regex]::Match($raw,'"Target":"/var/lib/postgresql/data","VolumeOptions":\{"Subpath":"([^"]+)"\}')
 if($targetCount -ne 1 -or !$sourceMatch.Success){throw 'PostgreSQL data mount is ambiguous'}
 $subpath='';if($subpathMatch.Success){$subpath=$subpathMatch.Groups[1].Value}
 return $sourceMatch.Groups[1].Value+'|'+$subpath
}
try {
 $env:SUPABASE_EXPERIMENTAL_STACK='1'
 if($Initialize){
  $name='pgr6a-'+[guid]::NewGuid().ToString('N').Substring(0,10)
  $work='tmp/'+$name
  New-Item -ItemType Directory -Path "$work/supabase/functions" -Force|Out-Null
  $config=(Get-Content supabase/prod/config.toml -Raw) -replace 'project_id = "driveit-prod-reviewed-bundle"',('project_id = "'+$name+'"')
  $config+="`n[db.migrations]`nenabled = false`n[auth]`nenable_signup = false`n"
  Set-Content "$work/supabase/config.toml" $config -Encoding utf8
  $manifest=Get-Content supabase/prod/preparation_manifest.json -Raw|ConvertFrom-Json
  foreach($entry in $manifest.files){if($entry.path -match '^supabase/(?:phase8-dev/supabase/)?functions/(.+)$'){
   $dest="$work/supabase/functions/"+$Matches[1];New-Item -ItemType Directory -Path (Split-Path $dest) -Force|Out-Null;Copy-Item $entry.path $dest
  }}
  New-Item -ItemType Directory "$work/supabase/functions/delete-account" -Force|Out-Null
  Copy-Item supabase/functions/delete-account/index.ts "$work/supabase/functions/delete-account/index.ts"
  Copy-Item supabase/functions/delete-account/planet_rebuild.ts "$work/supabase/functions/delete-account/planet_rebuild.ts"
  Set-LocalWorkerEnvironment $work
  $raw=& npx --no-install supabase@2.120.0 stack start --stack $name --workdir $work --eager --output-format json
  if($LASTEXITCODE -ne 0){throw 'New isolated stack startup failed'}
  $state=$raw|ConvertFrom-Json
  $descriptor=[pscustomobject]@{name=$name;work=$work;id=$state.id}
  $descriptor|ConvertTo-Json|Set-Content tmp/pgr6a-target.json
 }else{
  $descriptor=Get-Content tmp/pgr6a-target.json -Raw|ConvertFrom-Json
  if($descriptor.name -notmatch '^pgr6a-[0-9a-f]{10}$' -or $descriptor.work -cne ('tmp/'+$descriptor.name)){throw 'Wrong local descriptor'}
  Set-LocalWorkerEnvironment $descriptor.work
  $state=(& npx --no-install supabase@2.120.0 stack status --stack-id $descriptor.id --workdir $descriptor.work --output-format json)|ConvertFrom-Json
  if($LASTEXITCODE -ne 0){throw 'Isolated stack unavailable'}
  if($state.identity.id -cne $descriptor.id -or $state.identity.name -cne $descriptor.name){throw 'Stack status identity mismatch'}
 }
 $url=[uri]$state.env.API_URL;$db=[uri]$state.env.DB_URL
 if($url.Scheme -cne 'http' -or $url.Host -cne '127.0.0.1' -or $db.Host -cne '127.0.0.1'){throw 'Non-loopback target'}
 $containers=@(docker ps --format '{{.Names}}'|Where-Object {$_ -match ('^supabase-'+[regex]::Escape($descriptor.name)+'-'+[regex]::Escape($descriptor.name)+'-database-[a-f0-9]+$')})
 if($containers.Count -ne 1){throw 'Ambiguous deletion test DB'}
 $container=$containers[0]
 $mount=Get-PostgresDataIdentity $container
 if(!$mount -or !$mount.Contains('|')){throw 'Physical isolation mismatch'}
 foreach($other in @(docker ps --format '{{.Names}}'|Where-Object {$_ -match 'database-' -and $_ -ne $container})){
  $otherMount=Get-PostgresDataIdentity $other
  if($mount -ceq $otherMount){throw 'Shared physical PGDATA'}
 }
 $system=docker exec $container psql -U postgres -d postgres -X -At -c 'select system_identifier from pg_control_system();'
 if($LASTEXITCODE -ne 0 -or $system -notmatch '^\d+$' -or $system -in @('7702818118349594665','7702837359395967017','7702852553093967913')){throw 'Cluster identity mismatch'}
 if($descriptor.PSObject.Properties['system']){if($descriptor.system -cne $system -or $descriptor.subpath -cne $mount){throw 'Pinned cluster changed'}}
 else{$descriptor|Add-Member -NotePropertyName system -NotePropertyValue $system;$descriptor|Add-Member -NotePropertyName subpath -NotePropertyValue $mount;$descriptor|ConvertTo-Json|Set-Content tmp/pgr6a-target.json}
 if($RestartLocal){
  if($Initialize -or $BootstrapEmpty){throw 'Restart cannot initialize or bootstrap'}
  $previousApi=$state.env.API_URL
  $raw=& npx --no-install supabase@2.120.0 stack restart --stack-id $descriptor.id --workdir $descriptor.work --output-format json
  if($LASTEXITCODE -ne 0){throw 'Targeted local stack restart failed'}
  $state=(& npx --no-install supabase@2.120.0 stack status --stack-id $descriptor.id --workdir $descriptor.work --output-format json)|ConvertFrom-Json
  if($LASTEXITCODE -ne 0){throw 'Restart status unavailable'}
  if($state.identity.id -cne $descriptor.id -or $state.identity.name -cne $descriptor.name -or $state.env.API_URL -cne $previousApi){throw 'Restart changed target identity/endpoints'}
  $matches=@(docker ps --format '{{.Names}}'|Where-Object {$_ -match ('^supabase-'+[regex]::Escape($descriptor.name)+'-'+[regex]::Escape($descriptor.name)+'-database-[a-f0-9]+$')})
  if($matches.Count -ne 1){throw 'Restart DB ambiguous'};$container=$matches[0]
  $restartedMount=Get-PostgresDataIdentity $container
  $restartedSystem=docker exec $container psql -U postgres -d postgres -X -At -c 'select system_identifier from pg_control_system();'
  if($LASTEXITCODE -ne 0 -or $restartedMount -cne $descriptor.subpath -or $restartedSystem -cne $descriptor.system){throw 'Restart physical identity changed'}
  'Local isolated stack restarted; pinned PGDATA/system identity preserved'
 }
 if($Initialize -or $BootstrapEmpty){
  $empty=docker exec $container psql -U postgres -d postgres -X -At -c "select (select count(*) from auth.users)+(select count(*) from pg_class where relnamespace='public'::regnamespace and relkind='r');"
  if($empty -cne '0'){throw 'New stack not empty'}
  $bundle='tmp/'+$descriptor.name+'-baseline.sql'
  & 'C:\Users\PC\.deno\bin\deno.exe' run --allow-read --allow-write=tmp tool/build_prod_transaction.ts $bundle
  if($LASTEXITCODE -ne 0){throw 'Baseline builder failed'}
  Get-Content $bundle -Raw|docker exec -i $container psql -U postgres -d postgres -X -q -v ON_ERROR_STOP=1|Out-Null
  if($LASTEXITCODE -ne 0){throw 'Local baseline failed'}
 }
 # An unapplied forward candidate is explicit; never reset or replay it on an existing schema.
 $installed=docker exec $container psql -U postgres -d postgres -X -At -c "select to_regclass('public.account_deletion_jobs') is not null;"
 if($installed -ceq 'f'){
  Get-Content supabase/account-deletion/migrations/202611010001_account_deletion.sql -Raw|docker exec -i $container psql -U postgres -d postgres -X -q -v ON_ERROR_STOP=1|Out-Null
  if($LASTEXITCODE -ne 0){throw 'Local deletion migration failed'}
 }
 $auditInstalled=docker exec $container psql -U postgres -d postgres -X -At -c "select to_regclass('public.account_deletion_events') is not null;"
 if($auditInstalled -ceq 'f'){
  Get-Content supabase/account-deletion/migrations/202611010002_account_deletion_audit.sql -Raw|docker exec -i $container psql -U postgres -d postgres -X -q -v ON_ERROR_STOP=1|Out-Null
  if($LASTEXITCODE -ne 0){throw 'Local deletion audit migration failed'}
 }
 $subjectInstalled=docker exec $container psql -U postgres -d postgres -X -At -c "select position('not exists(select 1 from auth.users' in pg_get_functiondef('public.account_deletion_active(uuid)'::regprocedure))>0;"
 if($subjectInstalled -ceq 'f'){
  Get-Content supabase/account-deletion/migrations/202611010003_account_deletion_revoked_subject.sql -Raw|docker exec -i $container psql -U postgres -d postgres -X -q -v ON_ERROR_STOP=1|Out-Null
  if($LASTEXITCODE -ne 0){throw 'Local subject fencing migration failed'}
 }
 $recoveryInstalled=docker exec $container psql -U postgres -d postgres -X -At -c "select to_regprocedure('public.account_deletion_worker_jobs()') is not null;"
 if($recoveryInstalled -ceq 'f'){
  Get-Content supabase/account-deletion/migrations/202611010004_account_deletion_recovery.sql -Raw|docker exec -i $container psql -U postgres -d postgres -X -q -v ON_ERROR_STOP=1|Out-Null
  if($LASTEXITCODE -ne 0){throw 'Local recovery migration failed'}
 }
 $generationPrivacy=docker exec $container psql -U postgres -d postgres -X -At -c "select position('generation::text,created_at=clock_timestamp()' in pg_get_functiondef('public.account_deletion_purge(uuid,uuid)'::regprocedure))>0;"
 if($generationPrivacy -ceq 'f'){
  Get-Content supabase/account-deletion/migrations/202611010005_account_deletion_generation_privacy.sql -Raw|docker exec -i $container psql -U postgres -d postgres -X -q -v ON_ERROR_STOP=1|Out-Null
  if($LASTEXITCODE -ne 0){throw 'Local generation privacy migration failed'}
 }
 $lockOrder=docker exec $container psql -U postgres -d postgres -X -At -c "select position('where id=p_id and owner_id=v and lease=p_lease' in pg_get_functiondef('public.account_deletion_purge(uuid,uuid)'::regprocedure))>0;"
 if($lockOrder -ceq 'f'){
  Get-Content supabase/account-deletion/migrations/202611010006_account_deletion_lock_order.sql -Raw|docker exec -i $container psql -U postgres -d postgres -X -q -v ON_ERROR_STOP=1|Out-Null
  if($LASTEXITCODE -ne 0){throw 'Local lock-order migration failed'}
 }
 $planetFence=docker exec $container psql -U postgres -d postgres -X -At -c "select to_regprocedure('public.account_deletion_planet_write_fence()') is not null;"
 if($planetFence -ceq 'f'){
  Get-Content supabase/account-deletion/migrations/202611010007_account_deletion_planet_serialization.sql -Raw|docker exec -i $container psql -U postgres -d postgres -X -q -v ON_ERROR_STOP=1|Out-Null
  if($LASTEXITCODE -ne 0){throw 'Local Planet serialization migration failed'}
 }
 $provenance=docker exec $container psql -U postgres -d postgres -X -At -c "select position('storage_ownership_conflict' in pg_get_functiondef('public.account_deletion_objects(uuid,uuid)'::regprocedure))>0;"
 if($provenance -ceq 'f'){
  Get-Content supabase/account-deletion/migrations/202611010008_account_deletion_storage_provenance.sql -Raw|docker exec -i $container psql -U postgres -d postgres -X -q -v ON_ERROR_STOP=1|Out-Null
  if($LASTEXITCODE -ne 0){throw 'Local Storage provenance migration failed'}
 }
 $authLifecycle=docker exec $container psql -U postgres -d postgres -X -At -c "select to_regprocedure('public.account_deletion_erase_auth_residue(uuid,text)') is not null;"
 if($authLifecycle -ceq 'f'){
  Get-Content supabase/account-deletion/migrations/202611010009_account_deletion_auth_lifecycle.sql -Raw|docker exec -i $container psql -U postgres -d postgres -X -q -v ON_ERROR_STOP=1|Out-Null
  if($LASTEXITCODE -ne 0){throw 'Local Auth lifecycle migration failed'}
 }
 $worldOrder=docker exec $container psql -U postgres -d postgres -X -At -c "select position('for update' in pg_get_functiondef('public.account_deletion_planet_write_fence()'::regprocedure))>0;"
 if($worldOrder -ceq 'f'){
  Get-Content supabase/account-deletion/migrations/202611010010_account_deletion_world_lock_order.sql -Raw|docker exec -i $container psql -U postgres -d postgres -X -q -v ON_ERROR_STOP=1|Out-Null
  if($LASTEXITCODE -ne 0){throw 'Local world lock-order migration failed'}
 }
 $memberRevocation=docker exec $container psql -U postgres -d postgres -X -At -c "select position('where administrator_id<>p_owner' in pg_get_functiondef('public.account_deletion_request(uuid,uuid,text)'::regprocedure))>0;"
 if($memberRevocation -ceq 'f'){
  Get-Content supabase/account-deletion/migrations/202611010011_account_deletion_group_member_revocation.sql -Raw|docker exec -i $container psql -U postgres -d postgres -X -q -v ON_ERROR_STOP=1|Out-Null
  if($LASTEXITCODE -ne 0){throw 'Local member revocation migration failed'}
 }
 $planetRebuild=docker exec $container psql -U postgres -d postgres -X -At -c "select to_regprocedure('public.account_deletion_planet_context(uuid,uuid)') is not null;"
 if($LASTEXITCODE -ne 0){throw 'Local Planet rebuild preflight failed'}
 if($planetRebuild -ceq 'f'){
  Get-Content supabase/account-deletion/migrations/202611010012_account_deletion_planet_rebuild.sql -Raw|docker exec -i $container psql -U postgres -d postgres -X -q -v ON_ERROR_STOP=1|Out-Null
  if($LASTEXITCODE -ne 0){throw 'Local Planet rebuild migration failed'}
 }
 $planAliases=docker exec $container psql -U postgres -d postgres -X -At -c "select position('left_trace' in pg_get_functiondef('public.account_deletion_planet_commit(uuid,uuid,text,jsonb)'::regprocedure))>0;"
 if($LASTEXITCODE -ne 0){throw 'Local plan alias preflight failed'}
 if($planAliases -ceq 'f'){
  Get-Content supabase/account-deletion/migrations/202611010013_account_deletion_planet_plan_alias.sql -Raw|docker exec -i $container psql -U postgres -d postgres -X -q -v ON_ERROR_STOP=1|Out-Null
  if($LASTEXITCODE -ne 0){throw 'Local plan alias migration failed'}
 }
 $insertAlias=docker exec $container psql -U postgres -d postgres -X -At -c "select position('projected' in pg_get_functiondef('public.account_deletion_planet_commit(uuid,uuid,text,jsonb)'::regprocedure))>0;"
 if($LASTEXITCODE -ne 0){throw 'Local insert alias preflight failed'}
 if($insertAlias -ceq 'f'){
  Get-Content supabase/account-deletion/migrations/202611010014_account_deletion_planet_insert_alias.sql -Raw|docker exec -i $container psql -U postgres -d postgres -X -q -v ON_ERROR_STOP=1|Out-Null
  if($LASTEXITCODE -ne 0){throw 'Local insert alias migration failed'}
 }
 $ownerProof=docker exec $container psql -U postgres -d postgres -X -At -c "select position('road.user_id<>publication.user_id' in pg_get_functiondef('public.account_deletion_planet_context(uuid,uuid)'::regprocedure))>0;"
 if($LASTEXITCODE -ne 0){throw 'Local owner proof preflight failed'}
 if($ownerProof -ceq 'f'){
  Get-Content supabase/account-deletion/migrations/202611010015_account_deletion_planet_owner_proof.sql -Raw|docker exec -i $container psql -U postgres -d postgres -X -q -v ON_ERROR_STOP=1|Out-Null
  if($LASTEXITCODE -ne 0){throw 'Local owner proof migration failed'}
 }
 $derivedHistory=docker exec $container psql -U postgres -d postgres -X -At -c "select position('delete from public.world_active_world_traces' in pg_get_functiondef('public.account_deletion_planet_commit(uuid,uuid,text,jsonb)'::regprocedure))>0;"
 if($LASTEXITCODE -ne 0){throw 'Local derived history preflight failed'}
 if($derivedHistory -ceq 'f'){
  Get-Content supabase/account-deletion/migrations/202611010016_account_deletion_planet_derived_history.sql -Raw|docker exec -i $container psql -U postgres -d postgres -X -q -v ON_ERROR_STOP=1|Out-Null
  if($LASTEXITCODE -ne 0){throw 'Local derived history migration failed'}
 }
 $historyBound=docker exec $container psql -U postgres -d postgres -X -At -c "select position('where active_from_generation<=g;' in pg_get_functiondef('public.account_deletion_planet_commit(uuid,uuid,text,jsonb)'::regprocedure))>0;"
 if($LASTEXITCODE -ne 0){throw 'Local history bound preflight failed'}
 if($historyBound -ceq 'f'){
  Get-Content supabase/account-deletion/migrations/202611010017_account_deletion_planet_history_bound.sql -Raw|docker exec -i $container psql -U postgres -d postgres -X -q -v ON_ERROR_STOP=1|Out-Null
  if($LASTEXITCODE -ne 0){throw 'Local history bound migration failed'}
 }
 foreach($entry in @(
  @('public.account_deletion_worker_claim(uuid)','202611010018_account_deletion_worker_queue.sql'),
  @('public.account_deletion_replay_load(uuid,uuid)','202611010019_account_deletion_replay_checkpoints.sql'),
  @('public.account_deletion_planet_hidden_roads()','202611010020_account_deletion_read_scope.sql')
 )){
  $installed=docker exec $container psql -U postgres -d postgres -X -At -c ("select to_regprocedure('"+$entry[0]+"') is not null;")
  if($LASTEXITCODE -ne 0){throw 'P-GR6C migration preflight failed'}
  if($installed -ceq 'f'){
   Get-Content ('supabase/account-deletion/migrations/'+$entry[1]) -Raw|docker exec -i $container psql -U postgres -d postgres -X -q -v ON_ERROR_STOP=1|Out-Null
   if($LASTEXITCODE -ne 0){throw ('Local P-GR6C migration failed: '+$entry[1])}
  }
 }
 $scopeDomain=docker exec $container psql -U postgres -d postgres -X -At -c "select position('179.98' in pg_get_functiondef('public.account_deletion_planet_hidden_roads()'::regprocedure))>0;"
 if($LASTEXITCODE -ne 0){throw 'Scope domain preflight failed'}
 if($scopeDomain -ceq 'f'){
  Get-Content supabase/account-deletion/migrations/202611010021_account_deletion_scope_domain.sql -Raw|docker exec -i $container psql -U postgres -d postgres -X -q -v ON_ERROR_STOP=1|Out-Null
  if($LASTEXITCODE -ne 0){throw 'Local scope domain migration failed'}
 }
 $crashBudget=docker exec $container psql -U postgres -d postgres -X -At -c "select exists(select 1 from information_schema.columns where table_schema='public' and table_name='account_deletion_jobs' and column_name='lease_expirations');"
 if($LASTEXITCODE -ne 0){throw 'Crash budget preflight failed'}
 if($crashBudget -ceq 'f'){
  Get-Content supabase/account-deletion/migrations/202611010022_account_deletion_crash_budget.sql -Raw|docker exec -i $container psql -U postgres -d postgres -X -q -v ON_ERROR_STOP=1|Out-Null
  if($LASTEXITCODE -ne 0){throw 'Local crash budget migration failed'}
 }
 $scopeBudget=docker exec $container psql -U postgres -d postgres -X -At -c "select position('limit 129' in pg_get_functiondef('public.account_deletion_planet_hidden_roads()'::regprocedure))>0;"
 if($LASTEXITCODE -ne 0){throw 'Scope budget preflight failed'}
 if($scopeBudget -ceq 'f'){
  Get-Content supabase/account-deletion/migrations/202611010023_account_deletion_scope_budget.sql -Raw|docker exec -i $container psql -U postgres -d postgres -X -q -v ON_ERROR_STOP=1|Out-Null
  if($LASTEXITCODE -ne 0){throw 'Local scope budget migration failed'}
 }
 $scopeRelevance=docker exec $container psql -U postgres -d postgres -X -At -c "select position('r.user_id=j.owner_id)))' in pg_get_functiondef('public.account_deletion_planet_hidden_roads()'::regprocedure))>0;"
 if($LASTEXITCODE -ne 0){throw 'Scope relevance preflight failed'}
 if($scopeRelevance -ceq 'f'){
  Get-Content supabase/account-deletion/migrations/202611010024_account_deletion_scope_relevance.sql -Raw|docker exec -i $container psql -U postgres -d postgres -X -q -v ON_ERROR_STOP=1|Out-Null
  if($LASTEXITCODE -ne 0){throw 'Local scope relevance migration failed'}
 }
 $durableAudit=docker exec $container psql -U postgres -d postgres -X -At -c "select to_regclass('public.account_deletion_erasure_audit') is not null;"
 if($LASTEXITCODE -ne 0){throw 'Durable audit migration preflight failed'}
 if($durableAudit -ceq 'f'){
  Get-Content supabase/account-deletion/migrations/202611010025_account_deletion_retention_audit.sql -Raw|docker exec -i $container psql -U postgres -d postgres -X -q -v ON_ERROR_STOP=1|Out-Null
  if($LASTEXITCODE -ne 0){throw 'Local durable audit migration failed'}
 }
 $roadVersion=docker exec $container psql -U postgres -d postgres -X -At -c "select position('r.processing_version<>3' in pg_get_functiondef('public.account_deletion_planet_context(uuid,uuid)'::regprocedure))>0;"
 if($LASTEXITCODE -ne 0){throw 'Deletion road-version preflight failed'}
 if($roadVersion -ceq 'f'){
  Get-Content supabase/account-deletion/migrations/202611020001_account_deletion_road_version.sql -Raw|docker exec -i $container psql -U postgres -d postgres -X -q -v ON_ERROR_STOP=1|Out-Null
  if($LASTEXITCODE -ne 0){throw 'Local deletion road-version correction failed'}
 }
 $generationVersion=docker exec $container psql -U postgres -d postgres -X -At -c "select position('''accountDeletion'',1,3,jsonb_array_length' in pg_get_functiondef('public.account_deletion_planet_commit(uuid,uuid,text,jsonb)'::regprocedure))>0;"
 if($LASTEXITCODE -ne 0){throw 'Deletion generation-version preflight failed'}
 if($generationVersion -ceq 'f'){
  Get-Content supabase/account-deletion/migrations/202611020002_account_deletion_generation_version.sql -Raw|docker exec -i $container psql -U postgres -d postgres -X -q -v ON_ERROR_STOP=1|Out-Null
  if($LASTEXITCODE -ne 0){throw 'Local deletion generation-version correction failed'}
 }
 Get-Content supabase/account-deletion/tests/audit_retention.sql -Raw|docker exec -i $container psql -U postgres -d postgres -X -q -v ON_ERROR_STOP=1
 if($LASTEXITCODE -ne 0){throw 'Local durable audit retention acceptance failed'}
 Get-Content supabase/account-deletion/tests/planet_rebuild_security.sql -Raw|docker exec -i $container psql -U postgres -d postgres -X -q -v ON_ERROR_STOP=1
 if($LASTEXITCODE -ne 0){throw 'Local Planet RPC security acceptance failed'}
 $workerToken=$env:ACCOUNT_DELETION_WORKER_TOKEN
 # Copy only this candidate endpoint into the local workspace; no deployment command.
 Copy-Item supabase/functions/delete-account/index.ts ($descriptor.work+'/supabase/functions/delete-account/index.ts') -Force
 Copy-Item supabase/functions/delete-account/planet_rebuild.ts ($descriptor.work+'/supabase/functions/delete-account/planet_rebuild.ts') -Force
 foreach($file in @('world_scoring.generated.js','world_scoring.manifest.json')){
  Copy-Item ('supabase/functions/process-world-publish/'+$file) ($descriptor.work+'/supabase/functions/process-world-publish/'+$file) -Force
 }
 $separator=$mount.IndexOf('|');if($separator -lt 0 -or $separator -ge ($mount.Length-1)){throw 'Pinned PostgreSQL subpath unavailable'}
 $rawSubpath=$mount.Substring($separator+1)
 $values=@{PGR6_LOCAL_URL=$state.env.API_URL;PGR6_CONTAINER=$container;PGR6_SUBPATH=$rawSubpath;PGR6_SYSTEM=$system;PGR6_ANON=$state.env.ANON_KEY;PGR6_SERVICE=$state.env.SERVICE_ROLE_KEY;PGR6_WORKER_TOKEN=$workerToken;PGR6F_MAILPIT_URL='http://127.0.0.1:63124'}
 foreach($key in $values.Keys){$saved[$key]=[Environment]::GetEnvironmentVariable($key);[Environment]::SetEnvironmentVariable($key,$values[$key])}
 if($PrepareOnly){'Isolated deletion test environment prepared; credentials suppressed';return}
 if($WorkerMode -cne 'test'){
  $action=switch($WorkerMode){'once'{'worker'}'status'{'worker_status'}'retry'{'worker_retry'}}
  if($WorkerMode -ceq 'retry' -and $ReviewJob -notmatch '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'){throw 'Explicit local review job UUID required'}
  $body=@{action=$action};if($WorkerMode -ceq 'retry'){$body.jobId=$ReviewJob}
  $response=Invoke-WebRequest -Uri ($state.env.API_URL+'/functions/v1/delete-account') -Method Post -ContentType 'application/json' -Headers @{
   apikey=$state.env.ANON_KEY;'x-driveit-deletion-worker'=$workerToken
  } -Body ($body|ConvertTo-Json -Compress) -TimeoutSec 60 -SkipHttpErrorCheck
  if($response.StatusCode -notin @(200,202)){throw ('Local worker HTTP '+$response.StatusCode+'; credentials suppressed')}
  $result=$response.Content|ConvertFrom-Json
  foreach($property in $result.PSObject.Properties.Name){if($property -notin @('state','pending','review','jobs')){throw 'Unexpected worker response field'}}
  $result|ConvertTo-Json -Depth 5;return
 }
 $arguments=@('test','--allow-env','--allow-net','--allow-run=docker,pwsh')
 if($Filter){$arguments+=@('--filter',$Filter)}
 if($SupportTest){$arguments+='supabase/account-deletion/tests/support_operator_test.ts'}else{$arguments+='supabase/prod/tests/account_deletion_test.ts'}
 & 'C:\Users\PC\.deno\bin\deno.exe' @arguments
 if($LASTEXITCODE -ne 0){throw 'Account deletion acceptance failed'}
}finally{foreach($key in $saved.Keys){[Environment]::SetEnvironmentVariable($key,$saved[$key])};$env:ACCOUNT_DELETION_WORKER_TOKEN=$savedWorker;Pop-Location}
