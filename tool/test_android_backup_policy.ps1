param([switch]$BuildManifest)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$manifestPath = Join-Path $root 'android/app/src/main/AndroidManifest.xml'
$legacyPath = Join-Path $root 'android/app/src/main/res/xml/account_deletion_backup_rules.xml'
$modernPath = Join-Path $root 'android/app/src/main/res/xml/account_deletion_extraction_rules.xml'
$ns = 'http://schemas.android.com/apk/res/android'

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) { throw "FAIL: $message" }
    Write-Output "PASS: $message"
}
function Load-Xml([string]$path) {
    [xml]$xml = Get-Content -LiteralPath $path -Raw
    return $xml
}
function Assert-AllExcluded([System.Xml.XmlNode]$scope, [string]$label) {
    foreach ($domain in @('root', 'file', 'database', 'sharedpref', 'external')) {
        $exclude = @($scope.SelectNodes("exclude[@domain='$domain' and @path='.']"))
        Assert-True ($exclude.Count -eq 1) "$label excludes all $domain data"
    }
}

$manifest = Load-Xml $manifestPath
$app = $manifest.SelectSingleNode('/manifest/application')
Assert-True ($null -ne $app) 'main manifest has application node'
Assert-True ($app.GetAttribute('allowBackup', $ns) -eq 'false') 'Android Auto Backup is disabled explicitly'
Assert-True ($app.GetAttribute('fullBackupContent', $ns) -eq '@xml/account_deletion_backup_rules') 'legacy backup rules remain wired'
Assert-True ($app.GetAttribute('dataExtractionRules', $ns) -eq '@xml/account_deletion_extraction_rules') 'Android 12+ extraction rules remain wired'

$legacy = Load-Xml $legacyPath
Assert-AllExcluded $legacy.DocumentElement 'Android 11 and lower / legacy transfer'
$modern = Load-Xml $modernPath
$cloud = $modern.SelectSingleNode('/data-extraction-rules/cloud-backup')
$transfer = $modern.SelectSingleNode('/data-extraction-rules/device-transfer')
Assert-True ($null -ne $cloud -and $null -ne $transfer) 'Android 12+ has separate cloud and device-transfer sections'
Assert-AllExcluded $cloud 'Android 12+ cloud backup'
Assert-AllExcluded $transfer 'Android 12+ device transfer'
Assert-True ($modern.OuterXml -notmatch '<include\b') 'no sensitive include rule overrides the exclusions'

if ($BuildManifest) {
    Push-Location $root
    try {
        & .\android\gradlew.bat -p android :app:processDebugMainManifest --no-daemon
        if ($LASTEXITCODE -ne 0) { throw "Gradle manifest merge failed with exit code $LASTEXITCODE" }
    } finally { Pop-Location }
    # Flutter's Android Gradle project writes app intermediates under the
    # repository build/ directory; standalone Gradle layouts may use
    # android/app/build/. Inspect both without assuming one layout.
    $candidateRoots = @(
        (Join-Path $root 'build/app/intermediates'),
        (Join-Path $root 'android/app/build/intermediates')
    ) | Where-Object { Test-Path -LiteralPath $_ }
    $candidates = @($candidateRoots | ForEach-Object {
        Get-ChildItem -LiteralPath $_ -Filter AndroidManifest.xml -File -Recurse -ErrorAction SilentlyContinue
    } | Where-Object { $_.FullName -match 'merged_manifest|merged_manifests' })
    $merged = $null
    foreach ($candidate in $candidates) {
        $parsed = Load-Xml $candidate.FullName
        $application = $parsed.SelectSingleNode('/manifest/application')
        if ($null -ne $application -and
            $application.GetAttribute('fullBackupContent', $ns) -eq '@xml/account_deletion_backup_rules' -and
            $application.GetAttribute('dataExtractionRules', $ns) -eq '@xml/account_deletion_extraction_rules') {
            $merged = $candidate.FullName
            break
        }
    }
    Assert-True ($null -ne $merged) 'Gradle merged manifest preserves both backup-rule references'
    Write-Output "Merged manifest: $merged"
}

Write-Output 'Android backup policy checks: PASS'
