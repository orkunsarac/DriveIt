param()
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
# Supabase CLI progress may use stderr even when startup succeeds. Do not let
# PowerShell turn native stderr text into a terminating ErrorRecord.
if(Test-Path variable:PSNativeCommandUseErrorActionPreference){$PSNativeCommandUseErrorActionPreference=$false}
Push-Location (Join-Path $PSScriptRoot '..')
$testEnvNames=@('DRIVEIT_EMAIL_TEST_API','DRIVEIT_MAILPIT_API','DRIVEIT_EMAIL_TEST_ANON','DRIVEIT_EMAIL_TEST_SERVICE')
$savedTestEnv=@{}
foreach($name in $testEnvNames){$savedTestEnv[$name]=[Environment]::GetEnvironmentVariable($name,'Process')}
function Invoke-SupabaseCli([string]$arguments){
  $psi=New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName='C:\Program Files\nodejs\node.exe'
  $psi.Arguments='"C:\Program Files\nodejs\node_modules\npm\bin\npx-cli.js" --no-install supabase@2.120.0 '+$arguments
  $psi.WorkingDirectory=(Get-Location).Path
  $psi.UseShellExecute=$false;$psi.CreateNoWindow=$true
  $psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
  $process=New-Object System.Diagnostics.Process;$process.StartInfo=$psi
  if(!$process.Start()){throw 'Could not start local Supabase CLI'}
  $outTask=$process.StandardOutput.ReadToEndAsync();$errTask=$process.StandardError.ReadToEndAsync()
  if(!$process.WaitForExit(240000)){$process.Kill();throw 'Local Supabase CLI timeout'}
  $process.WaitForExit()
  [pscustomobject]@{ExitCode=$process.ExitCode;Stdout=$outTask.GetAwaiter().GetResult();Stderr=$errTask.GetAwaiter().GetResult()}
}
try {
  $work='supabase/email-test'
  $config=Get-Content "$work/supabase/config.toml" -Raw
  if($config -notmatch '(?m)^project_id\s*=\s*"driveit-email-pgr6d"\s*$'){throw 'Email test project identity mismatch'}
  if($config -match '(?i)viqngnjfgknpxtoapzcg|arwnbogcswisfesayosy|SUPABASE_ACCESS_TOKEN'){throw 'Remote target marker in local email config'}

  # Capture CLI output only in process memory: `status --output env` contains local keys.
  $startResult=Invoke-SupabaseCli 'start --workdir supabase/email-test'
  if($startResult.ExitCode -ne 0){throw 'Local Supabase start failed; CLI output withheld to avoid credential disclosure'}
  $statusResult=Invoke-SupabaseCli 'status --workdir supabase/email-test --output env'
  if($statusResult.ExitCode -ne 0){throw 'Local Supabase status failed; CLI output withheld'}
  $statusText=$statusResult.Stdout+"`n"+$statusResult.Stderr
  $values=@{}
  foreach($name in @('API_URL','DB_URL','ANON_KEY','SERVICE_ROLE_KEY')){
    $match=[regex]::Match($statusText,"(?m)^$name=(.*)$")
    if(!$match.Success){throw "Local status missing $name"}
    $values[$name]=$match.Groups[1].Value.Trim().Trim('"').Trim("'")
  }
  $api=[uri]$values.API_URL
  if($api.Scheme -cne 'http' -or $api.Host -cne '127.0.0.1' -or $api.Port -ne 63121){throw 'Refusing non-isolated Auth endpoint'}
  $db=[uri]$values.DB_URL
  if($db.Scheme -notin @('postgres','postgresql') -or $db.Host -cne '127.0.0.1' -or $db.Port -ne 63122){throw 'Refusing non-isolated DB endpoint'}
  if(!$values.ANON_KEY -or !$values.SERVICE_ROLE_KEY){throw 'Local test keys unavailable'}
  $mailpit='http://127.0.0.1:63124'
  if((Invoke-WebRequest -Uri "$mailpit/api/v1/info" -TimeoutSec 8 -UseBasicParsing).StatusCode -ne 200){throw 'Local Mailpit API unavailable'}

  $env:DRIVEIT_EMAIL_TEST_API=$api.ToString().TrimEnd('/')
  $env:DRIVEIT_MAILPIT_API=$mailpit
  $env:DRIVEIT_EMAIL_TEST_ANON=$values.ANON_KEY
  $env:DRIVEIT_EMAIL_TEST_SERVICE=$values.SERVICE_ROLE_KEY
  & 'C:\Users\PC\.deno\bin\deno.exe' test --allow-env=DRIVEIT_EMAIL_TEST_API,DRIVEIT_MAILPIT_API,DRIVEIT_EMAIL_TEST_ANON,DRIVEIT_EMAIL_TEST_SERVICE --allow-net=127.0.0.1 --allow-read=site,supabase/email-test/templates,.github/workflows site/tests/deletion_pages_test.ts supabase/email-test/tests/auth_email_flows_test.ts
  if($LASTEXITCODE -ne 0){throw "Email integration tests failed with exit code $LASTEXITCODE"}
  'PASS: Auth/Mailpit integration and deletion/privacy page checks; loopback only'
} finally {
  foreach($name in $testEnvNames){
    if($null -eq $savedTestEnv[$name]){[Environment]::SetEnvironmentVariable($name,$null,'Process')}
    else{[Environment]::SetEnvironmentVariable($name,$savedTestEnv[$name],'Process')}
  }
  Pop-Location
}
