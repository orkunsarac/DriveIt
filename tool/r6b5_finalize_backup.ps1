param([Parameter(Mandatory)][string]$Root)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.IO.Compression.FileSystem

$base = Join-Path $env:LOCALAPPDATA 'DriveIt\Recovery'
$baseResolved = (Resolve-Path -LiteralPath $base).Path.TrimEnd('\')
$rootResolved = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')
if (!$rootResolved.StartsWith($baseResolved + '\',[StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $rootResolved) -notmatch '^R6B5-DEV-[0-9]{8}-[0-9]{6}-[a-f0-9]{8}$') { throw 'Invalid protected backup root.' }

$allowed = @([Security.Principal.WindowsIdentity]::GetCurrent().User.Value,'S-1-5-18')
foreach ($path in @($rootResolved,(Join-Path $rootResolved 'staging'))) {
  $acl = Get-Acl -LiteralPath $path
  if ($acl.Access.Count -ne 2) { throw 'Backup ACL has an unexpected principal count.' }
  foreach ($rule in $acl.Access) {
    $sid = $rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value
    if ($sid -notin $allowed -or $rule.AccessControlType -ne 'Allow') { throw 'Backup ACL includes an unexpected principal.' }
  }
}

$manifestPath = Join-Path $rootResolved 'manifest.json'
$artifactPath = Join-Path $rootResolved 'driveit-dev-r6b5.zip.dpapi'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.project_ref -cne 'viqngnjfgknpxtoapzcg' -or $manifest.artifact -cne 'driveit-dev-r6b5.zip.dpapi' -or $manifest.encryption -cne 'Windows DPAPI CurrentUser') { throw 'Backup manifest target or encryption mismatch.' }
$cipher = [IO.File]::ReadAllBytes($artifactPath)
$cipherHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($cipher)).ToLowerInvariant()
if ($cipher.Length -ne [long]$manifest.bytes -or $cipherHash -cne $manifest.sha256) { throw 'Encrypted artifact size or hash mismatch.' }
$plain = [Security.Cryptography.ProtectedData]::Unprotect($cipher,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
$stream = [IO.MemoryStream]::new($plain)
$archive = [IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Read)
try {
  $manifestEntry = @($archive.Entries | Where-Object FullName -CEQ 'payload_manifest.json')
  if ($manifestEntry.Count -ne 1) { throw 'Encrypted payload manifest missing or duplicated.' }
  $reader = [IO.StreamReader]::new($manifestEntry[0].Open())
  try { $payloadManifest = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
  if (@($payloadManifest.files).Count -ne [int]$manifest.payload_files) { throw 'Encrypted payload file count mismatch.' }
  $verified = 0
  foreach ($entry in $archive.Entries) {
    if ($entry.FullName -ceq 'payload_manifest.json') { continue }
    if ($entry.FullName.StartsWith('/') -or $entry.FullName -match '(^|/)\.\.(/|$)') { throw 'Unsafe archive path.' }
    $wanted = @($payloadManifest.files | Where-Object path -CEQ $entry.FullName)
    if ($wanted.Count -ne 1 -or $entry.Length -ne [long]$wanted[0].bytes) { throw 'Encrypted archive inventory mismatch.' }
    $entryStream = $entry.Open(); $sha = [Security.Cryptography.SHA256]::Create()
    try { $hash = [Convert]::ToHexString($sha.ComputeHash($entryStream)).ToLowerInvariant() } finally { $entryStream.Dispose(); $sha.Dispose() }
    if ($hash -cne $wanted[0].sha256) { throw 'Encrypted archive member hash mismatch.' }
    $verified++
  }
  if ($verified -ne [int]$manifest.payload_files) { throw 'Encrypted archive member count mismatch.' }
} finally { $archive.Dispose(); $stream.Dispose(); [Array]::Clear($plain,0,$plain.Length) }

$stage = Join-Path $rootResolved 'staging'
$expectedStage = [IO.Path]::GetFullPath($stage).TrimEnd('\')
$resolvedStage = (Resolve-Path -LiteralPath $stage).Path.TrimEnd('\')
if ($expectedStage -cne $resolvedStage -or ([IO.File]::GetAttributes($resolvedStage) -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Plaintext staging target failed path safety checks.' }
$rootItems = @(Get-ChildItem -LiteralPath $rootResolved -Force | Select-Object -ExpandProperty Name | Sort-Object)
if (($rootItems -join '|') -cne 'driveit-dev-r6b5.zip.dpapi|manifest.json|staging') { throw 'Unexpected sibling exists; plaintext staging cleanup refused.' }
Remove-Item -LiteralPath $resolvedStage -Recurse -Force
if (Test-Path -LiteralPath $resolvedStage) { throw 'Plaintext staging cleanup incomplete.' }
Write-Output "PASS: encrypted artifact verified ($verified members, SHA256 $cipherHash); plaintext staging removed."
