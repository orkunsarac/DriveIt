$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
& ./tool/r6b2_planet_parity.ps1
$db = @(docker ps --filter 'label=com.supabase.service=database' --format '{{.Names}}' | Where-Object { $_ -like 'supabase-r6b2-rehearsal-r6b2-rehearsal-20261103-database-*' })
if ($db.Count -ne 1) { throw 'Expected one isolated rehearsal database.' }
function Query([string]$sql) {
  $result = @($sql | docker exec -i $db[0] psql -U postgres -d r6b2_rehearsal_v2 -X -q -At -v ON_ERROR_STOP=1)
  if ($LASTEXITCODE -ne 0) { throw 'Rehearsal SQL failed; stop without retry.' }
  return $result
}
function Source($entry) {
  $text = [IO.File]::ReadAllText((Join-Path (Get-Location) $entry.path)).Replace("`r`n", "`n")
  $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($text)))
  if ($hash -cne $entry.sha256) { throw "Manifest hash mismatch: $($entry.path)" }
  return $text
}
function Record($entry, [string]$sql) {
  $file = [IO.Path]::GetFileNameWithoutExtension($entry.path)
  if ($file -cnotmatch '^([0-9]{12})_([a-z0-9_]+)$') { throw 'Unexpected migration name.' }
  $version, $name = $Matches[1], $Matches[2]
  $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($sql))
  Query "INSERT INTO supabase_migrations.schema_migrations(version,name,statements) VALUES ('$version','$name',ARRAY[convert_from(decode('$encoded','base64'),'UTF8')]);" | Out-Null
}
$base = @((Get-Content supabase/prod/preparation_manifest.json -Raw | ConvertFrom-Json).files | Where-Object kind -eq 'migration')
$upgrade = @((Get-Content supabase/prod/upgrade_manifest.json -Raw | ConvertFrom-Json).files)
$corrections = @((Get-Content supabase/prod/correction_manifest.json -Raw | ConvertFrom-Json).files)
if ($base.Count -ne 25 -or $upgrade.Count -ne 25 -or $corrections.Count -ne 2) { throw 'Migration inventory count mismatch.' }
$expectedVersions = @($base[2..23] | ForEach-Object { ([IO.Path]::GetFileName($_.path) -split '_')[0] })
$actualVersions = @(Query 'SELECT version FROM supabase_migrations.schema_migrations ORDER BY version;')
$before = Query "SELECT count(*)||':'||md5(coalesce(string_agg(to_jsonb(m)::text,E'\n' ORDER BY to_jsonb(m)::text),'')) FROM public.phase8_drive_manifests m;"
if (($actualVersions -join ',') -ceq ($expectedVersions -join ',')) {
  foreach ($entry in $base[0..1]) { $text = Source $entry; Record $entry $text }
} else {
  $withBootstrap = @($base[0..23] | ForEach-Object { ([IO.Path]::GetFileName($_.path) -split '_')[0] })
  if (($actualVersions -join ',') -cne ($withBootstrap -join ',')) { throw 'Restore ledger is not an expected 22 or 24 version state.' }
  foreach ($entry in $base[0..1]) {
    $text = Source $entry
    $version = ([IO.Path]::GetFileName($entry.path) -split '_')[0]
    $expectedHash = [Convert]::ToHexString([Security.Cryptography.MD5]::HashData([Text.Encoding]::UTF8.GetBytes($text))).ToLowerInvariant()
    if ((Query "SELECT md5(statements[1]) FROM supabase_migrations.schema_migrations WHERE version='$version';") -cne $expectedHash) { throw 'Recorded bootstrap source differs.' }
  }
  if ((Query "SELECT coalesce(to_regclass('public.phase8_group_rollout')::text,'absent');") -cne 'absent') { throw 'Gate already exists; refusing replay.' }
  Write-Output 'Resuming verified 24-version state after local database ownership correction.'
}
$gate = $base[24]; $gateSql = Source $gate
Query $gateSql | Out-Null
if ((Query 'SELECT enabled FROM public.phase8_group_rollout WHERE singleton;') -cne 'f') { throw 'Group gate is not false.' }
Record $gate $gateSql
if ((Query 'SELECT count(*) FROM supabase_migrations.schema_migrations;') -cne '25') { throw 'Base ledger count mismatch.' }
foreach ($entry in ($upgrade + $corrections)) {
  $text = Source $entry
  Query $text | Out-Null
  Record $entry $text
  Write-Output ("Applied " + [IO.Path]::GetFileName($entry.path))
}
if ((Query 'SELECT count(*) FROM supabase_migrations.schema_migrations;') -cne '52') { throw 'Final ledger count mismatch.' }
$after = Query "SELECT count(*)||':'||md5(coalesce(string_agg(to_jsonb(m)::text,E'\n' ORDER BY to_jsonb(m)::text),'')) FROM public.phase8_drive_manifests m;"
if ($before -cne $after) { throw 'Existing finalized drive manifest rows changed.' }
if ((Query 'SELECT enabled FROM public.phase8_group_rollout WHERE singleton;') -cne 'f') { throw 'Group gate changed.' }
Write-Output 'PASS: 52 migration records; group gate false; existing finalized manifest rows unchanged.'
