param([switch]$RunApprovedTests,[switch]$ResumeCleanup)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Set-Location (Join-Path $PSScriptRoot '..')
if(!$RunApprovedTests){'DRY RUN: use explicit approved hosted-test switch; no connection or users created.';return}
$audit=(& ./tool/prod_readiness_audit.ps1)|ConvertFrom-Json
if($audit.projectRef -cne 'arwnbogcswisfesayosy' -or $audit.status -cne 'ACTIVE_HEALTHY' -or $audit.disableSignup -ne $true -or $audit.evidence.migrationCount -ne 52 -or $audit.evidence.gate -ne $false -or $audit.activeDeletionSchedules -ne 0){throw 'Hosted closed-PROD preconditions failed'}
if($ResumeCleanup){
 $run=(Get-Content tmp/hosted-test-current.json -Raw|ConvertFrom-Json).runId
}else{
 if($audit.evidence.authUsers -ne 0){throw 'Fresh hosted run requires zero users; never clean unknown accounts'}
 if(Test-Path -LiteralPath tmp/hosted-test-current.json){
  $previousRun=(Get-Content tmp/hosted-test-current.json -Raw|ConvertFrom-Json).runId
  & ./tool/verify_hosted_cleanup.ps1 -RunId $previousRun
 }
 $run=[guid]::NewGuid().ToString()
 @{runId=$run}|ConvertTo-Json|Set-Content tmp/hosted-test-current.json
}
if($run -cnotmatch '^[a-f0-9-]{36}$'){throw 'Invalid explicit run descriptor'}
$folder=Join-Path $env:USERPROFILE '.driveit-secrets'
$pat=Import-Clixml (Join-Path $folder 'supabase-prod-pat.clixml');if($pat -is [Management.Automation.PSCredential]){$pat=$pat.Password}
$map=Import-Clixml (Join-Path $folder 'prod-mapbox-token.clixml')
$ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($pat);$mptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($map)
$names=@('DRIVEIT_HOSTED_RUN_ID','DRIVEIT_HOSTED_APPROVAL','DRIVEIT_HOSTED_PUBLIC_KEY','DRIVEIT_HOSTED_SERVICE_KEY','DRIVEIT_HOSTED_MAPBOX','DRIVEIT_HOSTED_CLEANUP_ONLY');$saved=@{}
foreach($name in $names){$saved[$name]=[Environment]::GetEnvironmentVariable($name)}
try {
 $token=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
 $response=Invoke-WebRequest -Uri 'https://api.supabase.com/v1/projects/arwnbogcswisfesayosy/api-keys' -Headers @{Authorization=('Bearer '+$token)} -SkipHttpErrorCheck
 if($response.StatusCode -ne 200){throw ('Server test key access refused HTTP '+$response.StatusCode)}
 $keys=@($response.Content|ConvertFrom-Json)
 $public=@($keys|Where-Object name -ceq 'anon');$service=@($keys|Where-Object name -ceq 'service_role')
 if($public.Count -ne 1 -or $service.Count -ne 1 -or !$public[0].api_key -or !$service[0].api_key){throw 'Expected server-side test keys missing; values suppressed'}
 $env:DRIVEIT_HOSTED_RUN_ID=$run
 $env:DRIVEIT_HOSTED_APPROVAL='APPROVED_TWO_SYNTHETIC_USERS'
 $env:DRIVEIT_HOSTED_PUBLIC_KEY=$public[0].api_key
 $env:DRIVEIT_HOSTED_SERVICE_KEY=$service[0].api_key
 $env:DRIVEIT_HOSTED_MAPBOX=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($mptr)
 $env:DRIVEIT_HOSTED_CLEANUP_ONLY=if($ResumeCleanup){'true'}else{'false'}
 & 'C:\Users\PC\.deno\bin\deno.exe' test --allow-env --allow-read=. --allow-run=pwsh --allow-net=arwnbogcswisfesayosy.supabase.co,api.mapbox.com supabase/prod/tests/hosted_acceptance_test.ts
 $testExit=$LASTEXITCODE
 & ./tool/verify_hosted_cleanup.ps1 -RunId $run
 $final=(& ./tool/prod_readiness_audit.ps1)|ConvertFrom-Json
 if($final.evidence.authUsers -ne 0 -or $final.evidence.gate -ne $false -or $final.disableSignup -ne $true -or $final.activeDeletionSchedules -ne 0){throw 'Final hosted cleanup/gates failed'}
 if($testExit -ne 0){throw 'Hosted scenario failed but scoped cleanup verified; encrypted journal retained.'}
 'PASS: zero remaining accounts; signup/group/worker schedule closed. No real email sent.'
} finally {
 foreach($name in $names){[Environment]::SetEnvironmentVariable($name,$saved[$name])}
 [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr);[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($mptr)
 $token=$null;$keys=$null;$public=$null;$service=$null;$response=$null;$pat=$null;$map=$null
}
