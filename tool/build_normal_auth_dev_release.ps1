param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$expectedProjectRef = 'viqngnjfgknpxtoapzcg'
$phase8ProjectRef = 'jidyfemjzztlwjmijndx'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$configRelativePath = 'config/supabase.auth.dev.json'
$configPath = Join-Path $repoRoot 'config\supabase.auth.dev.json'

Push-Location $repoRoot
try {
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        throw "Missing local Auth config. Copy config/supabase.auth.dev.example.json to $configRelativePath and add the Planet DEV publishable key locally."
    }

    git -c core.fsmonitor=false check-ignore -q $configRelativePath
    if ($LASTEXITCODE -ne 0) {
        throw 'Auth config is not Git-ignored; refusing to build with local credentials.'
    }

    try {
        $config = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json
    }
    catch {
        throw 'Local Auth config is not valid JSON; values were not printed.'
    }

    $propertyNames = @($config.PSObject.Properties.Name | Sort-Object)
    $expectedProperties = @('SUPABASE_PUBLISHABLE_KEY', 'SUPABASE_URL')
    if (($propertyNames -join '|') -ne ($expectedProperties -join '|')) {
        throw 'Local Auth config must contain exactly SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.'
    }

    $url = [string]$config.SUPABASE_URL
    $key = [string]$config.SUPABASE_PUBLISHABLE_KEY
    $uri = $null
    if (-not [Uri]::TryCreate($url, [UriKind]::Absolute, [ref]$uri) -or
        $uri.Scheme -ne 'https' -or
        $uri.Host -ne "$expectedProjectRef.supabase.co" -or
        $uri.UserInfo -or $uri.Query -or $uri.Fragment -or
        $uri.AbsolutePath -ne '/') {
        throw "Auth URL must point exactly to Planet DEV project $expectedProjectRef; Phase 8 ref $phase8ProjectRef is forbidden."
    }

    if ([string]::IsNullOrWhiteSpace($key) -or
        $key -match 'REPLACE|service_role|sb_secret_' -or
        -not $key.StartsWith('sb_publishable_')) {
        throw 'A Supabase sb_publishable client key is required; service-role/secret keys are rejected.'
    }

    Write-Host "Building normal release for the approved Auth project ref $expectedProjectRef."
    Write-Host 'The local public key is supplied via an ignored file and will not be printed.'
    Write-Host 'Automatic upload is limited to newly saved, proven account drives; historical/Guest/archive data is not auto-enqueued.'
    Write-Host 'M2 deletion requires per-drive consent; only consented pending deletions may retry.'
    Write-Host 'Group Drive requires visible startup and consent; background continuation also requires its explicit checkbox and location FGS.'
    flutter build apk --release --config-only `
        --dart-define=DRIVEIT_LOCAL_OWNER_ACTIVATION=true `
        --dart-define=DRIVEIT_ACCOUNT_SYNC_ENABLED=true `
        --dart-define=DRIVEIT_ACCOUNT_DELETE_ENABLED=true `
        --dart-define=DRIVEIT_GROUP_DRIVE_ENABLED=true `
        --dart-define-from-file=$configRelativePath
    if ($LASTEXITCODE -ne 0) {
        throw 'Flutter release configuration failed; no APK build attempted.'
    }
    flutter build apk --release `
        --dart-define=DRIVEIT_LOCAL_OWNER_ACTIVATION=true `
        --dart-define=DRIVEIT_ACCOUNT_SYNC_ENABLED=true `
        --dart-define=DRIVEIT_ACCOUNT_DELETE_ENABLED=true `
        --dart-define=DRIVEIT_GROUP_DRIVE_ENABLED=true `
        --dart-define-from-file=$configRelativePath
    if ($LASTEXITCODE -ne 0) {
        throw 'Flutter release build failed.'
    }

    $apkPath = Join-Path $repoRoot 'build\app\outputs\flutter-apk\app-release.apk'
    if (-not (Test-Path -LiteralPath $apkPath -PathType Leaf)) {
        throw 'Flutter returned success but release APK was not created.'
    }
    Write-Host "Release APK created at $apkPath. Verify its package/signature before installation."
}
finally {
    Pop-Location
}
