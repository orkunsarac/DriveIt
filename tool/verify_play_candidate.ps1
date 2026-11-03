param(
  [Parameter(Mandatory)][string]$Bundle,
  [Parameter(Mandatory)][string]$BundletoolJar,
  [Parameter(Mandatory)][ValidateRange(1,2100000000)][int]$ExpectedVersionCode,
  [Parameter(Mandatory)][string]$ExpectedVersionName,
  [Parameter(Mandatory)][ValidatePattern('^[0-9A-Fa-f]{64}$')][string]$ExpectedCertificateSha256
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$bundlePath = (Resolve-Path -LiteralPath $Bundle).Path
$bundletoolPath = (Resolve-Path -LiteralPath $BundletoolJar).Path
if (!(Test-Path -LiteralPath $bundlePath -PathType Leaf) -or !(Test-Path -LiteralPath $bundletoolPath -PathType Leaf)) { throw 'Bundle or bundletool is missing.' }

& java -jar $bundletoolPath validate "--bundle=$bundlePath" | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Bundletool validation failed.' }
$manifest = (& java -jar $bundletoolPath dump manifest "--bundle=$bundlePath" --module=base) -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'Bundle manifest read failed.' }
foreach ($check in @(
  'package="com\.osaracx\.driveit"',
  'android:targetSdkVersion="36"',
  ('android:versionCode="' + $ExpectedVersionCode + '"'),
  ('android:versionName="' + [regex]::Escape($ExpectedVersionName) + '"')
)) { if ($manifest -notmatch $check) { throw 'Bundle package, SDK, or requested version mismatch.' } }
if ($manifest -match 'android:(debuggable|testOnly)="true"') { throw 'Debuggable or test-only bundles are forbidden for Play release.' }
$config = (& java -jar $bundletoolPath dump config "--bundle=$bundlePath") -join "`n"
if ($LASTEXITCODE -ne 0 -or $config -notmatch 'PAGE_ALIGNMENT_16K') { throw 'Bundle does not declare 16 KB page alignment.' }
& jarsigner -verify $bundlePath *> $null
if ($LASTEXITCODE -ne 0) { throw 'Bundle signature verification failed.' }
$certificate = (& keytool -printcert -jarfile $bundlePath 2>$null) -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'Signing certificate fingerprint unavailable.' }
$fingerprints = [regex]::Matches($certificate, 'SHA256:\s*([0-9A-Fa-f:]{95})')
if ($fingerprints.Count -ne 1) { throw 'Expected exactly one upload certificate fingerprint.' }
$actualCertificate = $fingerprints[0].Groups[1].Value.Replace(':','')
if ($actualCertificate -ine $ExpectedCertificateSha256) { throw 'Bundle certificate differs from the expected upload certificate.' }
& (Join-Path $repoRoot 'tool/check_aab_native_alignment.ps1') -Bundle $bundlePath
$item = Get-Item -LiteralPath $bundlePath
Write-Output "PASS: package, expected version, target SDK, bundle alignment, ELF alignment and upload certificate."
Write-Output "Bytes=$($item.Length); SHA256=$((Get-FileHash -LiteralPath $bundlePath -Algorithm SHA256).Hash.ToLowerInvariant())"
Write-Output 'AAB verification does not establish build freshness, generated-APK ZIP alignment, or physical 16 KB device behavior.'
