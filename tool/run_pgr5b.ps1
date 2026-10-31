param([string]$Filter='')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Push-Location (Join-Path $PSScriptRoot '..')
$saved=@{}
$fixtureInstalled=$false
try {
 $env:SUPABASE_EXPERIMENTAL_STACK='1'
 $state=(& npx --no-install supabase@2.120.0 stack status --stack 'pgr2b-canonical-20261031' --workdir tmp/pgr2b-canonical --output-format json)|ConvertFrom-Json
 if($LASTEXITCODE -ne 0 -or $state.env.API_URL -cne 'http://127.0.0.1:27773' -or ([uri]$state.env.DB_URL).Host -cne '127.0.0.1'){throw 'Wrong test endpoints'}
 $containers=@(docker ps --format '{{.Names}}'|Where-Object {$_ -match '^supabase-pgr2b-canonical-pgr2b-canonical-20261031-database-[a-f0-9]+$'})
 if($containers.Count -ne 1){throw 'Ambiguous canonical DB'}
 $mount=docker inspect --format '{{range .HostConfig.Mounts}}{{if eq .Target "/var/lib/postgresql/data"}}{{.VolumeOptions.Subpath}}{{end}}{{end}}' $containers[0]
 if($LASTEXITCODE -ne 0 -or $mount -cne 'instance-6e5901b4a541135e72ad8a3b2810a754e5e786533c88fe9386c11285b7c86efe-f4223b3e-8b1a-4c2a-bc16-707753a33aca/data'){throw 'Wrong physical test PGDATA'}
 $id=docker exec $containers[0] psql -U postgres -d postgres -X -At -c 'select system_identifier from pg_control_system();'
 if($LASTEXITCODE -ne 0 -or $id -cne '7702837359395967017'){throw 'Wrong cluster identity'}
 $values=@{PHASE8_TEST_STACK='pgr2b-canonical-20261031';PHASE8_TEST_DB_CONTAINER=$containers[0];PHASE8_LOCAL_URL=$state.env.API_URL;PHASE8_LOCAL_ANON_KEY=$state.env.ANON_KEY;PHASE8_LOCAL_ANON_BEARER=$state.env.ANON_KEY;PHASE8_LOCAL_SERVICE_ROLE_KEY=$state.env.SERVICE_ROLE_KEY;PHASE8_LOCAL_SERVICE_ROLE_BEARER=$state.env.SERVICE_ROLE_KEY;PHASE8_LOCAL_CLEANUP_TOKEN='unused-local-negative-token'}
 foreach($key in $values.Keys){$saved[$key]=[Environment]::GetEnvironmentVariable($key);[Environment]::SetEnvironmentVariable($key,$values[$key])}
 # Match the existing envelope contract only in the explicitly pinned local Storage service.
 $headers=@{apikey=$state.env.SERVICE_ROLE_KEY;Authorization=('Bearer '+$state.env.SERVICE_ROLE_KEY)}
 $body=@{public=$false;file_size_limit=10485760;allowed_mime_types=@('application/json')}|ConvertTo-Json -Compress
 $null=Invoke-RestMethod -Method Put -Uri ($state.env.API_URL+'/storage/v1/bucket/phase8-drive-staging') -Headers $headers -ContentType application/json -Body $body
 # Local provider fixture never enters the PROD function source or deployment manifest.
 $localFunction='tmp/pgr2b-canonical/supabase/functions/process-world-publish'
 if((Get-Item $localFunction).LinkType){throw 'Fixture workspace must not link to production source'}
 Copy-Item supabase/functions/process-world-publish/index.ts "$localFunction/production.ts" -Force
 Copy-Item supabase/prod/tests/mapbox_fixture_entry.ts "$localFunction/index.ts" -Force
 $fixtureInstalled=$true
 $argsList=@('test','--allow-env','--allow-net=127.0.0.1:27773','--allow-run=docker')
 if($Filter){$argsList+=@('--filter',$Filter)}
 $argsList+=@('supabase/prod/tests/canonical_drive_edge_test.ts','supabase/prod/tests/canonical_planet_edge_test.ts')
 & 'C:\Users\PC\.deno\bin\deno.exe' @argsList
 if($LASTEXITCODE -ne 0){throw 'P-GR5B service acceptance failed'}
} finally {
 if($fixtureInstalled){Copy-Item supabase/functions/process-world-publish/index.ts "$localFunction/index.ts" -Force}
 foreach($key in $saved.Keys){[Environment]::SetEnvironmentVariable($key,$saved[$key])}
 Pop-Location
}
