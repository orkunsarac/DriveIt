param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$processVariables = @(
    'DRIVEIT_PLAY_RELEASE', 'DRIVEIT_PLAY_KEYSTORE', 'DRIVEIT_PLAY_KEY_ALIAS',
    'DRIVEIT_PLAY_STORE_PASSWORD', 'DRIVEIT_PLAY_KEY_PASSWORD', 'DRIVEIT_BUNDLETOOL_JAR'
)
$previous = @{}
foreach ($name in $processVariables) {
    $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

function ConvertFrom-SecurePrompt([string]$Prompt) {
    $secure = Read-Host -Prompt $Prompt -AsSecureString
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
}

Push-Location $repoRoot
try {
    if ([string]::IsNullOrWhiteSpace($env:DRIVEIT_PLAY_KEYSTORE)) {
        $env:DRIVEIT_PLAY_KEYSTORE = 'C:\Users\PC\DriveIt-Signing\driveit-upload.jks'
    }
    if ([string]::IsNullOrWhiteSpace($env:DRIVEIT_PLAY_KEY_ALIAS)) {
        $env:DRIVEIT_PLAY_KEY_ALIAS = 'driveit-upload'
    }
    if ([string]::IsNullOrWhiteSpace($env:DRIVEIT_BUNDLETOOL_JAR)) {
        $env:DRIVEIT_BUNDLETOOL_JAR = Read-Host 'Path to the trusted bundletool JAR'
    }
    $keyStorePath = [IO.Path]::GetFullPath($env:DRIVEIT_PLAY_KEYSTORE)
    $bundletoolPath = [IO.Path]::GetFullPath($env:DRIVEIT_BUNDLETOOL_JAR)
    $repoPrefix = $repoRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if ($keyStorePath.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'The Play upload keystore must be stored outside the repository.'
    }
    if (!(Test-Path -LiteralPath $keyStorePath -PathType Leaf)) {
        throw 'The configured Play upload keystore does not exist; no build was attempted.'
    }
    if (!(Test-Path -LiteralPath $bundletoolPath -PathType Leaf)) {
        throw 'The configured bundletool JAR does not exist; no build was attempted.'
    }
    foreach ($name in @('DRIVEIT_PLAY_STORE_PASSWORD', 'DRIVEIT_PLAY_KEY_PASSWORD')) {
        if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name, 'Process'))) {
            $prompt = if ($name -eq 'DRIVEIT_PLAY_STORE_PASSWORD') { 'Keystore password' } else { 'Upload key password' }
            [Environment]::SetEnvironmentVariable($name, (ConvertFrom-SecurePrompt $prompt), 'Process')
        }
    }

    $env:DRIVEIT_PLAY_RELEASE = 'true'
    Write-Host 'Building the Play AAB with the fixed store applicationId and external upload key.'
    Write-Host 'Cloud Auth, owner activation, automatic sync, deletion, and Group Drive remain disabled.'
    flutter build appbundle --release --no-pub `
        --dart-define=DRIVEIT_LOCAL_OWNER_ACTIVATION=false `
        --dart-define=DRIVEIT_ACCOUNT_SYNC_ENABLED=false `
        --dart-define=DRIVEIT_ACCOUNT_DELETE_ENABLED=false `
        --dart-define=DRIVEIT_GROUP_DRIVE_ENABLED=false
    if ($LASTEXITCODE -ne 0) {
        throw 'Play AAB build failed; inspect the non-secret Gradle error above.'
    }

    $bundlePath = Join-Path $repoRoot 'build\app\outputs\bundle\release\app-release.aab'
    if (!(Test-Path -LiteralPath $bundlePath -PathType Leaf)) {
        throw 'Flutter reported success but the expected Play AAB is missing.'
    }

    $java = Get-Command java -ErrorAction Stop
    $jarsigner = Get-Command jarsigner -ErrorAction Stop
    $keytool = Get-Command keytool -ErrorAction Stop
    & $java.Source -jar $bundletoolPath validate "--bundle=$bundlePath" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'bundletool rejected the AAB.' }

    $manifestText = & $java.Source -jar $bundletoolPath dump manifest `
        "--bundle=$bundlePath" --module=base
    if ($LASTEXITCODE -ne 0) { throw 'Could not read the AAB base manifest.' }
    if (($manifestText -join "`n") -notmatch 'package="com\.osaracx\.driveit"') {
        throw 'The AAB applicationId does not match the approved Play package.'
    }
    if (($manifestText -join "`n") -notmatch 'android:targetSdkVersion="36"') {
        throw 'The AAB target SDK is not API 36.'
    }
    if (($manifestText -join "`n") -notmatch 'android:versionCode="[1-9][0-9]*"') {
        throw 'The AAB does not contain a positive versionCode.'
    }
    if (($manifestText -join "`n") -notmatch 'android:versionName="[^"]+"') {
        throw 'The AAB does not contain a versionName.'
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($bundlePath)
    try {
        if (!$zip.Entries.FullName.Contains('base/lib/arm64-v8a/libapp.so')) {
            throw 'The AAB is missing the required 64-bit ARM Flutter native library.'
        }
    }
    finally {
        $zip.Dispose()
    }

    # Upload certificates are self-signed by design; avoid -strict, which
    # treats the expected non-CA certificate chain as an error.
    & $jarsigner.Source -verify -certs $bundlePath *> $null
    if ($LASTEXITCODE -ne 0) { throw 'The AAB is not signed by a valid upload certificate.' }
    $certificate = & $keytool.Source -printcert -jarfile $bundlePath 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Could not inspect the AAB signing certificate.' }
    $fingerprint = ($certificate | Select-String 'SHA256:' | Select-Object -First 1).Line
    if ([string]::IsNullOrWhiteSpace($fingerprint)) {
        throw 'The AAB signing certificate has no readable SHA-256 fingerprint.'
    }

    Write-Host 'Verified Play AAB package, target SDK, version metadata, 64-bit ARM library, and upload signature.'
    Write-Host $fingerprint
    Write-Host "AAB: $bundlePath"
}
finally {
    foreach ($name in $processVariables) {
        $value = $previous[$name]
        if ($null -eq $value) {
            Remove-Item "Env:$name" -ErrorAction SilentlyContinue
        }
        else {
            [Environment]::SetEnvironmentVariable($name, $value, 'Process')
        }
    }
    Pop-Location
}
