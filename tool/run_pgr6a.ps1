param([switch]$Initialize,[switch]$BootstrapEmpty,[switch]$PrepareOnly,[string]$Filter='')
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
  $bytes=New-Object byte[] 32;[Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
  [IO.File]::WriteAllText((Join-Path (Get-Location) $path),'ACCOUNT_DELETION_WORKER_TOKEN='+[Convert]::ToHexString($bytes).ToLowerInvariant())
 }
 $env:ACCOUNT_DELETION_WORKER_TOKEN=((Get-Content $path -Raw)-split '=',2)[1].Trim()
 $config=$work+'/supabase/config.toml';$text=Get-Content $config -Raw
 if($text -notmatch '\[edge_runtime.secrets\]'){Add-Content $config "`n[edge_runtime.secrets]`nACCOUNT_DELETION_WORKER_TOKEN = `"env(ACCOUNT_DELETION_WORKER_TOKEN)`""}
}
try {
 $env:SUPABASE_EXPERIMENTAL_STACK='1'
 if($Initialize){
  $name='pgr6a-'+[guid]::NewGuid().ToString('N').Substring(0,10)
  $work='tmp/'+$name
  New-Item -ItemType Directory -Path "$work/supabase/functions" -Force|Out-Null
  $config=(Get-Content supabase/prod/config.toml -Raw) -replace 'project_id = "driveit-prod-reviewed-bundle"',('project_id = "'+$name+'"')
  $config+="`n[db.migrations]`nenabled = false`n[auth]`nenable_signup = false`n[functions.delete-account]`nverify_jwt = false`n"
  Set-Content "$work/supabase/config.toml" $config -Encoding utf8
  $manifest=Get-Content supabase/prod/preparation_manifest.json -Raw|ConvertFrom-Json
  foreach($entry in $manifest.files){if($entry.path -match '^supabase/(?:phase8-dev/supabase/)?functions/(.+)$'){
   $dest="$work/supabase/functions/"+$Matches[1];New-Item -ItemType Directory -Path (Split-Path $dest) -Force|Out-Null;Copy-Item $entry.path $dest
  }}
  New-Item -ItemType Directory "$work/supabase/functions/delete-account"|Out-Null
  Copy-Item supabase/functions/delete-account/index.ts "$work/supabase/functions/delete-account/index.ts"
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
 }
 $url=[uri]$state.env.API_URL;$db=[uri]$state.env.DB_URL
 if($url.Scheme -cne 'http' -or $url.Host -cne '127.0.0.1' -or $db.Host -cne '127.0.0.1'){throw 'Non-loopback target'}
 $containers=@(docker ps --format '{{.Names}}'|Where-Object {$_ -match ('^supabase-'+[regex]::Escape($descriptor.name)+'-'+[regex]::Escape($descriptor.name)+'-database-[a-f0-9]+$')})
 if($containers.Count -ne 1){throw 'Ambiguous deletion test DB'}
 $container=$containers[0]
 $mount=docker inspect --format '{{range .HostConfig.Mounts}}{{if eq .Target "/var/lib/postgresql/data"}}{{.VolumeOptions.Subpath}}{{end}}{{end}}' $container
 if($LASTEXITCODE -ne 0 -or !$mount.StartsWith('instance-'+$descriptor.id+'-')){throw 'Physical isolation mismatch'}
 foreach($other in @(docker ps --format '{{.Names}}'|Where-Object {$_ -match 'database-' -and $_ -ne $container})){
  $otherMount=docker inspect --format '{{range .HostConfig.Mounts}}{{if eq .Target "/var/lib/postgresql/data"}}{{.VolumeOptions.Subpath}}{{end}}{{end}}' $other
  if($mount -ceq $otherMount){throw 'Shared physical PGDATA'}
 }
 $system=docker exec $container psql -U postgres -d postgres -X -At -c 'select system_identifier from pg_control_system();'
 if($LASTEXITCODE -ne 0 -or $system -notmatch '^\d+$' -or $system -in @('7702818118349594665','7702837359395967017','7702852553093967913')){throw 'Cluster identity mismatch'}
 if($descriptor.PSObject.Properties['system']){if($descriptor.system -cne $system -or $descriptor.subpath -cne $mount){throw 'Pinned cluster changed'}}
 else{$descriptor|Add-Member -NotePropertyName system -NotePropertyValue $system;$descriptor|Add-Member -NotePropertyName subpath -NotePropertyValue $mount;$descriptor|ConvertTo-Json|Set-Content tmp/pgr6a-target.json}
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
 $workerToken=$env:ACCOUNT_DELETION_WORKER_TOKEN
 # Copy only this candidate endpoint into the local workspace; no deployment command.
 Copy-Item supabase/functions/delete-account/index.ts ($descriptor.work+'/supabase/functions/delete-account/index.ts') -Force
 $values=@{PGR6_LOCAL_URL=$state.env.API_URL;PGR6_CONTAINER=$container;PGR6_SUBPATH=$mount;PGR6_SYSTEM=$system;PGR6_ANON=$state.env.ANON_KEY;PGR6_SERVICE=$state.env.SERVICE_ROLE_KEY;PGR6_WORKER_TOKEN=$workerToken}
 foreach($key in $values.Keys){$saved[$key]=[Environment]::GetEnvironmentVariable($key);[Environment]::SetEnvironmentVariable($key,$values[$key])}
 if($PrepareOnly){'Isolated deletion test environment prepared; credentials suppressed';return}
 $arguments=@('test','--allow-env','--allow-net','--allow-run=docker')
 if($Filter){$arguments+=@('--filter',$Filter)}
 $arguments+='supabase/prod/tests/account_deletion_test.ts'
 & 'C:\Users\PC\.deno\bin\deno.exe' @arguments
 if($LASTEXITCODE -ne 0){throw 'Account deletion acceptance failed'}
}finally{foreach($key in $saved.Keys){[Environment]::SetEnvironmentVariable($key,$saved[$key])};$env:ACCOUNT_DELETION_WORKER_TOKEN=$savedWorker;Pop-Location}
