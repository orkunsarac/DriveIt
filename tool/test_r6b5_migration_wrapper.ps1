Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Set-Location (Join-Path $PSScriptRoot '..')
. (Join-Path $PSScriptRoot 'r6b5_migration_wrapper.ps1')
$entries=@((Get-Content 'supabase/prod/preparation_manifest.json' -Raw|ConvertFrom-Json).files|Where-Object kind -eq 'migration')+
  @(Get-Content 'supabase/prod/upgrade_manifest.json' -Raw|ConvertFrom-Json).files+
  @(Get-Content 'supabase/prod/correction_manifest.json' -Raw|ConvertFrom-Json).files
if($entries.Count -ne 52){throw 'Expected 52 reviewed migration files.'}
foreach($entry in $entries){
  $sql=[IO.File]::ReadAllText($entry.path).Replace("`r`n","`n")
  $actual=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($sql)))
  if($actual -cne $entry.sha256){throw ('Migration source hash mismatch: '+$entry.path)}
  $sourceBeginCount=@($sql -split "`n"|Where-Object{$_.Trim() -ieq 'begin;'}).Count
  if($sourceBeginCount -gt 1){throw ('Ambiguous standalone BEGIN markers: '+$entry.path)}
  $wrapped=New-R6B5AtomicMigrationStatement $sql $entry
  if(!$wrapped.StartsWith("BEGIN;`n") -or !$wrapped.TrimEnd().EndsWith('COMMIT;')){throw ('Transaction wrapper boundary invalid: '+$entry.path)}
  $identity=Get-R6B5MigrationIdentity $entry
  $expectedRecord="INSERT INTO supabase_migrations.schema_migrations(version,name,statements) VALUES ('$($identity.version)','$($identity.name)'"
  if(!$wrapped.Contains($expectedRecord)){throw ('Ledger record not inside transaction: '+$entry.path)}
  $beginCount=0
  foreach($line in ($wrapped -split "`n")){if($line.Trim() -ieq 'begin;'){$beginCount++}}
  if($beginCount -ne 1){throw ('Nested standalone BEGIN remains after wrapping: '+$entry.path)}
}
Write-Output 'PASS: 52 hash-verified migrations produce one outer transaction containing SQL and ledger record.'
