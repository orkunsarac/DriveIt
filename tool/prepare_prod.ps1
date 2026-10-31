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
function Get-ProdInventory {
  $manifest = Get-Content -Raw (Join-Path $prodRoot 'supabase/prod/preparation_manifest.json') | ConvertFrom-Json
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
  return $manifest
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
  "PASS: $passed preparation checks (synthetic targets only; no network)."
  return
}
Assert-ProdTarget $ProjectRef $ExpectedProjectRef $SupabaseUrl
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
