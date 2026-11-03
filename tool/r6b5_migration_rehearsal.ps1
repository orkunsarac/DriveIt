param(
  [string]$Container = 'driveit-r6b5-restore-20261103-j',
  [ValidatePattern('^driveit_r6b5_migration_rehearsal(?:_[a-z0-9]+)?$')][string]$Database = 'driveit_r6b5_migration_rehearsal'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

# This tool only creates a new database in the specifically labelled, offline
# R6-B5 restore container. It never changes DEV/PROD or the protected restore DB.
$inspect = @(& docker inspect --format '{{index .Config.Labels "driveit.test"}}|{{.State.Status}}|{{.HostConfig.NetworkMode}}|{{.Config.Image}}' $Container 2>$null)
if ($LASTEXITCODE -ne 0 -or ($inspect -join '').Trim() -cne 'r6b5-restore|running|none|public.ecr.aws/supabase/postgres:17.11.0.004') { throw 'Target is not the owned network-isolated R6-B5 restore container.' }
function Query([string]$db,[string]$sql) {
  $out = @(& docker exec --user postgres $Container psql -X -A -t -v ON_ERROR_STOP=1 -U postgres -d $db -c $sql 2>&1)
  if ($LASTEXITCODE -ne 0) { throw "Isolated rehearsal query failed in $db." }
  return ($out -join "`n").Trim()
}
function Run-File([string]$db,[string]$path) {
  $out = @(& docker exec --user postgres $Container psql -X -v ON_ERROR_STOP=1 -U postgres -d $db -f $path 2>&1)
  if ($LASTEXITCODE -ne 0) { throw "Isolated rehearsal SQL failed in $db at $(Split-Path -Leaf $path); output suppressed." }
}
function Copy-ToContainer([string]$source,[string]$target) {
  & docker cp $source ($Container + ':' + $target) 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Unable to copy reviewed migration SQL to the offline container.' }
}
function Read-Manifest([string]$path) { return (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json) }
function Checked-Source($entry) {
  $path = Join-Path (Get-Location) $entry.path
  $text = [IO.File]::ReadAllText($path).Replace("`r`n","`n")
  $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($text)))
  if ($hash -cne $entry.sha256) { throw "Manifest hash mismatch: $($entry.path)" }
  return $text
}
function Record-Migration($entry,[string]$sql) {
  $name = [IO.Path]::GetFileNameWithoutExtension($entry.path)
  if ($name -cnotmatch '^([0-9]{12})_([a-z0-9_]+)$') { throw 'Unexpected migration filename.' }
  $version=$Matches[1];$migrationName=$Matches[2]
  $encoded=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($sql))
  [void](Query $Database "INSERT INTO supabase_migrations.schema_migrations(version,name,statements) VALUES ('$version','$migrationName',ARRAY[convert_from(decode('$encoded','base64'),'UTF8')]);")
}

$present = Query 'postgres' "SELECT count(*) FROM pg_database WHERE datname='$Database';"
if ($present -cne '0') { throw 'Refusing to reuse or overwrite an existing rehearsal database.' }
$sourceOwner = Query 'postgres' "SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname='driveit_r6b5_restore';"
if ($sourceOwner -cne 'postgres') { throw 'Protected restored database has an unexpected owner.' }
$sourceRows = Query 'driveit_r6b5_restore' 'SELECT count(*) FROM supabase_migrations.schema_migrations;'
if ($sourceRows -cne '22') { throw 'Protected restore is not the expected 22-migration baseline.' }
$sourceManifest = Query 'driveit_r6b5_restore' "SELECT count(*)||':'||md5(coalesce(string_agg(to_jsonb(m)::text,E'\n' ORDER BY to_jsonb(m)::text),'')) FROM public.phase8_drive_manifests m;"
$create = @(& docker exec --user postgres $Container psql -X -v ON_ERROR_STOP=1 -U supabase_admin -d postgres -c "CREATE DATABASE $Database TEMPLATE driveit_r6b5_restore OWNER postgres" 2>&1)
if ($LASTEXITCODE -ne 0) { throw 'Could not create a separate migration rehearsal copy.' }

try {
  $base=@((Read-Manifest 'supabase/prod/preparation_manifest.json').files|Where-Object kind -eq 'migration')
  $upgrade=@((Read-Manifest 'supabase/prod/upgrade_manifest.json').files)
  $corrections=@((Read-Manifest 'supabase/prod/correction_manifest.json').files)
  if ($base.Count -ne 25 -or $upgrade.Count -ne 25 -or $corrections.Count -ne 2) { throw 'Migration manifest inventory count mismatch.' }
  $actual=@((Query $Database 'SELECT version FROM supabase_migrations.schema_migrations ORDER BY version;') -split "`n"|Where-Object {$_})
  $baseline=@($base[2..23]|ForEach-Object{([IO.Path]::GetFileName($_.path)-split '_')[0]})
  if (($actual -join ',') -cne ($baseline -join ',')) { throw 'Rehearsal copy ledger is not the expected 22-version state.' }

  foreach($entry in $base[0..1]) {
    $text=Checked-Source $entry;$version=([IO.Path]::GetFileName($entry.path)-split '_')[0]
    $expected=[Convert]::ToHexString([Security.Cryptography.MD5]::HashData([Text.Encoding]::UTF8.GetBytes($text))).ToLowerInvariant()
    $recorded=Query $Database "SELECT coalesce((SELECT md5(statements[1]) FROM supabase_migrations.schema_migrations WHERE version='$version'),'absent');"
    if ($recorded -ceq 'absent') { Record-Migration $entry $text }
    elseif ($recorded -cne $expected) { throw 'Bootstrap SQL ledger fingerprint differs from the reviewed manifest.' }
  }

  $gate=$base[24];$gateSql=Checked-Source $gate
  if ((Query $Database "SELECT coalesce(to_regclass('public.phase8_group_rollout')::text,'absent');") -cne 'absent') { throw 'Group rollout table already exists; refusing to replay gate migration.' }
  $gateFile='r6b5-gate-migration.sql';[IO.File]::WriteAllText((Join-Path $env:TEMP $gateFile),$gateSql,[Text.UTF8Encoding]::new($false));$gatePath=Join-Path $env:TEMP $gateFile;Copy-ToContainer $gatePath '/tmp/r6b5-gate-migration.sql';Run-File $Database '/tmp/r6b5-gate-migration.sql';Record-Migration $gate $gateSql
  if ((Query $Database 'SELECT enabled::text FROM public.phase8_group_rollout WHERE singleton;') -cne 'false') { throw 'Group Drive gate did not initialize false.' }

  foreach($entry in ($upgrade+$corrections)) {
    $sql=Checked-Source $entry;$file=Join-Path $env:TEMP ([IO.Path]::GetFileName($entry.path));[IO.File]::WriteAllText($file,$sql,[Text.UTF8Encoding]::new($false));$remote='/tmp/r6b5-'+[IO.Path]::GetFileName($entry.path);Copy-ToContainer $file $remote;Run-File $Database $remote;Record-Migration $entry $sql
  }
  if ((Query $Database 'SELECT count(*) FROM supabase_migrations.schema_migrations;') -cne '52') { throw 'Final migration ledger is not 52.' }
  if ((Query $Database 'SELECT enabled::text FROM public.phase8_group_rollout WHERE singleton;') -cne 'false') { throw 'Group Drive gate changed from false.' }
  if ((Query $Database "SELECT count(*)||':'||md5(coalesce(string_agg(to_jsonb(m)::text,E'\n' ORDER BY to_jsonb(m)::text),'')) FROM public.phase8_drive_manifests m;") -cne $sourceManifest) { throw 'Existing finalized manifest data changed during migration rehearsal.' }

  $newPublicTables=@()
  foreach($entry in ($upgrade+$corrections)) {
    $sql=Checked-Source $entry
    foreach($match in [regex]::Matches($sql,'(?im)\bCREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:public\.)?"?([a-zA-Z_][a-zA-Z0-9_]*)"?')) { $newPublicTables+= $match.Groups[1].Value }
  }
  $newPublicTables=@($newPublicTables|Sort-Object -Unique)
  foreach($table in $newPublicTables) { if ((Query $Database "SELECT coalesce((SELECT relrowsecurity::text FROM pg_class WHERE oid=to_regclass('public.$table')),'missing');") -cne 'true') { throw "New public table RLS check failed: $table" } }

  foreach($test in @('tool/r6b2_group_gate_test.sql','tool/r6b2_deletion_isolation_test.sql')) {
    $testPath=(Resolve-Path $test).Path;Copy-ToContainer $testPath ('/tmp/'+(Split-Path -Leaf $test));Run-File $Database ('/tmp/'+(Split-Path -Leaf $test))
  }
  $summary=[pscustomobject]@{container=$Container;database=$Database;baseline_migrations=22;final_migrations=52;group_gate=$false;finalized_manifest_fingerprint=$sourceManifest;new_public_tables_checked=$newPublicTables.Count;new_public_tables_with_rls=$newPublicTables.Count;synthetic_sql_tests='group-gate,deletion-isolation';network='none'}
  $summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $env:TEMP 'driveit-r6b5-migration-summary.json') -Encoding utf8
  Write-Output ('PASS: isolated backup-copy rehearsal; migrations=52; group gate=false; existing finalized manifests unchanged; new public tables checked='+$newPublicTables.Count+'; synthetic SQL tests=2 PASS.')
} catch { Write-Output ('MIGRATION_REHEARSAL_FAILED: '+$_.Exception.Message); throw }
