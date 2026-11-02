param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $root
try {
 $env:SUPABASE_EXPERIMENTAL_STACK='1'
 $target=Get-Content tmp/r3-upgrade-target.json -Raw|ConvertFrom-Json
 if($target.name -cnotmatch '^r3-upgrade-[a-f0-9]{10}$' -or $target.work -cne ('tmp/'+$target.name)){throw 'Unapproved local descriptor'}
 $state=(& npx --no-install supabase@2.120.0 stack status --stack-id $target.id --workdir $target.work --output-format json)|ConvertFrom-Json
 if($LASTEXITCODE -ne 0 -or $state.identity.id -cne $target.id -or $state.identity.name -cne $target.name){throw 'Local identity mismatch'}
 if(([uri]$state.env.API_URL).Host -cne '127.0.0.1' -or ([uri]$state.env.DB_URL).Host -cne '127.0.0.1'){throw 'Non-loopback target'}
 $names=@(docker ps --format '{{.Names}}')
 $dbs=@(docker ps --filter ('label=com.supabase.stack='+$target.id) --filter 'label=com.supabase.service=database' --format '{{.Names}}')
 if($dbs.Count -ne 1){throw 'Ambiguous local database'}
 $container=$dbs[0]
 if(!$container.StartsWith('supabase-'+$target.name+'-',[StringComparison]::Ordinal)){throw 'Container name does not match approved local stack'}
 foreach($other in $names|Where-Object {$_ -match 'database-' -and $_ -ne $container}){
  & ./tool/test_postgres_isolation.ps1 -LeftContainer $container -RightContainer $other
 }
 function Sql([string]$sql){
  $result=$sql|docker exec -i $container psql -U postgres -d postgres -X -At -v ON_ERROR_STOP=1
  if($LASTEXITCODE -ne 0){throw 'Isolated SQL validation failed'}
  return ($result -join "`n").Trim()
 }
 $system=Sql 'select system_identifier from pg_control_system();'
 if($system -notmatch '^\d+$'){throw 'Missing system identity'}
 # Also compare classic Supabase clusters; no inspection of environment secrets.
 foreach($other in $names|Where-Object {$_ -match '^supabase_db_'}){
  $otherSystem=docker exec $other psql -U postgres -d postgres -X -At -c 'select system_identifier from pg_control_system();'
  if($LASTEXITCODE -ne 0 -or $otherSystem -ceq $system){throw 'Classic cluster identity is ambiguous'}
  $left=(docker inspect --format '{{json .Mounts}}' $container|ConvertFrom-Json)|Where-Object Destination -eq '/var/lib/postgresql/data'
  $right=(docker inspect --format '{{json .Mounts}}' $other|ConvertFrom-Json)|Where-Object Destination -eq '/var/lib/postgresql/data'
  if(!$left -or !$right -or $left.Source -ceq $right.Source){throw 'Classic physical mount isolation is ambiguous'}
 }
 if((Sql "select (select count(*) from auth.users)+(select count(*) from storage.objects)+(select count(*) from pg_class where relnamespace='public'::regnamespace and relkind in ('r','p')); ") -cne '0'){throw 'Fresh empty database required; no reset is allowed'}
 $prefix='tmp/r3-sql-'+[guid]::NewGuid().ToString('N')
 & 'C:\Users\PC\.deno\bin\deno.exe' run --allow-read --allow-write=tmp tool/build_prod_transaction.ts ($prefix+'-base.sql')
 if($LASTEXITCODE -ne 0){throw 'Base build failed'}
 & 'C:\Users\PC\.deno\bin\deno.exe' run --allow-read --allow-write=tmp tool/build_prod_upgrade.ts ($prefix+'-upgrade.sql')
 if($LASTEXITCODE -ne 0){throw 'Upgrade build failed'}
 $null=Sql (Get-Content ($prefix+'-base.sql') -Raw)
 $upgrade=Get-Content ($prefix+'-upgrade.sql') -Raw
 if($upgrade -notmatch 'COMMIT;\s*$'){throw 'Missing outer commit'}
 $null=Sql ($upgrade -replace 'COMMIT;\s*$','ROLLBACK;')
 if((Sql "select count(*)=25 and to_regclass('public.account_deletion_jobs') is null from supabase_migrations.schema_migrations;") -cne 't'){throw 'Rollback did not restore the base'}
 'PASS: additive upgrade rolls back with base history intact.'
 $null=Sql $upgrade
 if((Sql "select count(*)=50 and public.phase8_group_enabled()=false and (select count(*) from auth.users)=0 from supabase_migrations.schema_migrations;") -cne 't'){throw 'Upgrade final acceptance failed'}
 'PASS: 50 migration history, erasure audit/worker ACL assertions, Group Drive FALSE and zero Auth users.'
} finally {Pop-Location}
