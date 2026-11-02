param([Parameter(Mandatory)][string]$PackageDirectory,[switch]$ApplyApprovedUpgrade,[switch]$RoadVersionCorrection)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $root
try {
 & ./tool/prepare_prod.ps1 -SelfTest
 $package=[IO.Path]::GetFullPath((Join-Path $root $PackageDirectory))
 if(!$package.StartsWith((Join-Path $root 'tmp/r3-approved-'),[StringComparison]::OrdinalIgnoreCase)){throw 'Only a reviewed R3 package is permitted'}
 $actual=Join-Path $package $(if($RoadVersionCorrection){'road-version-correction.sql'}else{'upgrade.sql'})
 $verification='tmp/r3-upgrade-verify-'+[guid]::NewGuid().ToString('N')+'.sql'
 $buildArgs=@('run','--allow-read','--allow-write=tmp','tool/build_prod_upgrade.ts',$verification)
 if($RoadVersionCorrection){$buildArgs+='--road-version-correction'}
 & 'C:\Users\PC\.deno\bin\deno.exe' @buildArgs
 if($LASTEXITCODE -ne 0 -or (Get-FileHash $actual).Hash -cne (Get-FileHash $verification).Hash){throw 'Package does not match current verified sources'}
 if(!$ApplyApprovedUpgrade){'DRY RUN: verified additive upgrade; no connection or write.';return}
 $ref='arwnbogcswisfesayosy'
 $record=Import-Clixml (Join-Path $env:USERPROFILE '.driveit-secrets/supabase-prod-pat.clixml')
 $secret=if($record -is [Management.Automation.PSCredential]){$record.Password}else{$record}
 $ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
 try {
  $token=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
  $headers=@{Authorization=('Bearer '+$token)}
  function Api([string]$Path,[string]$Query='', [bool]$ReadOnly=$true){
   if($Path -notin @('','/config/auth','/database/query','/secrets')){throw 'Endpoint refused'}
   $request=@{Uri=('https://api.supabase.com/v1/projects/'+$ref+$Path);Headers=$headers;SkipHttpErrorCheck=$true;TimeoutSec=180}
   if($Query){$request.Method='Post';$request.ContentType='application/json';$request.Body=@{query=$Query;read_only=$ReadOnly}|ConvertTo-Json -Compress}
   $response=Invoke-WebRequest @request
   if($response.StatusCode -notin @(200,201)){throw ('PROD API refused '+$Path+' HTTP '+$response.StatusCode+'; response content suppressed. Do not retry writes before inspecting history.')}
   return $response.Content|ConvertFrom-Json
  }
  $project=Api '';if($project.id -cne $ref -or $project.status -cne 'ACTIVE_HEALTHY'){throw 'PROD identity/health mismatch'}
  if((Api '/config/auth').disable_signup -ne $true){throw 'Signup must stay disabled'}
  $secrets=@(Api '/secrets')
  foreach($required in @('MAPBOX_ACCESS_TOKEN','PHASE8_CLEANUP_TOKEN')){
   if($secrets.name -notcontains $required){throw ('Required PROD server secret missing before migration: '+$required)}
  }
  $state=Api '/database/query' "select (select count(*) from auth.users) as users,(select enabled from public.phase8_group_rollout where singleton) as gate,to_regclass('public.account_deletion_jobs') is not null as deletion;"
  if(@($state)[0].users -ne 0 -or @($state)[0].gate -ne $false -or @($state)[0].deletion -ne [bool]$RoadVersionCorrection){throw 'Unexpected PROD state; installation refused'}
  $history=@(Api '/database/query' 'select version,statements from supabase_migrations.schema_migrations order by version;')
  $expected=@((Get-Content supabase/prod/preparation_manifest.json -Raw|ConvertFrom-Json).files|Where-Object kind -eq 'migration')
  if($RoadVersionCorrection){$expected+=@((Get-Content supabase/prod/upgrade_manifest.json -Raw|ConvertFrom-Json).files)}
  if($history.Count -ne $expected.Count){throw 'Unexpected base history count'}
  for($i=0;$i -lt $expected.Count;$i++){
   $version=([IO.Path]::GetFileName($expected[$i].path)-split '_')[0]
   $sql=($history[$i].statements -join "`n").Replace("`r`n","`n")
   $hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($sql)))
   if($history[$i].version -cne $version -or $hash -cne $expected[$i].sha256){throw ('Stored base migration differs from reviewed source: '+$version)}
  }
  'PASS: fixed PROD identity, signup, zero users, closed group gate and exact base history hashes.'
  $null=Api '/database/query' (Get-Content $actual -Raw) $false
  $final=Api '/database/query' "select (select count(*) from supabase_migrations.schema_migrations) as migrations,(select count(*) from auth.users) as users,(select enabled from public.phase8_group_rollout where singleton) as gate,to_regclass('public.account_deletion_erasure_audit') is not null as audit;"
  $finalCount=if($RoadVersionCorrection){52}else{50}
  if(@($final)[0].migrations -ne $finalCount -or @($final)[0].users -ne 0 -or @($final)[0].gate -ne $false -or @($final)[0].audit -ne $true){throw 'Post-upgrade acceptance failed; do not retry'}
  if((Api '/config/auth').disable_signup -ne $true){throw 'Signup changed unexpectedly'}
  "PASS: approved PROD transaction committed; $finalCount migrations, zero users, group gate FALSE, signup disabled."
 } finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr);$token=$null;$headers=$null;$secret=$null;$record=$null
 }
} finally {Pop-Location}
