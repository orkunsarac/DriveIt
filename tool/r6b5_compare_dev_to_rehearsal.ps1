param([string]$Container='driveit-r6b5-restore-20261103-j',[string]$Database='driveit_r6b5_migration_rehearsal_b')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Set-Location (Join-Path $PSScriptRoot '..')
$env:SUPABASE_TELEMETRY_DISABLED='1'
$ref='viqngnjfgknpxtoapzcg'
$cli=(Resolve-Path 'tmp\supabase-cli-npm-cache\_npx\6f1b058a4d9555af\node_modules\.bin\supabase.cmd').Path
$sql=(Resolve-Path 'tool\r6b5_catalog.sql').Path
$identity=@(& docker inspect --format '{{index .Config.Labels "driveit.test"}}|{{.State.Status}}|{{.HostConfig.NetworkMode}}' $Container 2>$null)
if($LASTEXITCODE -ne 0 -or ($identity -join '').Trim() -cne 'r6b5-restore|running|none'){throw 'Comparison target is not the owned offline restore container.'}
& docker cp $sql ($Container+':/tmp/r6b5-compare-catalog.sql')|Out-Null
if($LASTEXITCODE -ne 0){throw 'Unable to copy read-only catalog SQL to offline container.'}
$localOutput=@(& docker exec --user postgres $Container psql -X -A -t -U supabase_admin -d $Database -f /tmp/r6b5-compare-catalog.sql 2>$null)
if($LASTEXITCODE -ne 0){throw 'Offline final catalog query failed.'}
$local=($localOutput -join "`n"|ConvertFrom-Json)
$remoteOutput=@(& $cli db query --linked --project-ref $ref --workdir (Join-Path (Get-Location) 'supabase\phase8-dev') --file $sql --output-format json 2>$null)
if($LASTEXITCODE -ne 0){throw 'Read-only DEV catalog query failed; raw output suppressed.'}
$remoteText=($remoteOutput|ForEach-Object{$_.ToString()})-join "`n";$start=$remoteText.IndexOf('{');$end=$remoteText.LastIndexOf('}')
if($start -lt 0 -or $end -lt $start){throw 'DEV catalog output was not valid JSON.'}
$remote=($remoteText.Substring($start,$end-$start+1)|ConvertFrom-Json).rows[0].catalog
function Catalog-Key($x,[string]$kind){switch($kind){
  'schemaacl'{return @($x.owner,(@($x.acl|Sort-Object)-join ','))-join '|'}
  'extension'{return @($x.name,$x.version,$x.schema,$x.schema_owner)-join '|'}
  'event'{return @($x.name,$x.event,$x.enabled,(@($x.tags|Sort-Object)-join ','),$x.owner,$x.function_schema,$x.function_name,$x.function_owner,(@($x.function_acl|Sort-Object)-join ','),$x.definition)-join '|'}
  'table'{return @($x.schema,$x.table,$x.owner,$x.rls,$x.force_rls,(@($x.acl|Sort-Object)-join ','))-join '|'}
  'policy'{return @($x.schema,$x.table,$x.name,$x.mode,(@($x.roles|Sort-Object)-join ','),$x.command,$x.'using',$x.check)-join '|'}
  'trigger'{return @($x.schema,$x.table,$x.name,$x.enabled,$x.definition)-join '|'}
  'function'{$signature=$x.signature;if(!$signature.StartsWith($x.schema+'.')){$signature=$x.schema+'.'+$signature};return @($x.schema,$signature,$x.owner,$x.definer,(@($x.config|Sort-Object)-join ','),(@($x.acl|Sort-Object)-join ','),$x.definition_hash)-join '|'}
  'defacl'{return @($x.owner,$x.schema,$x.kind,(@($x.acl|Sort-Object)-join ','))-join '|'}
}}
function Equal-Array($a,$b,[string]$kind){$left=@($a|ForEach-Object{Catalog-Key $_ $kind}|Sort-Object);$right=@($b|ForEach-Object{Catalog-Key $_ $kind}|Sort-Object);return @(Compare-Object $left $right).Count -eq 0}
function Equal-Data($a,$b){foreach($f in @('auth_users','auth_hash','migrations','migration_hash','storage_buckets','storage_objects','storage_hash','manifest_rows','manifest_hash')){if([string]$a.$f -cne [string]$b.$f){return $false}};return $true}
$diff=[System.Collections.Generic.List[string]]::new()
foreach($pair in @(@('extensions','extension'),@('event_triggers','event'),@('tables','table'),@('policies','policy'),@('triggers','trigger'),@('functions','function'),@('default_acl','defacl'))){if(!(Equal-Array $remote.($pair[0]) $local.($pair[0]) $pair[1])){$diff.Add($pair[0])}}
if((Catalog-Key $remote.extensions_schema 'schemaacl') -cne (Catalog-Key $local.extensions_schema 'schemaacl')){$diff.Add('extensions_schema_owner_acl')}
if(!(Equal-Data $remote.data $local.data)){$diff.Add('aggregate_data_fingerprints')}
if($diff.Count){throw ('DEV/rehearsal catalog mismatch: '+($diff -join ','))}
$result=[pscustomobject]@{project_ref=$ref;local_container=$Container;local_database=$Database;remote_pg=$remote.server_version;local_pg=$local.server_version;catalog_categories=7;extension_schema_owner_and_acl='equal';aggregate_data_fingerprints=9;equal=$true}
$result|ConvertTo-Json -Depth 4 -Compress
