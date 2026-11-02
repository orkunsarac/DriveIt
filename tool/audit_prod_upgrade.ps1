# Metadata-only comparison against the isolated 50-migration reference.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Set-Location (Join-Path $PSScriptRoot '..')
$target=Get-Content tmp/r3-upgrade-target.json -Raw|ConvertFrom-Json
if($target.name -cnotmatch '^r3-upgrade-[a-f0-9]{10}$'){throw 'Wrong local reference descriptor'}
$db=@(docker ps --filter ('label=com.supabase.stack='+$target.id) --filter 'label=com.supabase.service=database' --format '{{.Names}}')
if($db.Count -ne 1){throw 'Ambiguous reference database'}
$count=docker exec $db[0] psql -U postgres -d postgres -X -At -c 'select count(*) from supabase_migrations.schema_migrations;'
if($LASTEXITCODE -ne 0 -or $count -cne '50'){throw 'Reference history mismatch'}
$source=Get-Content tool/audit_prod_policies.ps1 -Raw
$match=[regex]::Match($source,"(?s)\`$query=@'\r?\n(.*?)\r?\n'@")
if(!$match.Success){throw 'Canonical catalog query not found'}
$query=$match.Groups[1].Value
$local=("BEGIN;`n"+$query+"`nROLLBACK;")|docker exec -i $db[0] psql -U postgres -d postgres -X -At -q -v ON_ERROR_STOP=1
if($LASTEXITCODE -ne 0){throw 'Reference catalog read failed'}
$expected=($local -join "`n")|ConvertFrom-Json
if(!$expected.PSObject.Properties['tables'] -or !$expected.PSObject.Properties['functions']){throw 'Reference catalog incomplete'}
$record=Import-Clixml (Join-Path $env:USERPROFILE '.driveit-secrets/supabase-prod-pat.clixml')
$secret=if($record -is [Management.Automation.PSCredential]){$record.Password}else{$record}
$ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
try {
 $token=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
 $response=Invoke-WebRequest -Uri 'https://api.supabase.com/v1/projects/arwnbogcswisfesayosy/database/query' -Method Post -Headers @{Authorization=('Bearer '+$token)} -ContentType application/json -Body (@{query=$query;read_only=$true}|ConvertTo-Json -Compress) -SkipHttpErrorCheck
 if($response.StatusCode -notin @(200,201)){throw ('PROD catalog HTTP '+$response.StatusCode)}
 $value=@($response.Content|ConvertFrom-Json)[0].json_build_object
 $actual=if($value -is [string]){$value|ConvertFrom-Json}else{$value}
 $historyResponse=Invoke-WebRequest -Uri 'https://api.supabase.com/v1/projects/arwnbogcswisfesayosy/database/query' -Method Post -Headers @{Authorization=('Bearer '+$token)} -ContentType application/json -Body (@{query='select version,statements from supabase_migrations.schema_migrations order by version;';read_only=$true}|ConvertTo-Json -Compress) -SkipHttpErrorCheck
 if($historyResponse.StatusCode -notin @(200,201)){throw 'History metadata read failed'}
 $history=@($historyResponse.Content|ConvertFrom-Json)
 $base=@((Get-Content supabase/prod/preparation_manifest.json -Raw|ConvertFrom-Json).files|Where-Object kind -eq 'migration')
 $upgrade=@((Get-Content supabase/prod/upgrade_manifest.json -Raw|ConvertFrom-Json).files)
 $files=$base+$upgrade
 if($history.Count -ne 50){throw 'History count differs from approved package'}
 for($i=0;$i -lt 50;$i++){
  $version=([IO.Path]::GetFileName($files[$i].path)-split '_')[0]
  $sql=($history[$i].statements -join "`n").Replace("`r`n","`n")
  $hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($sql)))
  if($history[$i].version -cne $version -or $hash -cne $files[$i].sha256){throw ('Stored source hash mismatch: '+$version)}
 }
 'PASS: all 50 stored migration SQL hashes match the approved source manifests.'
} finally {[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr);$token=$null;$secret=$null;$record=$null}
$fail=0;$lines=[Collections.Generic.List[string]]::new()
$lines.Add('# R3 — 50 migration PROD katalog karşılaştırması')
$lines.Add('');$lines.Add('Yalnız katalog metadata: public tablo RLS/rol GRANT, public/storage/realtime policy komut/rol/USING/WITH CHECK, tüm public fonksiyon imzası/gövdesi/SECURITY DEFINER/search_path/EXECUTE yetkileri yerel referansla birebir karşılaştırıldı. Gerçek kullanıcı satırı sorgulanmadı.')
foreach($category in @('tables','policies','functions')){
 $lines.Add('');$lines.Add('## '+$category)
 $key=if($category -eq 'tables'){'name'}elseif($category -eq 'functions'){'signature'}else{'policyname'}
 foreach($e in $expected.$category){
  $found=@($actual.$category|Where-Object {$_.$key -ceq $e.$key -and ($category -ne 'policies' -or ($_.schemaname -ceq $e.schemaname -and $_.tablename -ceq $e.tablename))})
  $pass=$found.Count -eq 1 -and ($e|ConvertTo-Json -Depth 100 -Compress) -ceq ($found[0]|ConvertTo-Json -Depth 100 -Compress)
  if(!$pass){$fail++}
  $lines.Add('- '+$(if($pass){'PASS'}else{'FAIL'})+' '+$e.$key)
 }
 if(@($expected.$category).Count -ne @($actual.$category).Count){$fail++;$lines.Add('FAIL: object count differs')}
 'Compared '+$category+': '+@($expected.$category).Count
}
$lines.Add('');$lines.Add('Sonuç: '+$(if($fail){'FAIL'}else{'PASS'})+'; uyuşmazlık '+$fail+'.')
[IO.File]::WriteAllLines((Join-Path (Get-Location) 'docs/r3_prod_catalog_acceptance.md'),$lines,[Text.UTF8Encoding]::new($false))
if($fail){throw ('Catalog mismatches: '+$fail)}
'PASS: all expected object definitions and privileges match the local 50-migration reference.'
