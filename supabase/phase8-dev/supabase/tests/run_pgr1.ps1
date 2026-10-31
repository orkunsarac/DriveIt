$ErrorActionPreference = 'Stop'
$env:SUPABASE_EXPERIMENTAL_STACK = '1'
$pgrWorkdir = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$pgrStatus = (& npx --no-install supabase@2.120.0 stack status --stack 'pgr1-44f7398d' --workdir $pgrWorkdir --output-format json) | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $pgrStatus.env.API_URL -ne 'http://127.0.0.1:24471') { throw 'P-GR1 API mismatch' }
$pgrContainers = @(docker ps --format '{{.Names}}' | Where-Object { $_ -match '^supabase-phase8-dev-pgr1-44f7398d-database-[a-f0-9]+$' })
if ($pgrContainers.Count -ne 1) { throw 'Ambiguous P-GR1 database' }
$pgrContainer = $pgrContainers[0]
$pgrMount = docker inspect --format '{{range .Mounts}}{{if eq .Destination "/var/lib/postgresql/data"}}{{.Name}}{{end}}{{end}}' $pgrContainer
if ($pgrMount -ne 'supabase-db-8be209d2ef18cfad45c272ec67764692') { throw 'P-GR1 volume mismatch' }
foreach ($pgrFile in @('phase8_m4_server_gate.sql','phase8_m4_group_drive.sql','phase8_m4_group_lobby.sql','phase8_m4_group_rejoin.sql')) {
  $pgrSql = Get-Content -Raw (Join-Path $PSScriptRoot $pgrFile)
  if ($pgrFile -ne 'phase8_m4_server_gate.sql') {
    $pgrSql = $pgrSql -replace '^begin;', 'begin; create extension if not exists pgtap with schema extensions; update public.phase8_group_rollout set enabled=true;'
  }
  $pgrOutput = $pgrSql | docker exec -i $pgrContainer psql -U postgres -d postgres -X -v ON_ERROR_STOP=1
  if ($LASTEXITCODE -ne 0 -or ($pgrOutput -match 'not ok|Looks like')) { throw "SQL failure: $pgrFile" }
  $pgrCount = @($pgrOutput | Where-Object { $_ -match '^\s*ok \d+' }).Count
  "$pgrFile : $pgrCount passed"
}
$pgrEnvNames = @('PHASE8_TEST_STACK','PHASE8_TEST_DB_CONTAINER','PHASE8_LOCAL_URL','PHASE8_LOCAL_ANON_KEY','PHASE8_LOCAL_ANON_BEARER','PHASE8_LOCAL_SERVICE_ROLE_KEY','PHASE8_LOCAL_SERVICE_ROLE_BEARER')
$pgrOldEnv = @{}
foreach ($pgrName in $pgrEnvNames) { $pgrOldEnv[$pgrName] = [Environment]::GetEnvironmentVariable($pgrName) }
try {
  $env:PHASE8_TEST_STACK = 'pgr1-44f7398d'
  $env:PHASE8_TEST_DB_CONTAINER = $pgrContainer
  $env:PHASE8_LOCAL_URL = $pgrStatus.env.API_URL
  $env:PHASE8_LOCAL_ANON_KEY = $pgrStatus.env.ANON_KEY
  $env:PHASE8_LOCAL_ANON_BEARER = $pgrStatus.env.ANON_KEY
  $env:PHASE8_LOCAL_SERVICE_ROLE_KEY = $pgrStatus.env.SERVICE_ROLE_KEY
  $env:PHASE8_LOCAL_SERVICE_ROLE_BEARER = $pgrStatus.env.SERVICE_ROLE_KEY
  & 'C:\Users\PC\.deno\bin\deno.exe' test --allow-env --allow-net --allow-run=docker (Join-Path $PSScriptRoot 'phase8_m4_lobby_realtime_test.ts')
  if ($LASTEXITCODE -ne 0) { throw 'Deno integration failed' }
} finally {
  foreach ($pgrName in $pgrEnvNames) { [Environment]::SetEnvironmentVariable($pgrName, $pgrOldEnv[$pgrName]) }
}
