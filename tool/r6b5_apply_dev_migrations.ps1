param([switch]$ApplyApprovedDevMigrations)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if(!$ApplyApprovedDevMigrations){throw 'Explicit ApplyApprovedDevMigrations switch required.'}
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $root
$env:SUPABASE_TELEMETRY_DISABLED='1'
. (Join-Path $PSScriptRoot 'r6b5_migration_wrapper.ps1')
$ref='viqngnjfgknpxtoapzcg'
$cli=(Resolve-Path 'tmp\supabase-cli-npm-cache\_npx\6f1b058a4d9555af\node_modules\.bin\supabase.cmd').Path
$project=Join-Path $root ('tmp\r6b5-dev-migration-work-'+[guid]::NewGuid().ToString('N'))
$migrationDir=Join-Path $project 'supabase\migrations'
New-Item -ItemType Directory -Path $migrationDir -Force|Out-Null
$configText=@"
project_id = "driveit-r6b5-dev-$([guid]::NewGuid().ToString('N').Substring(0,8))"

[db.migrations]
enabled = true
schema_paths = ["./migrations/*.sql"]
"@
Set-Content -LiteralPath (Join-Path $project 'supabase\config.toml') -Value $configText -Encoding utf8

function Read-Manifest([string]$path){Get-Content -LiteralPath $path -Raw|ConvertFrom-Json}
function Checked-Source($entry){$path=Join-Path $root $entry.path;$sql=[IO.File]::ReadAllText($path).Replace("`r`n","`n");$hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($sql)));if($hash -cne $entry.sha256){throw ('Source manifest mismatch: '+$entry.path)};return $sql}
function Get-Version($entry){$name=[IO.Path]::GetFileNameWithoutExtension($entry.path);if($name -cnotmatch '^([0-9]{12})_([a-z0-9_]+)$'){throw 'Unexpected migration name'};return @{version=$Matches[1];name=$Matches[2]}}
function Invoke-Cli([string[]]$argv,[string]$label){$old=$ErrorActionPreference;$ErrorActionPreference='Continue';try{$out=@(& $cli @argv 2>&1);$code=$LASTEXITCODE}finally{$ErrorActionPreference=$old};if($code -ne 0){throw ($label+' failed; output suppressed; stop and inspect remote migration history before retrying.')};return ,$out}
function Invoke-Remote([string]$sql,[bool]$parse=$false){$file=Join-Path $project ('query-'+[guid]::NewGuid().ToString('N')+'.sql');[IO.File]::WriteAllText($file,$sql,[Text.UTF8Encoding]::new($false));$out=Invoke-Cli @('db','query','--linked','--project-ref',$ref,'--workdir',$project,'--file',$file,'--output-format','json') 'DEV database query';if(!$parse){return $null};$text=($out|ForEach-Object{$_.ToString()})-join "`n";$start=$text.IndexOf('{');$end=$text.LastIndexOf('}');if($start -lt 0 -or $end -lt $start){throw 'DEV query response was not JSON; output suppressed.'};return ($text.Substring($start,$end-$start+1)|ConvertFrom-Json).rows}
function Assert-Remote([string]$query,[string]$expected,[string]$label){$rows=Invoke-Remote $query $true;if(@($rows).Count -ne 1 -or [string]$rows[0].value -cne $expected){throw ($label+' pre/postcondition failed; stop.')};return $rows[0]}
function Apply-One($entry,[string]$sql){$version=Get-Version $entry;$local=Join-Path $migrationDir ([IO.Path]::GetFileName($entry.path));[IO.File]::WriteAllText($local,$sql,[Text.UTF8Encoding]::new($false));$atomic=New-R6B5AtomicMigrationStatement $sql $entry;$file=Join-Path $project ('apply-'+$version.version+'.sql');[IO.File]::WriteAllText($file,$atomic,[Text.UTF8Encoding]::new($false));[void](Invoke-Cli @('db','query','--linked','--project-ref',$ref,'--workdir',$project,'--file',$file,'--output-format','json') ('Migration '+$version.version));$check="SELECT count(*)::text AS value FROM supabase_migrations.schema_migrations WHERE version='$($version.version)' AND name='$($version.name)' AND statements[1]=convert_from(decode('$([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($sql)))','base64'),'UTF8');";$row=Assert-Remote $check '1' ('Ledger '+$version.version);Write-Output ('Applied DEV migration '+$version.version+'.')}

try{
  # Recheck the entire encrypted-backup-to-isolated-restore catalog agreement
  # immediately before any remote write; this check only reads DEV metadata.
  $backupRoot=Join-Path $env:LOCALAPPDATA 'DriveIt\Recovery\R6B5-DEV-20261103-085654-8b8b13f2'
  & (Join-Path $root 'tool\r6b5_restore_rehearsal.ps1') -Root $backupRoot -Container 'driveit-r6b5-restore-20261103-j' -Resume | Out-Null
  if($LASTEXITCODE -ne 0){throw 'Fresh read-only DEV/backup consistency check failed; no writes performed.'}
  $base=@((Read-Manifest 'supabase/prod/preparation_manifest.json').files|Where-Object kind -eq 'migration')
  $upgrade=@((Read-Manifest 'supabase/prod/upgrade_manifest.json').files)
  $corrections=@((Read-Manifest 'supabase/prod/correction_manifest.json').files)
  if($base.Count -ne 25 -or $upgrade.Count -ne 25 -or $corrections.Count -ne 2){throw 'Expected 25 base, 25 deletion and 2 correction manifest files.'}
  $all=@($base+$upgrade+$corrections)
  if(@($all|ForEach-Object{(Get-Version $_).version}|Select-Object -Unique).Count -ne 52){throw 'Migration versions are not unique.'}
  foreach($entry in $all){$sql=Checked-Source $entry;[IO.File]::WriteAllText((Join-Path $migrationDir ([IO.Path]::GetFileName($entry.path))),$sql,[Text.UTF8Encoding]::new($false))}
  $projects=Invoke-Cli @('projects','list','--output-format','json') 'DEV project identity check';$projectJson=($projects|ForEach-Object{$_.ToString()}|Where-Object{$_.TrimStart().StartsWith('{')})-join "`n";$matches=@((ConvertFrom-Json $projectJson).projects|Where-Object id -CEQ $ref);if($matches.Count -ne 1 -or $matches[0].status -cne 'ACTIVE_HEALTHY' -or $matches[0].name -cne 'DriveIT DEV'){throw 'DEV project identity or health mismatch.'}
  $ledger=Invoke-Remote "SELECT jsonb_build_object('versions',coalesce(jsonb_agg(version ORDER BY version),'[]'::jsonb),'count',count(*)) AS value FROM supabase_migrations.schema_migrations;" $true
  if(@($ledger).Count -ne 1 -or [int]$ledger[0].value.count -ne 22){throw 'Remote baseline migration count is not 22; no writes performed.'}
  $expected=@($base[2..23]|ForEach-Object{(Get-Version $_).version});$actual=@($ledger[0].value.versions|ForEach-Object{[string]$_});if(($actual -join ',') -cne ($expected -join ',')){throw 'Remote baseline migration versions differ from the verified backup.'}
  $state=Invoke-Remote "SELECT jsonb_build_object('manifest',count(*)||':'||md5(coalesce(string_agg(to_jsonb(m)::text,E'\n' ORDER BY to_jsonb(m)::text),'')),'gate',coalesce(to_regclass('public.phase8_group_rollout')::text,'absent'),'deletion',coalesce(to_regclass('public.account_deletion_jobs')::text,'absent'),'trigger',(SELECT count(*) FROM pg_event_trigger WHERE evtname='ensure_rls')) AS value FROM public.phase8_drive_manifests m;" $true
  if(@($state).Count -ne 1 -or $state[0].value.gate -cne 'absent' -or $state[0].value.deletion -cne 'absent' -or [int]$state[0].value.trigger -ne 1){throw 'Remote schema precondition differs from verified backup.'}
  $backup=Get-Content -LiteralPath (Join-Path $env:LOCALAPPDATA 'DriveIt\Recovery\R6B5-DEV-20261103-085654-8b8b13f2\restore-work\inventory\catalog.json') -Raw|ConvertFrom-Json
  if([string]$state[0].value.manifest -cne ([string]$backup.data.manifest_rows+':'+[string]$backup.data.manifest_hash)){throw 'Remote finalized manifest fingerprint differs from verified backup.'}
  $versionBase=@($base[0..23]);foreach($entry in $versionBase){[void](Checked-Source $entry)}

  # Reconcile only the two hash-verified bootstrap ledger records. Their DDL
  # was independently proven equal to the DEV Planet catalog (122/122).
  foreach($entry in $base[0..1]){$version=Get-Version $entry;$sql=Checked-Source $entry;$encoded=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($sql));$file=Join-Path $project ('ledger-'+$version.version+'.sql');$insert="BEGIN; INSERT INTO supabase_migrations.schema_migrations(version,name,statements) VALUES ('$($version.version)','$($version.name)',ARRAY[convert_from(decode('$encoded','base64'),'UTF8')]); COMMIT;";[IO.File]::WriteAllText($file,$insert,[Text.UTF8Encoding]::new($false));[void](Invoke-Cli @('db','query','--linked','--project-ref',$ref,'--workdir',$project,'--file',$file,'--output-format','json') ('Bootstrap ledger reconciliation '+$version.version))}
  if((Assert-Remote 'SELECT count(*)::text AS value FROM supabase_migrations.schema_migrations;' '24' 'Bootstrap reconciliation').value -ne '24'){throw 'Bootstrap ledger reconciliation failed.'}

  # Apply the server Group Drive gate first and verify false before deletion DDL.
  Apply-One $base[24] (Checked-Source $base[24])
  $gate=Invoke-Remote "SELECT enabled::text AS value FROM public.phase8_group_rollout WHERE singleton;" $true
  if(@($gate).Count -ne 1 -or [string]$gate[0].value -cne 'false'){throw 'Group Drive gate is not false; stop before deletion migrations.'}
  foreach($entry in ($upgrade+$corrections)){Apply-One $entry (Checked-Source $entry)}

  $final=Invoke-Remote "SELECT jsonb_build_object('count',(SELECT count(*) FROM supabase_migrations.schema_migrations),'gate',(SELECT enabled FROM public.phase8_group_rollout WHERE singleton),'manifest',count(*)||':'||md5(coalesce(string_agg(to_jsonb(m)::text,E'\n' ORDER BY to_jsonb(m)::text),'')),'jobs_rls',(SELECT relrowsecurity FROM pg_class WHERE oid='public.account_deletion_jobs'::regclass),'audit_rls',(SELECT relrowsecurity FROM pg_class WHERE oid='public.account_deletion_erasure_audit'::regclass),'ensure_rls',(SELECT count(*) FROM pg_event_trigger WHERE evtname='ensure_rls')) AS value FROM public.phase8_drive_manifests m;" $true
  if(@($final).Count -ne 1 -or [int]$final[0].value.count -ne 52 -or $final[0].value.gate -ne $false -or [string]$final[0].value.manifest -cne [string]$state[0].value.manifest -or $final[0].value.jobs_rls -ne $true -or $final[0].value.audit_rls -ne $true -or [int]$final[0].value.ensure_rls -ne 1){throw 'DEV final migration/catalog verification failed.'}
  Write-Output 'PASS: DEV 52-migration chain; gate false; RLS and finalized manifest fingerprint verified.'
}catch{Write-Output ('DEV_MIGRATION_STOP: '+$_.Exception.Message);throw}
