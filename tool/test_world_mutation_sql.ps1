# Isolated schema inside ONE rollback transaction. Never rewrites public state.
param([string]$ProjectRef = 'viqngnjfgknpxtoapzcg')
$ErrorActionPreference = 'Stop'
if ($ProjectRef -ne 'viqngnjfgknpxtoapzcg') { throw 'DEV-only test.' }
if (-not $env:SUPABASE_ACCESS_TOKEN) { throw 'CLI authentication unavailable.' }
$taskMigration = Get-Content -Raw (Join-Path $PSScriptRoot '../supabase/migrations/202610060002_active_world_mutation.sql')
$taskStart = $taskMigration.IndexOf('create or replace function public.commit_active_world_mutation(')
$taskEnd = $taskMigration.IndexOf("notify pgrst", $taskStart)
$taskFunction = $taskMigration.Substring($taskStart,$taskEnd-$taskStart).Replace('public.world_', 'driveit_2c_test.world_').Replace('public.commit_active_world_mutation','driveit_2c_test.commit_active_world_mutation').Replace('driveit_2c_test.world_section_geometry_length_meters','public.world_section_geometry_length_meters')
$taskFixtures = Get-Content -Raw (Join-Path $PSScriptRoot '../test/fixtures/active_world_mutation_sql.json')
$taskSetup = Get-Content -Raw (Join-Path $PSScriptRoot 'world_mutation_sql_integration.sql')
$taskQuery = $taskSetup.Replace('/* FUNCTION */',$taskFunction).Replace('/* FIXTURES */',$taskFixtures.Trim())
$taskHeaders = @{ Authorization = ('Bearer ' + $env:SUPABASE_ACCESS_TOKEN) }
$taskBody = @{query=$taskQuery}|ConvertTo-Json -Compress
try {
  $taskResult = Invoke-RestMethod -Method Post -Uri "https://api.supabase.com/v1/projects/$ProjectRef/database/query" -Headers $taskHeaders -ContentType 'application/json' -Body $taskBody
  $taskResult | ConvertTo-Json -Compress
} catch {
  # This query contains no credential/source data; print only DB diagnostic.
  if ($_.ErrorDetails.Message) { Write-Output $_.ErrorDetails.Message }
  throw 'Isolated SQL integration failed; transaction rolls back.'
}
