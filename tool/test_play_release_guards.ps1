param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# Expected non-zero Flutter builds are assertions below; PowerShell 7 can otherwise
# promote native stderr from those deliberate failures into terminating errors.
$PSNativeCommandUseErrorActionPreference = $false
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$sdkRoot = (Get-Content -Raw (Join-Path $repoRoot 'android\local.properties') |
    Select-String -Pattern '(?m)^sdk\.dir=(.+)$').Matches.Groups[1].Value.Replace('\\', '\')
$buildTools = Get-ChildItem -LiteralPath (Join-Path $sdkRoot 'build-tools') -Directory |
    Sort-Object { [version]$_.Name } -Descending
$aapt = $buildTools | ForEach-Object { Join-Path $_.FullName 'aapt.exe' } |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (!$aapt) { throw 'Android SDK aapt.exe is required for build identity verification.' }

function Assert-PackageId([string]$Apk, [string]$Expected) {
    if (!(Test-Path -LiteralPath $Apk -PathType Leaf)) { throw "Expected APK is missing: $Apk" }
    $badging = & $aapt dump badging $Apk 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -or $badging -notmatch "package: name='$([regex]::Escape($Expected))'") {
        throw "APK package identity did not match expected '$Expected'."
    }
}

function Invoke-ExpectedBuildFailure(
    [string[]]$Arguments,
    [string]$ExpectedText,
    [string]$ExpectedAlso = ''
) {
    $priorErrorPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = & flutter @Arguments 2>&1 | Out-String
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $priorErrorPreference
    }
    if ($code -eq 0 -or $output -notmatch [regex]::Escape($ExpectedText)) {
        throw "Build guard did not reject the invalid configuration as expected: $ExpectedText"
    }
    if ($ExpectedAlso -and $output -notmatch [regex]::Escape($ExpectedAlso)) {
        throw "Build did not confirm the expected Play identity before refusing signing: $ExpectedAlso"
    }
}

$previous = @{}
$sensitiveNames = @(
    'DRIVEIT_PLAY_RELEASE',
    'DRIVEIT_PLAY_KEYSTORE',
    'DRIVEIT_PLAY_KEY_ALIAS',
    'DRIVEIT_PLAY_STORE_PASSWORD',
    'DRIVEIT_PLAY_KEY_PASSWORD'
)
foreach ($name in $sensitiveNames) {
    $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

Push-Location $repoRoot
try {
    Remove-Item Env:DRIVEIT_PLAY_RELEASE -ErrorAction SilentlyContinue
    flutter build apk --debug --no-pub
    if ($LASTEXITCODE -ne 0) { throw 'Normal debug APK build failed.' }
    $debugApk = Join-Path $repoRoot 'build\app\outputs\flutter-apk\app-debug.apk'
    Assert-PackageId $debugApk 'com.example.driveit_project'
    $permissions = & $aapt dump permissions $debugApk 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -or
        $permissions -notmatch 'android\.permission\.ACCESS_BACKGROUND_LOCATION' -or
        $permissions -notmatch 'android\.permission\.FOREGROUND_SERVICE_LOCATION') {
        throw 'Normal debug manifest is missing required location/foreground-service permissions.'
    }
    Write-Host 'PASS normal debug package and location permissions'

    flutter build apk --debug --no-pub `
        --target=integration_test/replay_hud_android_test.dart `
        --dart-define=DRIVEIT_ISOLATED_ANDROID_TEST=true
    if ($LASTEXITCODE -ne 0) { throw 'Isolated Android integration-test APK build failed.' }
    Assert-PackageId $debugApk 'com.example.driveit_project.isolated_test'
    Write-Host 'PASS isolated Android test package identity'

    Remove-Item Env:DRIVEIT_PLAY_RELEASE -ErrorAction SilentlyContinue
    Invoke-ExpectedBuildFailure @('build', 'appbundle', '--release', '--no-pub') `
        'Refusing release AAB without DRIVEIT_PLAY_RELEASE=true'
    Write-Host 'PASS unconfigured release AAB is refused'

    $env:DRIVEIT_PLAY_RELEASE = 'true'
    foreach ($name in @('DRIVEIT_PLAY_KEYSTORE', 'DRIVEIT_PLAY_KEY_ALIAS',
            'DRIVEIT_PLAY_STORE_PASSWORD', 'DRIVEIT_PLAY_KEY_PASSWORD')) {
        Remove-Item "Env:$name" -ErrorAction SilentlyContinue
    }
    Invoke-ExpectedBuildFailure @(
        'build', 'appbundle', '--release', '--no-pub',
        '--dart-define=DRIVEIT_LOCAL_OWNER_ACTIVATION=false',
        '--dart-define=DRIVEIT_ACCOUNT_SYNC_ENABLED=false',
        '--dart-define=DRIVEIT_ACCOUNT_DELETE_ENABLED=false',
        '--dart-define=DRIVEIT_GROUP_DRIVE_ENABLED=false'
    ) 'DRIVEIT_PLAY_KEYSTORE'
    Write-Host 'PASS Play release rejects missing upload signing material'

    Invoke-ExpectedBuildFailure @(
        'build', 'appbundle', '--release', '--no-pub',
        '--dart-define=SUPABASE_URL=https://viqngnjfgknpxtoapzcg.supabase.co'
    ) 'Play release refuses unverified Supabase configuration'
    Write-Host 'PASS Play release rejects DEV Supabase configuration'

    Invoke-ExpectedBuildFailure @('build', 'apk', '--debug', '--no-pub') `
        'Play release mode may only build the non-test release variant'
    Write-Host 'PASS Play mode rejects debug builds'
}
finally {
    foreach ($name in $sensitiveNames) {
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
