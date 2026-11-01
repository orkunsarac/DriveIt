param(
 [ValidateSet('open','resend','verify','consent','status','retry')][string]$Action,
 [string]$CaseId=''
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(Test-Path variable:PSNativeCommandUseErrorActionPreference){$PSNativeCommandUseErrorActionPreference=$false}
Push-Location (Join-Path $PSScriptRoot '..')
$envNames=@('PGR6_LOCAL_URL','PGR6_ANON','PGR6_SERVICE','ACCOUNT_DELETION_WORKER_TOKEN','PGR6F_OPERATOR_TOKEN','PGR6F_FINGERPRINT_KEY','PGR6F_CASE_DB','PGR6F_MAILPIT_URL')
$saved=@{};foreach($name in $envNames){$saved[$name]=[Environment]::GetEnvironmentVariable($name,'Process')}
$savedStackFlag=[Environment]::GetEnvironmentVariable('SUPABASE_EXPERIMENTAL_STACK','Process')
$env:SUPABASE_EXPERIMENTAL_STACK='1'
$plainOperatorToken='';$ptr=[IntPtr]::Zero
try{
 $descriptorPath='tmp/pgr6a-target.json';if(!(Test-Path -LiteralPath $descriptorPath)){throw 'Prepare the isolated P-GR6A test stack first'}
 $descriptor=Get-Content $descriptorPath -Raw|ConvertFrom-Json
 if($descriptor.name -notmatch '^pgr6a-[0-9a-f]{10}$' -or $descriptor.work -cne ('tmp/'+$descriptor.name)){throw 'Isolated stack descriptor invalid'}
 $previousErrorAction=$ErrorActionPreference;$ErrorActionPreference='Continue'
 try{$statusRaw=& npx --no-install supabase@2.120.0 stack status --stack-id $descriptor.id --workdir $descriptor.work --output-format json 2>$null;$cliExit=$LASTEXITCODE}
 finally{$ErrorActionPreference=$previousErrorAction}
 if($cliExit -ne 0){throw 'Pinned local stack status failed'}
 $state=$statusRaw|ConvertFrom-Json
 if($state.identity.id -cne $descriptor.id -or $state.identity.name -cne $descriptor.name){throw 'Stack identity mismatch'}
 $api=[uri]$state.env.API_URL;$db=[uri]$state.env.DB_URL
 if($api.Scheme -cne 'http' -or $api.Host -cne '127.0.0.1' -or $db.Host -cne '127.0.0.1'){throw 'Refusing non-loopback Supabase target'}
 $containers=@(docker ps --format '{{.Names}}'|Where-Object {$_ -match ('^supabase-'+[regex]::Escape($descriptor.name)+'-'+[regex]::Escape($descriptor.name)+'-database-[a-f0-9]+$')})
 if($containers.Count -ne 1){throw 'Pinned local database container ambiguous'}
 $raw=docker inspect --format '{{json .HostConfig.Mounts}}' $containers[0]
 if($LASTEXITCODE -ne 0){throw 'Local database mount inspection failed'}
 $targetCount=([regex]::Matches($raw,'"Target":"/var/lib/postgresql/data"')).Count
 $source=[regex]::Match($raw,'"Source":"([^"]+)","Target":"/var/lib/postgresql/data"')
 $subpath=[regex]::Match($raw,'"Target":"/var/lib/postgresql/data","VolumeOptions":\{"Subpath":"([^"]+)"\}')
 if($targetCount -ne 1 -or !$source.Success -or !$subpath.Success -or ($source.Groups[1].Value+'|'+$subpath.Groups[1].Value) -cne $descriptor.subpath){throw 'Local physical PGDATA pin unavailable'}
 $system=docker exec $containers[0] psql -U postgres -d postgres -X -At -c 'select system_identifier from pg_control_system();'
 if($LASTEXITCODE -ne 0 -or $system -cne $descriptor.system){throw 'Local PostgreSQL system identity changed'}
 $health=Invoke-WebRequest -Uri ($api.ToString().TrimEnd('/')+'/auth/v1/health') -TimeoutSec 8 -UseBasicParsing
 if($health.StatusCode -ne 200){throw 'Local Auth health check failed'}
 $mailpit='http://127.0.0.1:63124';$mailHealth=Invoke-WebRequest -Uri ($mailpit+'/api/v1/info') -TimeoutSec 8 -UseBasicParsing
 if($mailHealth.StatusCode -ne 200){throw 'Loopback Mailpit health check failed'}
 $workerFile=Join-Path (Get-Location) ($descriptor.work+'/supabase/functions/.env')
 $workerMatch=[regex]::Match((Get-Content $workerFile -Raw),'(?m)^ACCOUNT_DELETION_WORKER_TOKEN=([0-9a-f]{64})\s*$')
 if(!$workerMatch.Success){throw 'Pinned local worker secret unavailable'}
 $worker=$workerMatch.Groups[1].Value

 $keyFile=Join-Path (Get-Location) ($descriptor.work+'/support-operator-token.clixml')
 if(Test-Path -LiteralPath $keyFile){$credential=Import-Clixml -LiteralPath $keyFile;if($credential -isnot [Management.Automation.PSCredential]){throw 'Local DPAPI operator record invalid'};$secure=$credential.Password}
 else{
  $bytes=New-Object byte[] 32;$rng=[Security.Cryptography.RandomNumberGenerator]::Create();try{$rng.GetBytes($bytes)}finally{$rng.Dispose()}
  $token=[BitConverter]::ToString($bytes).Replace('-','').ToLowerInvariant();$secure=ConvertTo-SecureString $token -AsPlainText -Force
  (New-Object Management.Automation.PSCredential('DriveIt P-GR6F Local Operator',$secure))|Export-Clixml -LiteralPath $keyFile
 }
 $ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
 $plainOperatorToken=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
 if($plainOperatorToken -notmatch '^[0-9a-f]{64}$'){throw 'Local operator credential invalid'}

 $env:PGR6_LOCAL_URL=$api.ToString().TrimEnd('/');$env:PGR6_ANON=$state.env.ANON_KEY;$env:PGR6_SERVICE=$state.env.SERVICE_ROLE_KEY
 $env:ACCOUNT_DELETION_WORKER_TOKEN=$worker;$env:PGR6F_OPERATOR_TOKEN=$plainOperatorToken
 $env:PGR6F_CASE_DB=Join-Path (Get-Location) ($descriptor.work+'/support-cases.sqlite')
 $env:PGR6F_MAILPIT_URL=$mailpit
 $arguments=@('run',"--allow-env=PGR6_LOCAL_URL,PGR6_ANON,PGR6_SERVICE,ACCOUNT_DELETION_WORKER_TOKEN,PGR6F_OPERATOR_TOKEN,PGR6F_FINGERPRINT_KEY,PGR6F_CASE_DB,PGR6F_MAILPIT_URL",'--allow-net=127.0.0.1',"--allow-read=$($descriptor.work)","--allow-write=$($descriptor.work)",'tool/account_deletion_support.ts',$Action)
 if($CaseId){if($CaseId -notmatch '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'){throw 'Case ID invalid'};$arguments+=$CaseId}
 & 'C:\Users\PC\.deno\bin\deno.exe' @arguments
 if($LASTEXITCODE -ne 0){throw "Local support operator returned exit code $LASTEXITCODE"}
}finally{
 if($ptr -ne [IntPtr]::Zero){[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)}
 $plainOperatorToken=''
 foreach($name in $envNames){if($null -eq $saved[$name]){[Environment]::SetEnvironmentVariable($name,$null,'Process')}else{[Environment]::SetEnvironmentVariable($name,$saved[$name],'Process')}}
 [Environment]::SetEnvironmentVariable('SUPABASE_EXPERIMENTAL_STACK',$savedStackFlag,'Process')
 Pop-Location
}
