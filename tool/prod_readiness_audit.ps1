# Fixed-PROD metadata-only audit. No settings, migration, or data write endpoint.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$ref='arwnbogcswisfesayosy'
$record=Import-Clixml -LiteralPath (Join-Path $env:USERPROFILE '.driveit-secrets/supabase-prod-pat.clixml')
if($record -is [Management.Automation.PSCredential]){$secret=$record.Password}
elseif($record -is [Security.SecureString]){$secret=$record}
else{throw 'Unsupported encrypted PAT record; do not print its contents'}
$ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
try {
 $token=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
 $headers=@{Authorization=('Bearer '+$token)}
 function Read-Prod([string]$Path,[string]$Query=''){
  if($Path -notin @('','/config/auth','/database/query','/functions')){throw 'Endpoint not allowlisted'}
  $args=@{Uri=('https://api.supabase.com/v1/projects/'+$ref+$Path);Headers=$headers;SkipHttpErrorCheck=$true;TimeoutSec=45}
  if($Query){
   if($Path -cne '/database/query' -or $Query -notmatch '^select '){throw 'Only read-only SELECT is permitted'}
   $args.Method='Post';$args.ContentType='application/json';$args.Body=@{query=$Query;read_only=$true}|ConvertTo-Json -Compress
  }
  $r=Invoke-WebRequest @args
  if($r.StatusCode -notin @(200,201)){
   $detail=''
   try {
    $errorBody=$r.Content|ConvertFrom-Json
    if($errorBody.PSObject.Properties['message']){
     $detail=([string]$errorBody.message -replace '(?i)(sbp_|sb_secret_|eyJ)[A-Za-z0-9_.-]+','[redacted]')
     if($detail.Length -gt 500){$detail=$detail.Substring(0,500)}
    }
   } catch { $detail='Response details suppressed' }
   throw ('PROD read failed: '+$Path+' HTTP '+$r.StatusCode+' '+$detail)
  }
  return $r.Content|ConvertFrom-Json
 }
 $project=Read-Prod '';if($project.id -cne $ref){throw 'Project identity mismatch'}
 $auth=Read-Prod '/config/auth'
 $data=Read-Prod '/database/query' "select json_build_object('authUsers',(select count(*) from auth.users),'migrationCount',(select count(*) from supabase_migrations.schema_migrations),'gate',(select enabled from public.phase8_group_rollout where singleton),'publicTables',(select count(*) from pg_class where relnamespace='public'::regnamespace and relkind='r'),'deletionInstalled',to_regclass('public.account_deletion_jobs') is not null) as evidence;"
 $functions=Read-Prod '/functions'
 $storage=Read-Prod '/database/query' "select id,public from storage.buckets where id in ('world-drive-sources','phase8-drive-staging') order by id;"
 $cron=Read-Prod '/database/query' "select to_regclass('cron.job') is not null as installed;"
 $activeDeletionSchedules=0
 if(@($cron)[0].installed){
  $jobs=Read-Prod '/database/query' "select count(*) as active from cron.job where active and (command ilike '%delete-account%' or command ilike '%account_deletion%');"
  $activeDeletionSchedules=@($jobs)[0].active
 }
 [pscustomobject]@{projectRef=$ref;status=$project.status;disableSignup=$auth.disable_signup;anonymousSignup=$auth.external_anonymous_users_enabled;emailConfirmationRequired=(!$auth.mailer_autoconfirm);smtpConfigured=(![string]::IsNullOrWhiteSpace($auth.smtp_host));evidence=@($data)[0].evidence;privateBuckets=@($storage);activeDeletionSchedules=$activeDeletionSchedules;functions=@($functions|Select-Object slug,status,verify_jwt)}|ConvertTo-Json -Depth 7
} finally {
 [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
 $token=$null;$headers=$null;$secret=$null;$record=$null
}
