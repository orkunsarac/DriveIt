param(
    [Parameter(Mandatory = $true)]
    [string] $ApkPath
)

$ErrorActionPreference = 'Stop'
$apk = (Resolve-Path -LiteralPath $ApkPath).Path
if ([IO.Path]::GetExtension($apk) -ne '.apk') {
    throw 'Expected an APK file.'
}

$sdk = if ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { $env:ANDROID_HOME }
if (!$sdk) {
    $sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
}
$analyzer = Join-Path $sdk 'cmdline-tools\latest\bin\apkanalyzer.bat'
if (!(Test-Path -LiteralPath $analyzer)) {
    throw "apkanalyzer not found under Android SDK: $sdk"
}

$applicationId = (& $analyzer manifest application-id $apk).Trim()
if ($LASTEXITCODE -ne 0) {
    throw 'Could not inspect APK applicationId; refusing any install.'
}
if ($applicationId -cne 'com.example.driveit_project.isolated_test') {
    throw "Refusing APK applicationId '$applicationId'; only com.example.driveit_project.isolated_test is allowed."
}
Write-Host "Verified isolated APK applicationId: $applicationId"
