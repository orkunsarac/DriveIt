param([switch]$ApplyBootstrap)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $root
try {
  $env:SUPABASE_EXPERIMENTAL_STACK='1'
  $state=(& npx --no-install supabase@2.120.0 stack status --stack 'pgr2b-canonical-20261031' --workdir 'tmp/pgr2b-canonical' --output-format json)|ConvertFrom-Json
  if($LASTEXITCODE -ne 0 -or $state.env.API_URL -cne 'http://127.0.0.1:27773' -or ([uri]$state.env.DB_URL).Host -ne '127.0.0.1'){throw 'Wrong canonical test endpoints'}
  $containers=@(docker ps --format '{{.Names}}'|Where-Object {$_ -match '^supabase-pgr2b-canonical-pgr2b-canonical-20261031-database-[a-f0-9]+$'})
  if($containers.Count -ne 1){throw 'Ambiguous database'}
  $container=$containers[0]
  $info=(docker inspect $container|ConvertFrom-Json)[0]
  $mount=@($info.HostConfig.Mounts|Where-Object Target -eq '/var/lib/postgresql/data')[0]
  if($mount.VolumeOptions.Subpath -cne 'instance-6e5901b4a541135e72ad8a3b2810a754e5e786533c88fe9386c11285b7c86efe-f4223b3e-8b1a-4c2a-bc16-707753a33aca/data'){throw 'Wrong physical PGDATA'}
  $id=docker exec $container psql -U postgres -d postgres -X -At -c 'select system_identifier from pg_control_system();'
  if($LASTEXITCODE -ne 0 -or $id -cne '7702837359395967017'){throw 'Wrong cluster identity'}
  if($ApplyBootstrap){
    $empty=docker exec $container psql -U postgres -d postgres -X -At -c "select (select count(*) from auth.users)+(select count(*) from pg_class where relnamespace='public'::regnamespace and relkind='r');"
    if($LASTEXITCODE -ne 0 -or $empty -cne '0'){throw 'Bootstrap requires verified empty application schema and Auth'}
    $files=@(Get-ChildItem supabase/prod/bootstrap/*.sql|Sort-Object Name)+@(Get-ChildItem supabase/migrations/*.sql|Sort-Object Name)+@(Get-ChildItem supabase/phase8-dev/supabase/migrations/*.sql|Sort-Object Name)
    foreach($file in $files){
      Get-Content -Raw $file.FullName|docker exec -i $container psql -U postgres -d postgres -X -v ON_ERROR_STOP=1
      if($LASTEXITCODE -ne 0){throw ('Migration failed: '+$file.Name)}
    }
    # Explicit loopback URL is mandatory: named stacks are not selected by
    # database commands' default local target.
    $historyDirectory='tmp/pgr2b-canonical/supabase/migrations'
    New-Item -ItemType Directory -Path $historyDirectory -Force | Out-Null
    foreach($file in $files){Copy-Item -LiteralPath $file.FullName -Destination $historyDirectory}
    $versions=@($files|ForEach-Object {($_.Name -split '_')[0]})
    if(@($versions|Select-Object -Unique).Count -ne $files.Count){throw 'Migration version collision'}
    $dbUri=[uri]$state.env.DB_URL
    $localDbUrl=$state.env.DB_URL+$(if($dbUri.Query){'&sslmode=disable'}else{'?sslmode=disable'})
    & npx --no-install supabase@2.120.0 migration repair --status applied --db-url $localDbUrl --workdir tmp/pgr2b-canonical @versions
    if($LASTEXITCODE -ne 0){throw 'Local migration history registration failed'}
    $buckets=@(Get-Content -Raw supabase/prod/bootstrap/storage_buckets.json|ConvertFrom-Json)
    $buckets+=@{id='phase8-drive-staging';public=$false;file_size_limit=10485760;allowed_mime_types=$null}
    foreach($bucket in $buckets){
      $body=@{id=$bucket.id;name=$bucket.id;public=$bucket.public;file_size_limit=$bucket.file_size_limit;allowed_mime_types=$bucket.allowed_mime_types}|ConvertTo-Json
      $null=Invoke-RestMethod -Uri ($state.env.API_URL+'/storage/v1/bucket') -Method Post -Headers @{apikey=$state.env.SERVICE_ROLE_KEY;Authorization=('Bearer '+$state.env.SERVICE_ROLE_KEY)} -ContentType application/json -Body $body
    }
  }
  foreach($test in @('phase8_m4_server_gate.sql','phase8_m4_group_drive.sql','phase8_m4_group_lobby.sql','phase8_m4_group_rejoin.sql','phase8_security_contract.sql','phase8_m2_security.sql','phase8_staging_cancellation.sql')){
    $sql=Get-Content -Raw (Join-Path 'supabase/phase8-dev/supabase/tests' $test)
    $sql=$sql -replace '^begin;', 'begin; create extension if not exists pgtap with schema extensions;'
    if($test -in @('phase8_m4_group_drive.sql','phase8_m4_group_lobby.sql','phase8_m4_group_rejoin.sql')){$sql=$sql -replace '^begin;', 'begin; update public.phase8_group_rollout set enabled=true;'}
    $output=$sql|docker exec -i $container psql -U postgres -d postgres -X -v ON_ERROR_STOP=1
    if($LASTEXITCODE -ne 0 -or ($output -match 'not ok|Looks like')){throw ('SQL test failed: '+$test)}
    "$test : $(@($output|Where-Object {$_ -match '^\s*ok \d+'}).Count) passed"
  }
  $names=@('PHASE8_TEST_STACK','PHASE8_TEST_DB_CONTAINER','PHASE8_LOCAL_URL','PHASE8_LOCAL_ANON_KEY','PHASE8_LOCAL_ANON_BEARER','PHASE8_LOCAL_SERVICE_ROLE_KEY','PHASE8_LOCAL_SERVICE_ROLE_BEARER'); $old=@{}
  foreach($name in $names){$old[$name]=[Environment]::GetEnvironmentVariable($name)}
  try {
    $env:PHASE8_TEST_STACK='pgr2b-canonical-20261031'; $env:PHASE8_TEST_DB_CONTAINER=$container
    $env:PHASE8_LOCAL_URL=$state.env.API_URL; $env:PHASE8_LOCAL_ANON_KEY=$state.env.ANON_KEY; $env:PHASE8_LOCAL_ANON_BEARER=$state.env.ANON_KEY
    $env:PHASE8_LOCAL_SERVICE_ROLE_KEY=$state.env.SERVICE_ROLE_KEY; $env:PHASE8_LOCAL_SERVICE_ROLE_BEARER=$state.env.SERVICE_ROLE_KEY
    & 'C:\Users\PC\.deno\bin\deno.exe' test --allow-env --allow-net --allow-run=docker supabase/prod/tests/canonical_realtime_test.ts
    if($LASTEXITCODE -ne 0){throw 'Canonical integration failed'}
  } finally {foreach($name in $names){[Environment]::SetEnvironmentVariable($name,$old[$name])}}
} finally {Pop-Location}
