param([switch]$Resume)
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
$root = Join-Path $env:LOCALAPPDATA 'DriveIt\Recovery\R6B3-DEV-20261103-013444-8089709d'
$descriptor = Get-Content -LiteralPath (Join-Path $root 'r6b4-http-descriptor.json') -Raw | ConvertFrom-Json
if ($descriptor.name -notmatch '^pgr6a-[a-f0-9]{10}$' -or $descriptor.work -cne ('tmp/' + $descriptor.name)) { throw 'Invalid isolated stack descriptor.' }
$journalExists = Test-Path -LiteralPath (Join-Path $root 'r6b4-http-journal.dpapi')
if ($journalExists -and !$Resume) { throw 'Existing encrypted journal must be reviewed before another test.' }
if (!$journalExists -and $Resume) { throw 'No encrypted journal is available to resume.' }
$containers = @(docker ps --filter ('label=com.supabase.stack=' + $descriptor.id) --filter 'label=com.supabase.service=database' --format '{{.Names}}')
if ($containers.Count -ne 1 -or !$containers[0].StartsWith('supabase-' + $descriptor.name + '-' + $descriptor.name + '-database-')) { throw 'Ambiguous isolated database.' }
$system = docker exec $containers[0] psql -U postgres -d postgres -X -At -c 'select system_identifier from pg_control_system();'
if ($LASTEXITCODE -ne 0 -or $system -cne $descriptor.system) { throw 'Physical database identity mismatch.' }
$previous = @{}
try {
  $env:SUPABASE_EXPERIMENTAL_STACK = '1'
  $env:SUPABASE_TELEMETRY_DISABLED = '1'
  $status = (& npx --no-install supabase@2.120.0 stack status --stack-id $descriptor.id --workdir $descriptor.work --output-format json) | ConvertFrom-Json
  if ($LASTEXITCODE -ne 0 -or $status.identity.id -cne $descriptor.id) { throw 'Stack identity verification failed.' }
  $uri = [uri]$status.env.API_URL
  if ($uri.Scheme -cne 'http' -or $uri.Host -cne '127.0.0.1') { throw 'Nonlocal endpoint rejected.' }
  $values = @{R6B4_URL=$status.env.API_URL; R6B4_ANON=$status.env.ANON_KEY; R6B4_SERVICE=$status.env.SERVICE_ROLE_KEY; R6B4_CONTAINER=$containers[0]; R6B4_SYSTEM=$system; R6B4_STACK=$descriptor.name; R6B4_RESUME=$Resume.IsPresent.ToString().ToLowerInvariant()}
  foreach ($key in $values.Keys) { $previous[$key] = [Environment]::GetEnvironmentVariable($key); [Environment]::SetEnvironmentVariable($key,$values[$key]) }
  & 'C:\Users\PC\.deno\bin\deno.exe' test --allow-env --allow-net --allow-run=docker,pwsh tool/r6b4_http_test.ts
  if ($LASTEXITCODE -ne 0) { throw 'Isolated HTTP acceptance failed; encrypted fixture journal retained.' }
} finally {
  foreach ($key in $previous.Keys) { [Environment]::SetEnvironmentVariable($key,$previous[$key]) }
}
