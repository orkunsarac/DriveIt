param([ValidateSet('r6b2_rehearsal_v2','r6b2_parity_v3')][string]$Database = 'r6b2_rehearsal_v2')
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
$reference = @(docker ps --filter 'label=com.supabase.service=database' --format '{{.Names}}' | Where-Object { $_ -like 'supabase-r6b2-reference-full-r6b2-reference-full-database-*' })
$restore = @(docker ps --filter 'label=com.supabase.service=database' --format '{{.Names}}' | Where-Object { $_ -like 'supabase-r6b2-rehearsal-r6b2-rehearsal-20261103-database-*' })
if ($reference.Count -ne 1 -or $restore.Count -ne 1) { throw 'Expected unique isolated reference and restore containers.' }
$sql = Get-Content tool/r6b2_planet_catalog.sql -Raw
function Read-Catalog($container, $database) {
  $lines = @($sql | docker exec -i $container psql -U supabase_admin -d $database -X -q -At -v ON_ERROR_STOP=1)
  if ($LASTEXITCODE -ne 0) { throw "Catalog query failed: $database" }
  $result = @{}
  foreach ($line in $lines) {
    $entry = $line | ConvertFrom-Json
    $key = $entry.kind + ':' + $entry.object
    if ($result.ContainsKey($key)) { throw "Duplicate catalog key: $key" }
    $result[$key] = $entry.definition
  }
  return ,$result
}
$expected = Read-Catalog $reference[0] 'postgres'
$actual = Read-Catalog $restore[0] $Database
$keys = @(@($expected.Keys) + @($actual.Keys) | Sort-Object -Unique)
$differences = @($keys | Where-Object { $expected[$_] -cne $actual[$_] })
foreach ($key in $differences) {
  Write-Output "OBJECT $key"
  Write-Output "EXPECTED $($expected[$key])"
  Write-Output "ACTUAL $($actual[$key])"
}
if ($differences.Count -or $expected.Count -ne 122 -or $actual.Count -ne 122) { throw "Planet parity failed: $($differences.Count) differences; reference=$($expected.Count), restore=$($actual.Count)." }
Write-Output 'PASS: 122 Planet catalog records match the bootstrap plus 22 migration reference.'
