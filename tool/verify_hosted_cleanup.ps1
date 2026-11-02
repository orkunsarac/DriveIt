param([Parameter(Mandatory)][string]$RunId)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($RunId -cnotmatch '^[a-f0-9-]{36}$'){throw 'Invalid run identifier'}
$folder=Join-Path $env:USERPROFILE '.driveit-secrets'
$journalSecret=Import-Clixml (Join-Path $folder ('hosted-acceptance/'+$RunId+'.clixml'))
$jp=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($journalSecret)
try{$journal=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($jp)|ConvertFrom-Json}finally{[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($jp);$journalSecret.Dispose()}
$ids=@($journal.people|Where-Object {$_.PSObject.Properties['id']}|ForEach-Object {$_.id})
if($journal.runId -cne $RunId -or $ids.Count -gt 2 -or @($ids|Where-Object {$_ -cnotmatch '^[a-f0-9-]{36}$'}).Count){throw 'Journal scope invalid'}
if(!$ids.Count){'No created account identifiers in this journal.';return}
$in=($ids|ForEach-Object {"'"+$_+"'"}) -join ','
$private=@('phase8_drive_manifests','phase8_drive_upload_intents','phase8_drive_owner_sequences','phase8_drive_changes','phase8_drive_snapshots','phase8_drive_tombstones','phase8_drive_leases','phase8_drive_cancellations')
$sum=($private|ForEach-Object {"(select count(*) from public.$_ where owner_id::text in ($in))"}) -join '+'
$pub=@();if($journal.PSObject.Properties['publishes']){$pub=@($journal.publishes)}
if(@($pub|Where-Object {$_ -cnotmatch '^[a-f0-9-]{36}$'}).Count){throw 'Publication journal scope invalid'}
$planet="'traces',0,'generationSourceLinks',0"
if($pub.Count){
 $pubIn=($pub|ForEach-Object {"'"+$_+"'"}) -join ','
 $planet="'traces',(select count(*) from public.world_active_world_traces where source_publish_id::text in ($pubIn)),'generationSourceLinks',(select count(*) from public.world_active_world_generations where source_publish_id::text in ($pubIn))"
}
$query="select json_build_object('auth',(select count(*) from auth.users where id::text in ($in)),'profiles',(select count(*) from public.profiles where id::text in ($in)),'publishes',(select count(*) from public.world_publishes where user_id::text in ($in)),'roads',(select count(*) from public.world_validated_roads where user_id::text in ($in)),'privateRows',($sum),'storage',(select count(*) from storage.objects where owner_id::text in ($in) or (bucket_id in ('world-drive-sources','phase8-drive-staging') and split_part(name,'/',1) in ($in))),'jobOwnerLinks',(select count(*) from public.account_deletion_jobs where owner_id::text in ($in)),$planet) as remaining;"
$record=Import-Clixml (Join-Path $folder 'supabase-prod-pat.clixml');$secret=if($record -is [Management.Automation.PSCredential]){$record.Password}else{$record}
$ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
try {
 $token=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
 $r=Invoke-WebRequest -Uri 'https://api.supabase.com/v1/projects/arwnbogcswisfesayosy/database/query' -Method Post -Headers @{Authorization=('Bearer '+$token)} -ContentType application/json -Body (@{query=$query;read_only=$true}|ConvertTo-Json -Compress) -SkipHttpErrorCheck
 if($r.StatusCode -notin @(200,201)){throw ('Scoped cleanup metadata HTTP '+$r.StatusCode)}
 $remaining=@($r.Content|ConvertFrom-Json)[0].remaining
 if(@($remaining.PSObject.Properties|Where-Object {$_.Value -ne 0}).Count){throw 'Synthetic rows remain; encrypted journal retained; no unscoped cleanup attempted'}
 'PASS: zero scoped Auth/profile/Planet/private/Storage/owner/trace/generation links; audit-only receipts retained.'
} finally {[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr);$token=$null;$record=$null;$secret=$null;$journal=$null}
