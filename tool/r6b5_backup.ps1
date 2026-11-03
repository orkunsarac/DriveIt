$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
$env:SUPABASE_TELEMETRY_DISABLED = '1'
$ref = 'viqngnjfgknpxtoapzcg'
$base = Join-Path $env:LOCALAPPDATA 'DriveIt\Recovery'
$root = (Get-Content -LiteralPath (Join-Path $base 'r6b5-current-root.txt') -Raw).Trim()
$baseResolved = (Resolve-Path -LiteralPath $base).Path.TrimEnd('\')
$rootResolved = (Resolve-Path -LiteralPath $root).Path
if (!$rootResolved.StartsWith($baseResolved+'\',[StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $rootResolved) -notmatch '^R6B5-DEV-[0-9]{8}-[0-9]{6}-[a-f0-9]{8}$') { throw 'Invalid protected backup path.' }
$acl = Get-Acl -LiteralPath $rootResolved
$allowed = @([Security.Principal.WindowsIdentity]::GetCurrent().User.Value,'S-1-5-18')
if (!$acl.AreAccessRulesProtected -or $acl.Access.Count -ne 2) { throw 'Backup directory ACL is not protected.' }
foreach ($rule in $acl.Access) { if ($rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value -notin $allowed -or $rule.AccessControlType -ne 'Allow') { throw 'Unexpected backup principal.' } }
$cli = Join-Path (Get-Location) 'tmp/supabase-cli-npm-cache/_npx/6f1b058a4d9555af/node_modules/.bin/supabase.cmd'
$work = Join-Path (Get-Location) 'supabase/phase8-dev'
$stage = Join-Path $rootResolved 'staging'
if (Test-Path -LiteralPath $stage) {
  if (@(Get-ChildItem -LiteralPath $stage -File -Recurse).Count -ne 0) { throw 'Nonempty staging exists; do not overwrite.' }
} else { New-Item -ItemType Directory -Path $stage | Out-Null }
function Invoke-CLI([string]$label,[string[]]$arguments) {
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try { $out = @(& $cli @arguments 2>&1); $code = $LASTEXITCODE } finally { $ErrorActionPreference = $old }
  if ($code -ne 0) { throw "$label failed with exit $code; output suppressed to protect credentials and user data." }
  return ,$out
}
function Query([string]$sql) {
  $queryFile = Join-Path $stage 'read-only-query.sql'
  [IO.File]::WriteAllText($queryFile,$sql,[Text.UTF8Encoding]::new($false))
  $output = Invoke-CLI 'DEV read-only query' @('db','query','--linked','--project-ref',$ref,'--workdir',$work,'--file',$queryFile,'--output-format','json')
  $text = ($output | Where-Object {$_ -is [string]}) -join "`n"
  $start = $text.IndexOf('{'); $end = $text.LastIndexOf('}')
  if ($start -lt 0 -or $end -lt $start) { throw 'Read-only query returned invalid JSON.' }
  return ($text.Substring($start,$end-$start+1) | ConvertFrom-Json)
}
foreach ($d in @('database','inventory','functions','storage')) { New-Item -ItemType Directory -Path (Join-Path $stage $d) -Force | Out-Null }
$catalogSql = [IO.File]::ReadAllText((Join-Path (Get-Location) 'tool/r6b5_catalog.sql'))
$before = (Query $catalogSql).rows[0].catalog
if ($before.data.migrations -ne 22 -or @($before.event_triggers | Where-Object name -eq 'ensure_rls').Count -ne 1) { throw 'DEV initial migration or event-trigger preflight mismatch.' }
$before | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $stage 'inventory/catalog.json') -Encoding utf8
$bucketRows = @((Query "SELECT b.id,count(o.id)::int AS object_count,coalesce(sum((o.metadata->>'size')::bigint),0)::bigint AS object_bytes FROM storage.buckets b LEFT JOIN storage.objects o ON o.bucket_id=b.id GROUP BY b.id ORDER BY b.id").rows)
$objectRows = @((Query 'SELECT bucket_id,name,coalesce((metadata->>''size'')::bigint,0)::bigint AS bytes FROM storage.objects ORDER BY bucket_id,name').rows)
if (!$bucketRows.Count) { throw 'DEV bucket inventory unexpectedly empty.' }
$objectRows | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $stage 'inventory/storage-objects.json') -Encoding utf8
$functionWork = Join-Path $stage 'functions/work'
New-Item -ItemType Directory -Path (Join-Path $functionWork 'supabase') -Force | Out-Null
Set-Content -LiteralPath (Join-Path $functionWork 'supabase/config.toml') -Value 'project_id = "r6b5-backup"' -Encoding utf8
foreach ($spec in @(
  @{name='roles.sql';args=@('db','dump','--linked','--project-ref',$ref,'--workdir',$work,'--role-only')},
  @{name='full-schema.sql';args=@('db','dump','--linked','--project-ref',$ref,'--workdir',$work,'--schema','public,auth,storage,realtime,supabase_migrations,vault,graphql,graphql_public,pgbouncer,extensions')},
  @{name='full-data.sql';args=@('db','dump','--linked','--project-ref',$ref,'--workdir',$work,'--schema','public,auth,storage,realtime,supabase_migrations,vault,graphql,graphql_public,pgbouncer,extensions','--data-only','--use-copy')}
)) {
  $file=Join-Path $stage ('database/'+$spec.name)
  [void](Invoke-CLI $spec.name ($spec.args + @('--file',$file)))
  if (!(Test-Path -LiteralPath $file) -or (Get-Item -LiteralPath $file).Length -eq 0) { throw "Missing dump: $($spec.name)" }
}
$rawFunctions = Invoke-CLI 'function inventory' @('functions','list','--project-ref',$ref,'--output-format','json')
$jsonLine = @($rawFunctions | Where-Object {$_ -is [string] -and $_.TrimStart().StartsWith('{')})[0]
$functions = ($jsonLine | ConvertFrom-Json).functions
@{functions=@($functions | ForEach-Object {@{slug=$_.slug;version=$_.version;status=$_.status;verify_jwt=$_.verify_jwt;import_map=$_.import_map}})} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $stage 'inventory/edge-functions.json') -Encoding utf8
$rawSecrets = Invoke-CLI 'secret names inventory' @('secrets','list','--project-ref',$ref,'--output-format','json')
$secretLine = @($rawSecrets | Where-Object {$_ -is [string] -and $_.TrimStart().StartsWith('{')})[0]
$secretData = $secretLine | ConvertFrom-Json
@{secrets=@($secretData.secrets | ForEach-Object {@{name=$_.name;updated_at=$_.updated_at}})} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $stage 'inventory/edge-secret-names.json') -Encoding utf8
$rawSecrets=$null; $secretLine=$null; $secretData=$null
[void](Invoke-CLI 'Function source download' @('functions','download','--project-ref',$ref,'--workdir',$functionWork,'--use-api'))
foreach ($bucket in $bucketRows) {
  if ($bucket.id -cnotmatch '^[a-z0-9][a-z0-9._-]{0,62}$') { throw 'Unsafe bucket identifier.' }
  $destination=Join-Path $stage ('storage/'+$bucket.id)
  New-Item -ItemType Directory -Path $destination | Out-Null
  if ([int]$bucket.object_count -gt 0) {
    Push-Location $destination
    try { [void](Invoke-CLI 'Storage object download' @('--experimental','storage','cp','--recursive','--linked','--project-ref',$ref,'--workdir',$functionWork,('ss:///'+$bucket.id),'.')) } finally { Pop-Location }
  }
  $local = @(Get-ChildItem -LiteralPath $destination -File -Recurse)
  $expected = @($objectRows | Where-Object bucket_id -ceq $bucket.id)
  if ($local.Count -ne $expected.Count -or ($local | Measure-Object Length -Sum).Sum -ne [long]$bucket.object_bytes) { throw 'Storage object count or byte mismatch.' }
  $paths = @{}; foreach ($file in $local) {
    $relative=$file.FullName.Substring($destination.Length+1).Replace('\','/')
    # `supabase storage cp ss:///bucket .` preserves the bucket name as a
    # directory beneath the requested destination. Compare object keys after
    # removing that documented copy-layout prefix; retain the original layout
    # and record it in the encrypted manifest for deterministic restore.
    $bucketPrefix=$bucket.id + '/'
    if ($relative.StartsWith($bucketPrefix,[StringComparison]::Ordinal)) { $relative=$relative.Substring($bucketPrefix.Length) }
    $paths[$relative]=[long]$file.Length
  }
  foreach ($row in $expected) { if (!$paths.ContainsKey($row.name) -or $paths[$row.name] -ne [long]$row.bytes) { throw 'Storage path/size inventory mismatch.' } }
}
$after = (Query $catalogSql).rows[0].catalog
if (($before | ConvertTo-Json -Depth 100 -Compress) -cne ($after | ConvertTo-Json -Depth 100 -Compress)) { throw 'DEV changed during export; backup is not a verified coherent recovery point.' }
$payload = Join-Path $stage 'payload'; New-Item -ItemType Directory -Path $payload | Out-Null
Copy-Item -LiteralPath (Join-Path $stage 'database') -Destination $payload -Recurse
Copy-Item -LiteralPath (Join-Path $stage 'inventory') -Destination $payload -Recurse
Copy-Item -LiteralPath (Join-Path $stage 'storage') -Destination $payload -Recurse
Copy-Item -LiteralPath (Join-Path $functionWork 'supabase/functions') -Destination $payload -Recurse
$manifestFiles = @(Get-ChildItem -LiteralPath $payload -File -Recurse | Sort-Object FullName | ForEach-Object { $rel=$_.FullName.Substring($payload.Length+1).Replace('\','/'); @{path=$rel;bytes=$_.Length;modified_utc=$_.LastWriteTimeUtc.ToString('o');sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant();scope=$rel.Split('/')[0]} })
@{project_ref=$ref;created_utc=[DateTime]::UtcNow.ToString('o');files=$manifestFiles} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $payload 'payload_manifest.json') -Encoding utf8
Add-Type -AssemblyName System.Security; Add-Type -AssemblyName System.IO.Compression.FileSystem
$plain=Join-Path $stage 'payload.zip';[IO.Compression.ZipFile]::CreateFromDirectory($payload,$plain,[IO.Compression.CompressionLevel]::Optimal,$false)
$zip=[IO.File]::ReadAllBytes($plain);$encrypted=[Security.Cryptography.ProtectedData]::Protect($zip,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
$artifact=Join-Path $rootResolved 'driveit-dev-r6b5.zip.dpapi';[IO.File]::WriteAllBytes($artifact,$encrypted)
$decoded=[Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($artifact),$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
if ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($zip)) -cne [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($decoded))) { throw 'Encrypted round trip mismatch.' }
$ms=[IO.MemoryStream]::new($decoded);$archive=[IO.Compression.ZipArchive]::new($ms,[IO.Compression.ZipArchiveMode]::Read)
try {
 $verified=0
 foreach($entry in $archive.Entries) { if($entry.FullName -eq 'payload_manifest.json'){continue};$wanted=@($manifestFiles|Where-Object path -ceq $entry.FullName);if($wanted.Count -ne 1 -or $entry.Length -ne $wanted[0].bytes){throw 'Archive member inventory mismatch'};$stream=$entry.Open();$hash=[Security.Cryptography.SHA256]::Create();try{$digest=[Convert]::ToHexString($hash.ComputeHash($stream)).ToLowerInvariant()}finally{$stream.Dispose();$hash.Dispose()};if($digest -cne $wanted[0].sha256){throw 'Archive member hash mismatch'};$verified++ }
 if($verified -ne $manifestFiles.Count){throw 'Archive member count mismatch'}
} finally {$archive.Dispose();$ms.Dispose()}
@{project_ref=$ref;artifact='driveit-dev-r6b5.zip.dpapi';created_utc=[DateTime]::UtcNow.ToString('o');sha256=(Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash.ToLowerInvariant();bytes=(Get-Item -LiteralPath $artifact).Length;encryption='Windows DPAPI CurrentUser';payload_files=$verified;event_trigger_count=@($before.event_triggers).Count;storage_objects=$before.data.storage_objects;auth_users=$before.data.auth_users;migrations=$before.data.migrations;pre_post_catalog_equal=$true;limitations=@('Function secret values, Auth/SMTP/provider settings and extension binaries are not included.','Capture times are checked against matching catalog and data fingerprints; the export is not a single server-wide transaction.','Event-trigger definitions and extension schema ACL require explicit restoration and verification.')} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $rootResolved 'manifest.json') -Encoding utf8
& (Join-Path (Get-Location) 'tool/r6b5_finalize_backup.ps1') -Root $rootResolved
"PASS: encrypted DEV artifact created; $verified files verified; plaintext staging removed; migrations=$($before.data.migrations); event triggers=$(@($before.event_triggers).Count); storage objects=$($before.data.storage_objects)."
