param(
  [string]$ProjectRef,
  [string]$ExpectedProjectRef,
  [string]$SupabaseUrl,
  [switch]$SelfTest
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$prodRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
function Assert-ProdTarget([string]$Ref,[string]$Expected,[string]$Url) {
  if ($Ref -cnotmatch '^[a-z]{20}$' -or $Expected -cne $Ref) { throw 'Missing, ambiguous or mismatched approved target.' }
  if ($Ref -in @('viqngnjfgknpxtoapzcg','jidyfemjzztlwjmijndx')) { throw 'Known DEV project forbidden.' }
  if ($Url -cne ('https://' + $Ref + '.supabase.co')) { throw 'Target URL mismatch; credentials/custom endpoints forbidden.' }
}
function Test-FunctionJwtPolicy([string]$Config,[string]$Name,[string]$Expected) {
  $pattern = '(?ms)^\[functions\.' + [regex]::Escape($Name) + '\]\s*(.*?)(?=^\[|\z)'
  $sections = [regex]::Matches($Config, $pattern)
  if ($sections.Count -ne 1) { return $false }
  $values = [regex]::Matches($sections[0].Groups[1].Value, '(?m)^\s*verify_jwt\s*=\s*(true|false)\s*(?:#.*)?$')
  return $values.Count -eq 1 -and $values[0].Groups[1].Value -ceq $Expected
}
function Get-ProdInventory {
  $manifest = Get-Content -Raw (Join-Path $prodRoot 'supabase/prod/preparation_manifest.json') | ConvertFrom-Json
  $configPath = Join-Path $prodRoot 'supabase/prod/config.toml'
  if (!(Test-Path -LiteralPath $configPath)) { throw 'Production function configuration is missing.' }
  $config = [IO.File]::ReadAllText($configPath)
  if ($manifest.hashMode -cne 'utf8-lf') { throw 'Unknown source hash normalization.' }
  foreach ($entry in $manifest.files) {
    $path = [IO.Path]::GetFullPath((Join-Path $prodRoot $entry.path))
    if (!$path.StartsWith($prodRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Source inventory path escapes repository.' }
    if (!(Test-Path -LiteralPath $path)) { throw 'Source inventory file missing.' }
    $text = [IO.File]::ReadAllText($path).Replace("`r`n","`n")
    $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($text)))
    if ($hash -cne $entry.sha256) { throw 'Source inventory changed; review and regenerate manifest.' }
  }
  if ($manifest.groupDriveDefault -cne 'FALSE' -or $manifest.deploymentReady -ne $false) { throw 'Unsafe preparation manifest.' }
  if ($manifest.canonicalSchemaVerified -ne $true -or $manifest.localMigrationChainVerified -ne $true) { throw 'Canonical bootstrap not verified.' }
  $expectedFunctions = @('process-world-publish','planet-trace-detail','phase8-drive-begin','phase8-drive-cleanup','phase8-drive-delete','phase8-drive-download','phase8-drive-finalize','phase8-drive-lease','phase8-group-publish','delete-account')
  if (@($manifest.functions | Sort-Object -Unique) -join ',' -cne (@($expectedFunctions | Sort-Object -Unique) -join ',')) { throw 'Production function inventory is incomplete or contains an unreviewed function.' }
  foreach ($function in $expectedFunctions) {
    $verifyJwt = if ($function -in @('phase8-drive-cleanup','delete-account')) { 'false' } else { 'true' }
    if (!(Test-FunctionJwtPolicy $config $function $verifyJwt)) { throw "Missing or unsafe JWT policy for '$function'." }
    $entryPath = if ($function.StartsWith('phase8-')) { "supabase/phase8-dev/supabase/functions/$function/index.ts" } else { "supabase/functions/$function/index.ts" }
    if (@($manifest.files | Where-Object path -ceq $entryPath).Count -ne 1) { throw "Function entrypoint missing from source inventory: $function." }
  }
  $deleteRuntimeFiles = @(
    'supabase/functions/delete-account/index.ts',
    'supabase/functions/delete-account/planet_rebuild.ts',
    'supabase/functions/process-world-publish/active_world_overlap_stage.ts',
    'supabase/functions/process-world-publish/world_road_overlap.ts',
    'supabase/functions/process-world-publish/world_mutation.ts',
    'supabase/functions/process-world-publish/world_scoring_stage.ts',
    'supabase/functions/process-world-publish/world_scoring.ts',
    'supabase/functions/process-world-publish/world_scoring.generated.js',
    'supabase/functions/process-world-publish/source_contract.ts',
    'supabase/functions/process-world-publish/world_validation.ts',
    'supabase/functions/process-world-publish/validated_section_geojson.ts'
  )
  foreach ($path in $deleteRuntimeFiles) {
    if (@($manifest.files | Where-Object path -ceq $path).Count -ne 1) { throw "delete-account runtime dependency missing from source inventory: $path." }
  }
  $deleteSource = [IO.File]::ReadAllText((Join-Path $prodRoot 'supabase/functions/delete-account/index.ts'))
  foreach ($proof in @('auth.getUser(jwt)','signInWithPassword','account_deletion_claim','ACCOUNT_DELETION_WORKER_TOKEN')) {
    if (!$deleteSource.Contains($proof)) { throw 'delete-account server-side authorization contract is missing.' }
  }
  $migrations=@($manifest.files | Where-Object kind -eq 'migration')
  $versions=@($migrations|ForEach-Object {([IO.Path]::GetFileName($_.path) -split '_')[0]})
  if($versions.Count -ne 25 -or @($versions|Select-Object -Unique).Count -ne 25 -or ($versions -join ',') -cne (($versions|Sort-Object) -join ',') -or $versions[-1] -cne '202610310001') { throw 'Unsafe migration order/count/gate position.' }
  return $manifest
}
function Assert-ApprovedProdTarget([string]$Ref) {
  $approved=Get-Content -Raw (Join-Path $prodRoot 'supabase/prod/target.json')|ConvertFrom-Json
  if($Ref -cne 'arwnbogcswisfesayosy' -or $approved.projectRef -cne $Ref -or $approved.region -cne 'eu-central-1') { throw 'Target is not the approved PROD project.' }
}
if ($SelfTest) {
  $passed=0
  foreach ($case in @(
    @('','',''),
    @('viqngnjfgknpxtoapzcg','viqngnjfgknpxtoapzcg','https://viqngnjfgknpxtoapzcg.supabase.co'),
    @('jidyfemjzztlwjmijndx','jidyfemjzztlwjmijndx','https://jidyfemjzztlwjmijndx.supabase.co'),
    @('aaaaaaaaaaaaaaaaaaaa','bbbbbbbbbbbbbbbbbbbb','https://aaaaaaaaaaaaaaaaaaaa.supabase.co'),
    @('aaaaaaaaaaaaaaaaaaaa','aaaaaaaaaaaaaaaaaaaa','http://localhost'),
    @('aaaaaaaaaaaaaaaaaaaa','aaaaaaaaaaaaaaaaaaaa','https://aaaaaaaaaaaaaaaaaaaa.supabase.co/?token=synthetic')
  )) {
    $rejected=$false
    try { Assert-ProdTarget $case[0] $case[1] $case[2] } catch { $rejected=$true }
    if (!$rejected) { throw 'Unsafe target accepted.' }; $passed++
  }
  Assert-ProdTarget 'aaaaaaaaaaaaaaaaaaaa' 'aaaaaaaaaaaaaaaaaaaa' 'https://aaaaaaaaaaaaaaaaaaaa.supabase.co'; $passed++
  $manifest=Get-ProdInventory
  if ($manifest.blockers.Count -eq 0) { throw 'Missing bootstrap blockers.' }; $passed++
  if ($manifest.functions -notcontains 'delete-account') { throw 'Account deletion function is not inventoried.' }; $passed++
  $deleteConfig = [IO.File]::ReadAllText((Join-Path $prodRoot 'supabase/prod/config.toml'))
  if (!(Test-FunctionJwtPolicy $deleteConfig 'delete-account' 'false')) { throw 'Receipt recovery JWT policy missing.' }; $passed++
  Assert-ApprovedProdTarget 'arwnbogcswisfesayosy'; $passed++
  $rejected=$false;try{Assert-ApprovedProdTarget 'aaaaaaaaaaaaaaaaaaaa'}catch{$rejected=$true}
  if(!$rejected){throw 'Unapproved target accepted'}; $passed++
  "PASS: $passed preparation checks (synthetic targets only; no network)."
  return
}
Assert-ProdTarget $ProjectRef $ExpectedProjectRef $SupabaseUrl
Assert-ApprovedProdTarget $ProjectRef
$manifest=Get-ProdInventory
[pscustomobject]@{
  mode='dry-run'; targetSyntaxVerified=$true; remoteIdentityVerified=$false
  deploymentReady=$false; groupDriveDefault='FALSE'; blockers=$manifest.blockers
  canonicalSchemaVerified=$manifest.canonicalSchemaVerified
  localMigrationChainVerified=$manifest.localMigrationChainVerified
  migrationOrder=$manifest.files | Where-Object kind -eq 'migration' | Select-Object -ExpandProperty path
  functions=$manifest.functions
} | ConvertTo-Json -Depth 8
# This preparatory tool intentionally has no write/deployment mode. A valid
# target string does not prove project ownership, plan, emptiness or security.
exit 2
