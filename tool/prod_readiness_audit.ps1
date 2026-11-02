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
  if($r.StatusCode -notin @(200,201)){throw ('PROD read failed: '+$Path+' HTTP '+$r.StatusCode)}
  return $r.Content|ConvertFrom-Json
 }
 $project=Read-Prod '';if($project.id -cne $ref){throw 'Project identity mismatch'}
 $auth=Read-Prod '/config/auth'
 $data=Read-Prod '/database/query' "select json_build_object('authUsers',(select count(*) from auth.users),'migrationCount',(select count(*) from supabase_migrations.schema_migrations),'gate',public.phase8_group_enabled(),'publicTables',(select count(*) from pg_class where relnamespace='public'::regnamespace and relkind='r'),'deletionInstalled',to_regclass('public.account_deletion_jobs') is not null) as evidence;"
 $functions=Read-Prod '/functions'
 [pscustomobject]@{projectRef=$ref;status=$project.status;disableSignup=$auth.disable_signup;evidence=@($data)[0].evidence;functions=@($functions|Select-Object slug,status,verify_jwt)}|ConvertTo-Json -Depth 7
} finally {
 [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
 $token=$null;$headers=$null;$secret=$null;$record=$null
}
