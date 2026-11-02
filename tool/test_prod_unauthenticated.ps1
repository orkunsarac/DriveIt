# No credential, user creation, RPC mutation or worker invocation.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$base='https://arwnbogcswisfesayosy.supabase.co/functions/v1/'
$functions=@('process-world-publish','planet-trace-detail','phase8-drive-begin','phase8-drive-finalize','phase8-drive-download','phase8-drive-delete','phase8-drive-lease','phase8-drive-cleanup','phase8-group-publish')
$passed=0
foreach($name in $functions){
 $r=Invoke-WebRequest -Uri ($base+$name) -Method Post -ContentType application/json -Body '{}' -SkipHttpErrorCheck -TimeoutSec 30
 if($r.StatusCode -ne 401){throw ('Unauthenticated request not rejected as expected: '+$name+' HTTP '+$r.StatusCode)}
 $passed++
}
$cases=@(
 @{body=@{action='request';requestId='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';receiptToken=('a'*64);expectedOwner='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';confirm='DELETE_MY_ACCOUNT';password='synthetic-invalid'};status=401},
 @{body=@{action='worker_status'};status=401},
 @{body=@{action='run';requestId='invalid';receiptToken='invalid'};status=400}
)
foreach($case in $cases){
 $r=Invoke-WebRequest -Uri ($base+'delete-account') -Method Post -ContentType application/json -Body ($case.body|ConvertTo-Json -Compress) -SkipHttpErrorCheck -TimeoutSec 30
 if($r.StatusCode -ne $case.status){throw ('Deletion unauthenticated contract mismatch HTTP '+$r.StatusCode)}
 $passed++
}
'PASS: '+$passed+' hosted unauthenticated rejections; no account or worker action authorized.'
