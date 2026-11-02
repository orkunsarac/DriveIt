Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Set-Location (Join-Path $PSScriptRoot '..')
$target=Get-Content tmp/r3-upgrade-target.json -Raw|ConvertFrom-Json
if($target.name -cnotmatch '^r3-upgrade-[a-f0-9]{10}$'){throw 'Wrong local descriptor'}
$db=@(docker ps --filter ('label=com.supabase.stack='+$target.id) --filter 'label=com.supabase.service=database' --format '{{.Names}}')
if($db.Count -ne 1){throw 'Ambiguous isolated DB'}
foreach($other in @(docker ps --format '{{.Names}}'|Where-Object {$_ -match 'database-' -and $_ -ne $db[0]})){
 & ./tool/test_postgres_isolation.ps1 -LeftContainer $db[0] -RightContainer $other
}
function Sql([string]$query){
 $result=$query|docker exec -i $db[0] psql -U postgres -d postgres -X -q -At -v ON_ERROR_STOP=1
 if($LASTEXITCODE -ne 0){throw 'Local correction SQL failed'}
 return ($result -join "`n").Trim()
}
if((Sql "select (select count(*) from auth.users)=0 and (select count(*) from public.world_publishes)=0 and public.phase8_group_enabled()=false;") -cne 't'){throw 'Expected empty closed local reference'}
$history=Sql 'select count(*) from supabase_migrations.schema_migrations;'
if($history -cne '50'){throw 'Expected exact local history50'}
$path='tmp/road-correction-test-'+[guid]::NewGuid().ToString('N')+'.sql'
& 'C:\Users\PC\.deno\bin\deno.exe' run --allow-read --allow-write=tmp tool/build_prod_upgrade.ts $path --road-version-correction
if($LASTEXITCODE -ne 0){throw 'Correction build failed'}
$sql=Get-Content $path -Raw
if($sql -notmatch 'COMMIT;\s*$'){throw 'No outer commit'}
$null=Sql ($sql -replace 'COMMIT;\s*$','ROLLBACK;')
if((Sql "select (select count(*) from supabase_migrations.schema_migrations)=50 and position('r.processing_version<>6' in pg_get_functiondef('public.account_deletion_planet_context(uuid,uuid)'::regprocedure))>0;") -cne 't'){throw 'Correction rollback failed'}
$null=Sql $sql
if((Sql "select (select count(*) from supabase_migrations.schema_migrations)=52 and position('r.processing_version<>3' in pg_get_functiondef('public.account_deletion_planet_context(uuid,uuid)'::regprocedure))>0 and public.phase8_group_enabled()=false;") -cne 't'){throw 'Correction commit failed'}
'PASS: isolated correction rollback and commit; history 52, canonical road version 3, group gate FALSE.'
