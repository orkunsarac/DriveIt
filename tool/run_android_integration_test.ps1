param(
    [Parameter(Mandatory = $true)]
    [string] $TestFile,

    [Parameter(Mandatory = $true)]
    [string] $DeviceSerial,

    [string[]] $DartDefine = @(),

    [ValidateRange(60, 900)]
    [int] $TimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$integrationRoot = (Resolve-Path (Join-Path $repoRoot 'integration_test')).Path
$candidate = if ([IO.Path]::IsPathRooted($TestFile)) {
    [IO.Path]::GetFullPath($TestFile)
} else {
    [IO.Path]::GetFullPath((Join-Path $repoRoot $TestFile))
}
$prefix = $integrationRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (!$candidate.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or
    [IO.Path]::GetExtension($candidate) -ne '.dart' -or
    !(Test-Path -LiteralPath $candidate -PathType Leaf)) {
    throw 'TestFile must be an existing .dart file inside integration_test/.'
}
if ([string]::IsNullOrWhiteSpace($DeviceSerial)) {
    throw 'An explicit Android device serial is required.'
}

$relativeTest = [IO.Path]::GetRelativePath($repoRoot, $candidate).Replace('\', '/')
Write-Host "Running isolated Android integration test: $relativeTest on $DeviceSerial"
Write-Host 'Gradle enforces the .isolated_test applicationId before Flutter can install the APK.'

$defines = @('--dart-define=DRIVEIT_ISOLATED_ANDROID_TEST=true')
foreach ($value in $DartDefine) {
    if ([string]::IsNullOrWhiteSpace($value) -or $value.Contains("`n") -or $value.Contains("`r")) {
        throw 'Dart defines must be non-empty single-line values.'
    }
    if ($value -match '^DRIVEIT_ISOLATED_ANDROID_TEST=') {
        throw 'The isolated integration-test kill switch is managed by this runner.'
    }
    $defines += "--dart-define=$value"
}

& flutter test $relativeTest `
    -d $DeviceSerial `
    --no-pub `
    --no-uninstall `
    "--timeout=${TimeoutSeconds}s" `
    --reporter=expanded `
    @defines
exit $LASTEXITCODE
