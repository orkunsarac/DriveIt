param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('owned_drive_ui_android_test.dart', 'device_archive_lifecycle_android_test.dart', 'device_archive_success_android_test.dart', 'device_archive_home_revoke_android_test.dart', 'device_archive_lock_revoke_android_test.dart')]
    [string] $TestFile,

    [Parameter(Mandatory = $true)]
    [string] $DeviceSerial,

    [switch] $BootstrapOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$expectedSerial = 'R5CX42V8GSJ'
$baseId = 'com.example.driveit_project'
$isolatedId = "$baseId.isolated_test"
$expectedCert = '0b946cfdee1f4c10c2395475b952b4822944e64494d5ffbdeba4ed71f3422e21'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$testTarget = "integration_test/$TestFile"
if ($DeviceSerial -cne $expectedSerial) { throw 'Unexpected Android serial; refusing test install.' }

$adb = 'C:\Users\PC\AppData\Local\Android\Sdk\platform-tools\adb.exe'
$sdk = 'C:\Users\PC\AppData\Local\Android\Sdk'
$javaHome = 'C:\Program Files\Android\Android Studio\jbr'
$analyzer = Join-Path $sdk 'cmdline-tools\latest\bin\apkanalyzer.bat'
$signer = Join-Path $sdk 'build-tools\37.0.0\apksigner.bat'
$gradle = Join-Path $repoRoot 'android\gradlew.bat'
foreach ($required in @($adb, $analyzer, $signer, $gradle, "$javaHome\bin\java.exe")) {
    if (!(Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required Android tool is missing: $required" }
}
$env:JAVA_HOME = $javaHome
$env:PATH = "$javaHome\bin;$env:PATH"

$deviceRows = @(& $adb devices -l)
if ($LASTEXITCODE -ne 0 -or !($deviceRows | Where-Object { $_ -match "^$([regex]::Escape($expectedSerial))\s+device\b" })) {
    throw 'Expected A55 is not in device state; refusing build/install.'
}
$realPackagePath = @(& $adb -s $expectedSerial shell pm path $baseId)
if ($LASTEXITCODE -ne 0 -or $realPackagePath.Count -eq 0 -or ($realPackagePath -join '') -notmatch 'package:/') {
    throw 'Real DriveIt package is not installed as expected; refusing to proceed.'
}

$dartDefines = @('DRIVEIT_ISOLATED_ANDROID_TEST=true', 'DRIVEIT_RELEASE_ACCEPTANCE=true')
if ($BootstrapOnly) {
    if ($TestFile -cne 'owned_drive_ui_android_test.dart') {
        throw 'BootstrapOnly is supported only for the owned-drive release acceptance target.'
    }
    $dartDefines += 'DRIVEIT_RELEASE_BOOTSTRAP_ONLY=true'
}
$encodedDefines = ($dartDefines | ForEach-Object {
    [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($_))
}) -join ','

Push-Location $repoRoot
try {
    Write-Host "Building release AOT integration target $testTarget for isolated package only."
    & flutter build apk --release --no-pub --target $testTarget `
        --dart-define=DRIVEIT_ISOLATED_ANDROID_TEST=true `
        --dart-define=DRIVEIT_RELEASE_ACCEPTANCE=true
    if ($LASTEXITCODE -ne 0) { throw 'Flutter release APK build failed.' }

    Push-Location (Join-Path $repoRoot 'android')
    try {
        & .\gradlew.bat :app:assembleReleaseAndroidTest `
            "-Ptarget=$testTarget" `
            "-Pdart-defines=$encodedDefines"
        if ($LASTEXITCODE -ne 0) { throw 'Android release instrumentation APK build failed.' }
    } finally { Pop-Location }

    $appApk = Join-Path $repoRoot 'build\app\outputs\flutter-apk\app-release.apk'
    if (!(Test-Path -LiteralPath $appApk -PathType Leaf)) { throw 'Release target APK was not produced.' }
    $actualId = (& $analyzer manifest application-id $appApk).Trim()
    if ($LASTEXITCODE -ne 0 -or $actualId -cne $isolatedId) { throw "Refusing install: APK id '$actualId' is not isolated." }
    $debuggable = (& $analyzer manifest debuggable $appApk).Trim()
    if ($LASTEXITCODE -ne 0 -or $debuggable -cne 'false') { throw 'Refusing install: release APK is debuggable or unreadable.' }
    $manifest = (& $analyzer manifest print $appApk) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $manifest -notmatch '(?s)<meta-data[^>]*android:name="driveit\.isolated_owner_runtime"[^>]*android:value="true"') {
        throw 'Refusing install: isolated native manifest marker is absent.'
    }
    $appCert = ((& $signer verify --print-certs $appApk | Select-String 'certificate SHA-256 digest:').ToString() -split ': ')[-1].Trim().ToLowerInvariant()
    if ($LASTEXITCODE -ne 0 -or $appCert -cne $expectedCert) { throw 'Refusing install: APK signing certificate mismatch.' }
    $appDexPackages = (& $analyzer dex packages $appApk) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'Could not inspect release app dex contents; refusing install.' }

    $testCandidates = @(
        (Join-Path $repoRoot 'build\app\outputs\apk\androidTest\release\app-release-androidTest.apk'),
        (Join-Path (Split-Path $repoRoot -Parent) 'build\app\outputs\apk\androidTest\release\app-release-androidTest.apk')
    )
    $testApk = $testCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if (!$testApk) { throw 'Release instrumentation APK was not found at the expected Gradle output locations.' }
    $testId = (& $analyzer manifest application-id $testApk).Trim()
    if ($LASTEXITCODE -ne 0 -or $testId -cne "$isolatedId.test") { throw "Refusing install: instrumentation package '$testId' is not isolated." }
    $testManifest = (& $analyzer manifest print $testApk) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $testManifest -notmatch [regex]::Escape("android:targetPackage=`"$isolatedId`"")) {
        throw 'Refusing install: instrumentation target is not the isolated app.'
    }
    $testDexPackages = (& $analyzer dex packages $testApk) -join "`n"
    if ($LASTEXITCODE -ne 0 -or
        (($testDexPackages + "`n" + $appDexPackages) -notmatch 'androidx\.test\.runner\.AndroidJUnitRunner') -or
        (($testDexPackages + "`n" + $appDexPackages) -notmatch 'dev\.flutter\.plugins\.integration_test\.FlutterTestRunner') -or
        $testDexPackages -notmatch 'com\.example\.driveit_project\.Phase5ReleaseAcceptanceTest') {
        throw 'Refusing install: release APK pair is missing its instrumentation runner or acceptance test class.'
    }

    $currentPath = ((& $adb -s $expectedSerial shell pm path $isolatedId | Select-Object -First 1) -replace '^package:', '').Trim()
    if ($LASTEXITCODE -eq 0 -and $currentPath) {
        $localInstalled = Join-Path ([IO.Path]::GetTempPath()) ("driveit-isolated-before-release-{0}.apk" -f [guid]::NewGuid().ToString('N'))
        & $adb -s $expectedSerial pull $currentPath $localInstalled | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Could not read existing isolated APK for signing comparison; refusing update.' }
        $oldCert = ((& $signer verify --print-certs $localInstalled | Select-String 'certificate SHA-256 digest:').ToString() -split ': ')[-1].Trim().ToLowerInvariant()
        if ($LASTEXITCODE -ne 0 -or $oldCert -cne $appCert) { throw 'Installed isolated APK signing certificate differs; refusing update.' }
    }
    $testCert = ((& $signer verify --print-certs $testApk | Select-String 'certificate SHA-256 digest:').ToString() -split ': ')[-1].Trim().ToLowerInvariant()
    if ($LASTEXITCODE -ne 0 -or $testCert -cne $expectedCert) { throw 'Refusing install: instrumentation signing certificate mismatch.' }

    $apkHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $appApk).Hash
    Write-Host "Verified isolated release APK: $actualId; debuggable=$debuggable; SHA-256=$apkHash"
    Write-Host "Verified isolated instrumentation APK: $testId -> $isolatedId"

    & $adb -s $expectedSerial install -r $appApk
    if ($LASTEXITCODE -ne 0) { throw 'Isolated release APK install failed; stopping without fallback.' }
    & $adb -s $expectedSerial install -r $testApk
    if ($LASTEXITCODE -ne 0) { throw 'Isolated instrumentation APK install failed; stopping without fallback.' }
    $instrumentationOutput = @(& $adb -s $expectedSerial shell am instrument -w -r "$testId/androidx.test.runner.AndroidJUnitRunner")
    $instrumentationExitCode = $LASTEXITCODE
    $instrumentationText = $instrumentationOutput -join "`n"
    $instrumentationOutput | ForEach-Object { Write-Host $_ }
    if ($instrumentationExitCode -ne 0 -or
        $instrumentationText -match 'Process crashed|shortMsg=|FAILURES!!!|INSTRUMENTATION_CODE: 0' -or
        $instrumentationText -notmatch 'OK \(\d+ test') {
        throw 'Release instrumentation acceptance did not report an explicit passing test result.'
    }
} finally { Pop-Location }
