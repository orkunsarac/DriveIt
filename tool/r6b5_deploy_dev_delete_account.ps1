Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $root
$env:SUPABASE_TELEMETRY_DISABLED='1'
$ref='viqngnjfgknpxtoapzcg'
$url='https://viqngnjfgknpxtoapzcg.supabase.co'
$cli=(Resolve-Path 'tmp\supabase-cli-npm-cache\_npx\6f1b058a4d9555af\node_modules\.bin\supabase.cmd').Path
$work=Join-Path $root ('tmp\r6b5-dev-function-work-'+[guid]::NewGuid().ToString('N'))
$functionRoot=Join-Path $work 'supabase\functions'
New-Item -ItemType Directory -Path $functionRoot -Force|Out-Null
$cfg=@"
project_id = "driveit-r6b5-dev-$([guid]::NewGuid().ToString('N').Substring(0,8))"

[functions.delete-account]
verify_jwt = false
"@
Set-Content -LiteralPath (Join-Path $work 'supabase\config.toml') -Value $cfg -Encoding utf8

function Invoke-Cli([string[]]$argv,[string]$label){$old=$ErrorActionPreference;$ErrorActionPreference='Continue';try{$out=@(& $cli @argv 2>&1);$code=$LASTEXITCODE}finally{$ErrorActionPreference=$old};if($code -ne 0){throw ($label+' failed; CLI output suppressed to protect credentials. Stop and inspect remote state before retrying.')};return ,$out}
function Invoke-Remote([string]$sql,[bool]$parse=$false){$file=Join-Path $work ('query-'+[guid]::NewGuid().ToString('N')+'.sql');[IO.File]::WriteAllText($file,$sql,[Text.UTF8Encoding]::new($false));$out=Invoke-Cli @('db','query','--linked','--project-ref',$ref,'--workdir',$work,'--file',$file,'--output-format','json') 'DEV catalog query';if(!$parse){return $null};$text=($out|ForEach-Object{$_.ToString()})-join "`n";$start=$text.IndexOf('{');$end=$text.LastIndexOf('}');if($start -lt 0 -or $end -lt $start){throw 'DEV query output is not JSON.'};return ($text.Substring($start,$end-$start+1)|ConvertFrom-Json).rows}
function Invoke-ConfigRead(){if(!$env:SUPABASE_ACCESS_TOKEN){throw 'Management credential unavailable.'};$headers=@{Authorization=('Bearer '+$env:SUPABASE_ACCESS_TOKEN)};try{$r=Invoke-WebRequest -Uri ('https://api.supabase.com/v1/projects/'+$ref+'/config/auth') -Headers $headers -Method Get -SkipHttpErrorCheck -TimeoutSec 30;if($r.StatusCode -ne 200){throw ('DEV auth config read returned HTTP '+$r.StatusCode)};return ($r.Content|ConvertFrom-Json)}finally{$headers=$null;$r=$null}}
function Json-Command([string[]]$argv,[string]$name){$out=Invoke-Cli $argv $name;$line=@($out|Where-Object{$_.ToString().TrimStart().StartsWith('{')})|Select-Object -Last 1;if(!$line){throw ($name+' returned no JSON')};return ($line.ToString()|ConvertFrom-Json)}

if(!$env:SUPABASE_ACCESS_TOKEN){throw 'Supabase Management credential unavailable.'}
$manifest=Get-Content -LiteralPath 'supabase/prod/preparation_manifest.json' -Raw|ConvertFrom-Json
foreach($path in @('supabase/functions/delete-account/index.ts','supabase/functions/delete-account/planet_rebuild.ts')){if(@($manifest.files|Where-Object path -CEQ $path).Count -ne 1){throw ('Function manifest dependency missing: '+$path)}}
$functionFiles=@($manifest.files|Where-Object{$_.path -match '^supabase/functions/(delete-account|process-world-publish)/'})
if(!$functionFiles.Count){throw 'delete-account runtime manifest is empty.'}
foreach($entry in $functionFiles){$source=Join-Path $root $entry.path;$text=[IO.File]::ReadAllText($source).Replace("`r`n","`n");$hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($text)));if($hash -cne $entry.sha256){throw ('delete-account runtime source hash mismatch: '+$entry.path)};$target=Join-Path $work $entry.path;New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force|Out-Null;[IO.File]::WriteAllText($target,$text,[Text.UTF8Encoding]::new($false))}

$projects=Json-Command @('projects','list','--output-format','json') 'DEV identity inventory';$projectMatches=@($projects.projects|Where-Object id -CEQ $ref);if($projectMatches.Count -ne 1 -or $projectMatches[0].name -cne 'DriveIT DEV' -or $projectMatches[0].status -cne 'ACTIVE_HEALTHY'){throw 'DEV identity/health check failed.'}
$functionBefore=Json-Command @('functions','list','--project-ref',$ref,'--output-format','json') 'Function inventory'
if(@($functionBefore.functions|Where-Object slug -CEQ 'delete-account').Count){throw 'delete-account already exists; refusing to overwrite an unreviewed version.'}
$secretBefore=Json-Command @('secrets','list','--project-ref',$ref,'--output-format','json') 'Secret names inventory'
if(@($secretBefore.secrets|Where-Object name -CEQ 'ACCOUNT_DELETION_WORKER_TOKEN').Count){throw 'Worker secret already exists; refusing to rotate it.'}
$state=Invoke-Remote "SELECT jsonb_build_object('migrations',(SELECT count(*) FROM supabase_migrations.schema_migrations),'gate',(SELECT enabled FROM public.phase8_group_rollout WHERE singleton),'jobs_rls',(SELECT relrowsecurity FROM pg_class WHERE oid='public.account_deletion_jobs'::regclass),'audit_rls',(SELECT relrowsecurity FROM pg_class WHERE oid='public.account_deletion_erasure_audit'::regclass),'purge_owner',(SELECT pg_get_userbyid(proowner) FROM pg_proc WHERE oid='public.account_deletion_purge(uuid,uuid)'::regprocedure),'purge_definer',(SELECT prosecdef FROM pg_proc WHERE oid='public.account_deletion_purge(uuid,uuid)'::regprocedure),'purge_service_exec',has_function_privilege('service_role','public.account_deletion_purge(uuid,uuid)','EXECUTE'),'purge_auth_exec',has_function_privilege('authenticated','public.account_deletion_purge(uuid,uuid)','EXECUTE'),'leases_delete',has_table_privilege('service_role','public.phase8_drive_leases','DELETE'),'tombstone_delete',has_table_privilege('service_role','public.phase8_drive_tombstones','DELETE'),'tombstone_update',has_table_privilege('service_role','public.phase8_drive_tombstones','UPDATE'),'staging_helper',has_function_privilege('service_role','public.phase8_can_access_staging_object(text)','EXECUTE'),'group_rpc',has_function_privilege('service_role','public.phase8_group_command(text,uuid,text,uuid,boolean)','EXECUTE'),'geometry_helper',has_function_privilege('service_role','public.world_section_geometry_length_meters(extensions.geometry)','EXECUTE')) AS value;" $true
if(@($state).Count -ne 1){throw 'Post-migration catalog query returned an unexpected shape.'};$v=$state[0].value
if([int]$v.migrations -ne 52 -or $v.gate -ne $false -or $v.jobs_rls -ne $true -or $v.audit_rls -ne $true -or $v.purge_owner -cne 'postgres' -or $v.purge_definer -ne $true -or $v.purge_service_exec -ne $true -or $v.purge_auth_exec -ne $false -or $v.leases_delete -ne $false -or $v.tombstone_delete -ne $false -or $v.tombstone_update -ne $false -or $v.staging_helper -ne $false -or $v.group_rpc -ne $false -or $v.geometry_helper -ne $false){throw 'DEV post-migration security catalog differs from approved baseline.'}
$cron=Invoke-Remote "SELECT coalesce(to_regclass('cron.job')::text,'absent') AS value;" $true;if(@($cron).Count -ne 1){throw 'Scheduler catalog probe failed.'};$cronJobs=0;if($cron[0].value -cne 'absent'){$cronRows=Invoke-Remote "SELECT count(*)::text AS value FROM cron.job WHERE active AND (command ILIKE '%delete-account%' OR command ILIKE '%account_deletion%');" $true;$cronJobs=[int]$cronRows[0].value};if($cronJobs -ne 0){throw 'An active deletion scheduler exists; refusing Function activation.'}
$authBefore=Invoke-ConfigRead

# Preserve the secret only as DPAPI CurrentUser ciphertext outside the repo.
# The temporary .env is ACL-protected and removed immediately after CLI use.
$secretDir=Join-Path $env:LOCALAPPDATA 'DriveIt\Secrets'
if(!(Test-Path -LiteralPath $secretDir)){New-Item -ItemType Directory -Path $secretDir -Force|Out-Null;$acl=[Security.AccessControl.DirectorySecurity]::new();$acl.SetAccessRuleProtection($true,$false);foreach($sid in @([Security.Principal.WindowsIdentity]::GetCurrent().User,[Security.Principal.SecurityIdentifier]::new('S-1-5-18'))){$rule=[Security.AccessControl.FileSystemAccessRule]::new($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow');$acl.AddAccessRule($rule)};Set-Acl -LiteralPath $secretDir -AclObject $acl}
$resolvedSecretDir=(Resolve-Path -LiteralPath $secretDir).Path;if(($resolvedSecretDir -cne $secretDir) -or ((Get-Item -LiteralPath $secretDir).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Worker secret directory path is unsafe.'};$dirAcl=Get-Acl -LiteralPath $secretDir;$allowedSids=@([Security.Principal.WindowsIdentity]::GetCurrent().User.Value,'S-1-5-18');if(!$dirAcl.AreAccessRulesProtected -or $dirAcl.Access.Count -ne 2){throw 'Worker secret directory ACL is not protected.'};foreach($r in $dirAcl.Access){if($r.AccessControlType -ne 'Allow' -or $r.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value -notin $allowedSids){throw 'Unexpected worker secret directory principal.'}}
$cipherPath=Join-Path $secretDir 'r6b5-dev-account-deletion-worker-token.dpapi';if(Test-Path -LiteralPath $cipherPath){throw 'Encrypted worker token file already exists; refusing overwrite.'}
$bytes=[Security.Cryptography.RandomNumberGenerator]::GetBytes(32);$token=[Convert]::ToHexString($bytes).ToLowerInvariant();[Array]::Clear($bytes,0,$bytes.Length);$cipher=[Security.Cryptography.ProtectedData]::Protect([Text.Encoding]::UTF8.GetBytes($token),$null,[Security.Cryptography.DataProtectionScope]::CurrentUser);[IO.File]::WriteAllBytes($cipherPath,$cipher);[Array]::Clear($cipher,0,$cipher.Length)
$envPath=Join-Path $secretDir ('worker-'+[guid]::NewGuid().ToString('N')+'.env')
try{
  [IO.File]::WriteAllText($envPath,('ACCOUNT_DELETION_WORKER_TOKEN='+$token),[Text.UTF8Encoding]::new($false))
  $verify=[Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($cipherPath),$null,[Security.Cryptography.DataProtectionScope]::CurrentUser);$restored=[Text.Encoding]::UTF8.GetString($verify);[Array]::Clear($verify,0,$verify.Length);if($restored -cne $token -or $token -cnotmatch '^[0-9a-f]{64}$'){throw 'Worker token local encryption/format verification failed.'}
  [void](Invoke-Cli @('secrets','set','--project-ref',$ref,'--workdir',$work,'--env-file',$envPath) 'DEV worker secret set')
}finally{if(Test-Path -LiteralPath $envPath){$full=(Resolve-Path -LiteralPath $envPath).Path;if($full.StartsWith($resolvedSecretDir+'\',[StringComparison]::OrdinalIgnoreCase)){Remove-Item -LiteralPath $full -Force}};$token=$null;$restored=$null}
$secretAfter=Json-Command @('secrets','list','--project-ref',$ref,'--output-format','json') 'Worker secret verification';if(@($secretAfter.secrets|Where-Object name -CEQ 'ACCOUNT_DELETION_WORKER_TOKEN').Count -ne 1){throw 'Worker secret name not present after setting.'}

$deploy=Invoke-Cli @('functions','deploy','delete-account','--project-ref',$ref,'--workdir',$work,'--use-api','--no-verify-jwt') 'Single delete-account Function deployment'
$functionAfter=Json-Command @('functions','list','--project-ref',$ref,'--output-format','json') 'Post-deployment Function inventory'
$target=@($functionAfter.functions|Where-Object slug -CEQ 'delete-account');if($target.Count -ne 1 -or $target[0].status -cne 'ACTIVE' -or $target[0].verify_jwt -ne $false){throw 'delete-account deployment status/JWT mode mismatch.'}
foreach($old in $functionBefore.functions){$now=@($functionAfter.functions|Where-Object slug -CEQ $old.slug);if($now.Count -ne 1 -or $now[0].ezbr_sha256 -cne $old.ezbr_sha256 -or $now[0].updated_at -ne $old.updated_at){throw ('Unapproved Function code/timestamp changed during delete-account deployment: '+$old.slug)}}
$authAfter=Invoke-ConfigRead;if($authAfter.disable_signup -ne $authBefore.disable_signup){throw 'Auth signup setting changed unexpectedly.'}
$finalGate=Invoke-Remote "SELECT enabled::text AS value FROM public.phase8_group_rollout WHERE singleton;" $true;if([string]$finalGate[0].value -cne 'false'){throw 'Group Drive gate changed after Function deployment.'}
$summary=[pscustomobject]@{project_ref=$ref;function='delete-account';function_version=$target[0].version;verify_jwt=$target[0].verify_jwt;deletion_worker_secret_configured=$true;worker_secret_encrypted_local=$true;cron_enabled_deletion_jobs=$cronJobs;signup_changed=$false;signup_currently_disabled=[bool]$authAfter.disable_signup;group_drive_enabled=$false;other_functions_code_changed=$false;other_functions_updated_at_changed=$false}
$summary|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $secretDir 'r6b5-dev-delete-account-deployment.json') -Encoding utf8
Write-Output ('PASS: DEV delete-account deployed as version '+$target[0].version+'; verify_jwt=false; worker secret set; cron unchanged; other Functions unchanged.')
