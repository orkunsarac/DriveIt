param([Parameter(Mandatory)][string]$PackageDirectory,[switch]$ApplyApprovedFunctions)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $root
try {
 & ./tool/prepare_prod.ps1 -SelfTest
 $package=[IO.Path]::GetFullPath((Join-Path $root $PackageDirectory))
 if(!$package.StartsWith((Join-Path $root 'tmp/r3-approved-'),[StringComparison]::OrdinalIgnoreCase)){throw 'Reviewed R3 package required'}
 $manifest=Get-Content supabase/prod/preparation_manifest.json -Raw|ConvertFrom-Json
 foreach($entry in $manifest.files){
  if($entry.path -match '^supabase/(?:phase8-dev/supabase/)?functions/(.+)$'){
   $copy=Join-Path $package ('supabase/functions/'+$Matches[1])
   $text=[IO.File]::ReadAllText($copy).Replace("`r`n","`n")
   $hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($text)))
   if($hash -cne $entry.sha256){throw 'Packaged Function source differs from reviewed manifest'}
  }
 }
 if((Get-FileHash (Join-Path $package 'supabase/config.toml')).Hash -cne (Get-FileHash supabase/prod/config.toml).Hash){throw 'Function config mismatch'}
 if(!$ApplyApprovedFunctions){'DRY RUN: verified ten Function sources/config; no network or write.';return}
 $ref='arwnbogcswisfesayosy'
 $record=Import-Clixml (Join-Path $env:USERPROFILE '.driveit-secrets/supabase-prod-pat.clixml')
 $secret=if($record -is [Management.Automation.PSCredential]){$record.Password}else{$record}
 $ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
 $previous=[Environment]::GetEnvironmentVariable('SUPABASE_ACCESS_TOKEN')
 try {
  $token=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
  $headers=@{Authorization=('Bearer '+$token)}
  function Api([string]$Path,[string]$Body=''){
   if($Path -notin @('','/config/auth','/database/query','/functions','/secrets')){throw 'Endpoint refused'}
   $request=@{Uri=('https://api.supabase.com/v1/projects/'+$ref+$Path);Headers=$headers;SkipHttpErrorCheck=$true;TimeoutSec=60}
   if($Body){$request.Method='Post';$request.ContentType='application/json';$request.Body=$Body}
   $r=Invoke-WebRequest @request
   if($r.StatusCode -notin @(200,201)){throw ('PROD API refused '+$Path+' HTTP '+$r.StatusCode+'; credentials suppressed')}
   if($r.Content){return $r.Content|ConvertFrom-Json}
  }
  $project=Api '';if($project.id -cne $ref -or $project.status -cne 'ACTIVE_HEALTHY'){throw 'PROD identity/health mismatch'}
  if((Api '/config/auth').disable_signup -ne $true){throw 'Signup must remain closed'}
  $state=@(Api '/database/query' (@{read_only=$true;query="select (select count(*) from supabase_migrations.schema_migrations) as migrations,(select count(*) from auth.users) as users,(select enabled from public.phase8_group_rollout where singleton) as gate;"}|ConvertTo-Json -Compress))[0]
  if($state.migrations -ne 50 -or $state.users -ne 0 -or $state.gate -ne $false){throw 'Upgraded closed empty PROD required'}
  $secrets=@(Api '/secrets')
  foreach($required in @('MAPBOX_ACCESS_TOKEN','PHASE8_CLEANUP_TOKEN')){if($secrets.name -notcontains $required){throw ('Required existing server secret missing: '+$required)}}
  if($secrets.name -notcontains 'ACCOUNT_DELETION_WORKER_TOKEN'){
   $workerPath=Join-Path $env:USERPROFILE '.driveit-secrets/prod-account-deletion-worker.clixml'
   if(Test-Path -LiteralPath $workerPath){throw 'Local worker key already exists without matching server metadata; reconcile before rotation'}
   $bytes=[Security.Cryptography.RandomNumberGenerator]::GetBytes(32)
   $worker=[Convert]::ToHexString($bytes).ToLowerInvariant()
   $secureWorker=ConvertTo-SecureString $worker -AsPlainText -Force
   $secureWorker|Export-Clixml -LiteralPath $workerPath
   $null=Api '/secrets' (ConvertTo-Json -InputObject @(@{name='ACCOUNT_DELETION_WORKER_TOKEN';value=$worker}) -Compress)
   $worker=$null;$secureWorker.Dispose()
   'Server recovery secret configured; encrypted local copy retained. No worker invocation or schedule.'
  }
  $env:SUPABASE_ACCESS_TOKEN=$token
  foreach($name in $manifest.functions){
   $arguments=@('--no-install','supabase@2.120.0','functions','deploy',$name,'--project-ref',$ref,'--workdir',$package,'--use-api')
   if($name -in @('phase8-drive-cleanup','delete-account')){$arguments+='--no-verify-jwt'}
   $result=& npx @arguments 2>&1
   if($LASTEXITCODE -ne 0){
    $code=if(($result -join ' ') -match '\b403\b'){' HTTP 403'}elseif(($result -join ' ') -match '\b401\b'){' HTTP 401'}else{''}
    throw ('Function deployment failed: '+$name+$code+'; raw output suppressed; stop before further writes')
   }
   $live=@(Api '/functions'|Where-Object slug -ceq $name)
   $jwt=$name -notin @('phase8-drive-cleanup','delete-account')
   if($live.Count -ne 1 -or $live[0].status -cne 'ACTIVE' -or $live[0].verify_jwt -ne $jwt){throw ('Function read-back failed: '+$name)}
   'PASS: deployed/read-back '+$name+' JWT='+$jwt
  }
  if((Api '/config/auth').disable_signup -ne $true){throw 'Signup changed unexpectedly'}
 } finally {
  $env:SUPABASE_ACCESS_TOKEN=$previous
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr);$token=$null;$headers=$null;$secret=$null;$record=$null
 }
} finally {Pop-Location}
