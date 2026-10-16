[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-OneDriveRoot {
    $preferredNames = @('OneDrive', 'OneDriveCommercial', 'OneDriveConsumer')
    foreach ($name in $preferredNames) {
        $value = [Environment]::GetEnvironmentVariable($name, 'Process')
        if (-not [string]::IsNullOrWhiteSpace($value) -and
            (Test-Path -LiteralPath $value -PathType Container)) {
            return (Resolve-Path -LiteralPath $value).Path
        }
    }

    $profilePath = [Environment]::GetEnvironmentVariable('USERPROFILE', 'Process')
    if ([string]::IsNullOrWhiteSpace($profilePath) -or
        -not (Test-Path -LiteralPath $profilePath -PathType Container)) {
        throw 'OneDrive sync folder could not be detected from environment or user profile.'
    }

    $roots = @(Get-ChildItem -LiteralPath $profilePath -Directory -Force -ErrorAction Stop |
        Where-Object { $_.Name -like 'OneDrive*' })
    if ($roots.Count -ne 1) {
        throw 'OneDrive sync folder is missing or ambiguous; no files were copied.'
    }
    return $roots[0].FullName
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$preferredApk = Join-Path $repoRoot 'build\app\outputs\flutter-apk\app-release.apk'
$fallbackApk = Join-Path $repoRoot 'build\app\outputs\apk\release\app-release.apk'

if (Test-Path -LiteralPath $preferredApk -PathType Leaf) {
    $sourceApk = $preferredApk
} elseif (Test-Path -LiteralPath $fallbackApk -PathType Leaf) {
    $sourceApk = $fallbackApk
} else {
    throw 'No existing release APK was found. This script never builds an APK.'
}

$sourceItem = Get-Item -LiteralPath $sourceApk -ErrorAction Stop
if ($sourceItem.Length -le 0) {
    throw 'The selected release APK is empty.'
}

$oneDriveRoot = Resolve-OneDriveRoot
$destinationDirectory = Join-Path $oneDriveRoot 'DriveIt\APK'
New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
$destinationApk = Join-Path $destinationDirectory 'DriveIt-Latest.apk'

$sourceHash = (Get-FileHash -LiteralPath $sourceApk -Algorithm SHA256).Hash.ToUpperInvariant()
$stagingApk = Join-Path $destinationDirectory ('.DriveIt-Latest.' + [guid]::NewGuid().ToString('N') + '.staging')
$backupApk = $null

try {
    Copy-Item -LiteralPath $sourceApk -Destination $stagingApk -ErrorAction Stop
    $stagingHash = (Get-FileHash -LiteralPath $stagingApk -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($stagingHash -ne $sourceHash) {
        throw 'Staged copy hash differs from source; existing destination was not replaced.'
    }

    if (Test-Path -LiteralPath $destinationApk -PathType Leaf) {
        $existingHash = (Get-FileHash -LiteralPath $destinationApk -Algorithm SHA256).Hash.ToUpperInvariant()
        if ($existingHash -eq $sourceHash) {
            Remove-Item -LiteralPath $stagingApk -Force
        } else {
            $backupName = 'DriveIt-Latest.previous.' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.' +
                [guid]::NewGuid().ToString('N') + '.apk'
            $backupApk = Join-Path $destinationDirectory $backupName
            [System.IO.File]::Replace($stagingApk, $destinationApk, $backupApk, $true)
        }
    } else {
        [System.IO.File]::Move($stagingApk, $destinationApk)
    }

    $destinationHash = (Get-FileHash -LiteralPath $destinationApk -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($destinationHash -ne $sourceHash) {
        throw 'Final destination hash differs from source.'
    }

    $destinationItem = Get-Item -LiteralPath $destinationApk -ErrorAction Stop
    [pscustomobject]@{
        SourcePath = $sourceItem.FullName
        SourceSHA256 = $sourceHash
        DestinationPath = $destinationItem.FullName
        DestinationSHA256 = $destinationHash
        SizeBytes = $destinationItem.Length
        SourceLastWriteTime = $sourceItem.LastWriteTime
        PreviousCopyBackup = $backupApk
        LocalCopyVerified = $true
        CloudSyncVerified = $false
    } | Format-List

    Write-Output 'Local OneDrive-folder copy verified. Cloud upload/synchronization is not asserted.'
} finally {
    if (Test-Path -LiteralPath $stagingApk -PathType Leaf) {
        Remove-Item -LiteralPath $stagingApk -Force -ErrorAction SilentlyContinue
    }
}
