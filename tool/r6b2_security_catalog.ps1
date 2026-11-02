$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
$reference = @(docker ps --filter 'label=com.supabase.service=database' --format '{{.Names}}' | Where-Object { $_ -like 'supabase-r6b2-reference-canonical-*-database-*' })
$restore = @(docker ps --filter 'label=com.supabase.service=database' --format '{{.Names}}' | Where-Object { $_ -like 'supabase-r6b2-rehearsal-r6b2-rehearsal-20261103-database-*' })
if ($reference.Count -ne 1 -or $restore.Count -ne 1) { throw 'Expected unique isolated reference and restore containers.' }
$source = Get-Content tool/audit_prod_policies.ps1 -Raw
$match = [regex]::Match($source, "(?s)\`$query=@'\r?\n(.*?)\r?\n'@")
if (!$match.Success) { throw 'Security catalog query unavailable.' }
$query = "BEGIN;`n" + $match.Groups[1].Value + "`nROLLBACK;"
function Read-Catalog($container, $database) {
  $result = @($query | docker exec -i $container psql -U postgres -d $database -X -q -At -v ON_ERROR_STOP=1)
  if ($LASTEXITCODE -ne 0) { throw "Catalog query failed: $database" }
  return (($result -join "`n") | ConvertFrom-Json)
}
$expected = Read-Catalog $reference[0] 'postgres'
$actual = Read-Catalog $restore[0] 'r6b2_rehearsal_v2'
$failures = 0
foreach ($category in @('tables','policies','functions')) {
  $key = if ($category -eq 'tables') { 'name' } elseif ($category -eq 'functions') { 'signature' } else { 'policyname' }
  foreach ($e in $expected.$category) {
    $matches = @($actual.$category | Where-Object { $_.$key -ceq $e.$key -and ($category -ne 'policies' -or ($_.schemaname -ceq $e.schemaname -and $_.tablename -ceq $e.tablename)) })
    $exp = ($e | ConvertTo-Json -Depth 100 -Compress).Replace('\r\n','\n')
    $act = if ($matches.Count -eq 1) { ($matches[0] | ConvertTo-Json -Depth 100 -Compress).Replace('\r\n','\n') } else { 'MISSING_OR_AMBIGUOUS' }
    if ($exp -cne $act) { Write-Output "DIFFERENT $category $($e.$key)"; $failures++ }
  }
  foreach ($a in $actual.$category) {
    $matches = @($expected.$category | Where-Object { $_.$key -ceq $a.$key -and ($category -ne 'policies' -or ($_.schemaname -ceq $a.schemaname -and $_.tablename -ceq $a.tablename)) })
    if ($matches.Count -ne 1) { Write-Output "UNEXPECTED $category $($a.$key)"; $failures++ }
  }
  Write-Output "$category reference=$(@($expected.$category).Count) restore=$(@($actual.$category).Count)"
}
if ($failures) { throw "Security catalog comparison found $failures differences." }
Write-Output 'PASS: security catalogs match.'
