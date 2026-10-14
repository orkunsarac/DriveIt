[CmdletBinding()]
param(
    # Default mode performs only read-only target/preflight checks. -Apply
    # enables the later, separately-confirmed deployment steps.
    [switch]$Apply,
    # Pure local checks of fail-closed validators. Never calls the network/CLI.
    [switch]$SelfTest,
    # Explicitly authorized process PAT; never falls back to a stored login.
    [switch]$UseProcessAccessToken,
    [string]$BackupDirectory,
    # Only usable with the explicitly approved process PAT and verified backup.
    [switch]$NonInteractive,
    # Explicit recovery from the verified two-migration/private-bucket stage.
    # Never reruns a migration or overwrites an existing Edge Function.
    [switch]$ResumeAfterMigration
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ExpectedProjectRef = 'viqngnjfgknpxtoapzcg'
$ExpectedProjectName = 'DriveIT DEV'
$ExpectedMigration = '202610120001_phase8_drive_sync.sql'
$ExpectedMigrationSha256 = 'BF7AEAB76A39D075876C0C4CE02546782EBEB2F8374C0D521CD36977F8BFFD11'
$ExpectedMigrationHashes = [ordered]@{
    '202610120001_phase8_drive_sync.sql' = $ExpectedMigrationSha256
    '202610150001_phase8_m1_forward_repair.sql' = 'B1BAF05304E01ABA3D0E04654ED266B5130D2A8C14BB712C59237B591BD61F1C'
}
$ExpectedConfigSha256 = 'FE8814615A60AC7E9E4995A93D7ABE575069D08BE35E17234F94711CA578AA81'
$ExpectedCleanupSecurityTestSha256 = '848F6A4A8B56BDC0459A29CC554ED33920F31D1049292BEED5EB1751FCD8FE17'
$ExpectedBucket = 'phase8-drive-staging'
$CleanupSecretName = 'PHASE8_CLEANUP_TOKEN'
$ExpectedFunctions = @(
    @{ Slug = 'phase8-drive-begin';    VerifyJwt = $true  }
    @{ Slug = 'phase8-drive-finalize'; VerifyJwt = $true  }
    @{ Slug = 'phase8-drive-download'; VerifyJwt = $true  }
    @{ Slug = 'phase8-drive-cleanup';  VerifyJwt = $false }
)

# Pin this script to the exact local backend bundle it was reviewed with.
$ExpectedFunctionFileHashes = @{
    'functions/phase8-drive-begin/index.ts' = 'E3D5DEDA402EB1BA92135A24D26D1EDD4266BB630E17F6A924150C74187FF23F'
    'functions/phase8-drive-cleanup/index.ts' = '84E141B931A26A1B919E9562C6C4C5B906E1969AA07F84151A6074AC1EF5274F'
    'functions/phase8-drive-download/index.ts' = '8B35BEB039112378EE809A9D34C7A3C6D17A7F9CB1F399199DCC0BDB180C8343'
    'functions/phase8-drive-finalize/index.ts' = 'DA1D50E5C23140D4E8774B7534D9AACBFED9275A2DEE0E7609BA6F407FEBA5A8'
    'functions/_shared/canonical_test.ts' = '16BA7E51D25C0BD438B03230595D8A9A55087634816E30BCC414E19FE0CB0B92'
    'functions/_shared/common.ts' = 'C4A65AA1EF186B3A463D759D19B880A47E5FE49E4DAD75F185B73EE0CF1225AF'
}
$ExpectedFunctionFiles = @($ExpectedFunctionFileHashes.Keys | Sort-Object)

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$phase8Root = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'supabase/phase8-dev/supabase'))
$configPath = Join-Path $phase8Root 'config.toml'
$migrationDirectory = Join-Path $phase8Root 'migrations'
$migrationPath = Join-Path $migrationDirectory $ExpectedMigration
$functionsDirectory = Join-Path $phase8Root 'functions'
$apiBase = 'https://api.supabase.com/v1'

$oldAccessToken = [Environment]::GetEnvironmentVariable('SUPABASE_ACCESS_TOKEN', 'Process')
$oldDbPassword = [Environment]::GetEnvironmentVariable('SUPABASE_DB_PASSWORD', 'Process')
$oldSupabaseWorkdir = [Environment]::GetEnvironmentVariable('SUPABASE_WORKDIR', 'Process')
$accessToken = $null
$dbPassword = $null
$cleanupToken = $null
$accessTokenSecure = $null
$dbPasswordSecure = $null
$cleanupTokenSecure = $null
$accessBstr = [IntPtr]::Zero
$dbBstr = [IntPtr]::Zero
$cleanupBstr = [IntPtr]::Zero
$supabaseCliSpec = $null
$locationPushed = $false
$deploymentRoot = Join-Path $repoRoot 'tmp/diagnostic_acceptance/planet-m1-cli'
$baselineMigrationDirectory = Join-Path $repoRoot 'supabase/migrations'
$baselineMigrationNames = @(
    '202609230001_world_publish_validation_atomic.sql',
    '202609300001_world_publishes_service_role_select.sql',
    '202609300002_world_validated_roads_service_role_select.sql',
    '202609300003_active_world_empty_generation.sql',
    '202609300004_world_validated_road_sections_service_role_select.sql',
    '202609300005_world_validated_sections_geojson_read.sql',
    '202610010001_world_validated_sections_exact_distance_read.sql',
    '202610060001_active_world_overlap_candidates.sql',
    '202610060002_active_world_mutation.sql',
    '202610060003_planet_map_read.sql',
    '202610060004_planet_clip_set_based.sql',
    '202610070001_planet_trace_detail_read.sql',
    '202610070002_planet_trace_detail_lookup_index.sql'
)

function ConvertFrom-SecurePrompt {
    param(
        [Parameter(Mandatory = $true)][Security.SecureString]$SecureValue,
        [Parameter(Mandatory = $true)][ref]$Bstr
    )
    $Bstr.Value = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($Bstr.Value)
}

function Assert-ApprovedLocalBundle {
    Assert-ReviewedFileHash -Path $script:configPath -ExpectedHash $script:ExpectedConfigSha256 -Label 'config.toml'
    $files = @(Get-ChildItem -LiteralPath $script:migrationDirectory -Filter '*.sql' -File | Select-Object -ExpandProperty Name | Sort-Object)
    if (Compare-Object -ReferenceObject @($script:ExpectedMigrationHashes.Keys) -DifferenceObject $files) {
        throw 'Safety stop: exactly the two approved M1 migration files are required.'
    }
    foreach ($name in $script:ExpectedMigrationHashes.Keys) {
        Assert-ReviewedFileHash -Path (Join-Path $script:migrationDirectory $name) -ExpectedHash $script:ExpectedMigrationHashes[$name] -Label $name
    }
    Assert-ReviewedFileHash -Path (Join-Path $script:phase8Root 'tests/phase8_edge_integration_test.ts') `
        -ExpectedHash $script:ExpectedCleanupSecurityTestSha256 -Label 'phase8_edge_integration_test.ts'
    $actualFiles = @(Get-ChildItem -LiteralPath $script:functionsDirectory -Recurse -File | ForEach-Object {
        $_.FullName.Substring($script:phase8Root.Length + 1).Replace('\', '/')
    } | Sort-Object)
    if (Compare-Object -ReferenceObject $script:ExpectedFunctionFiles -DifferenceObject $actualFiles) {
        throw 'Safety stop: Edge Function bundle file set changed; undeclared local dependency/config files are not allowed.'
    }
    foreach ($file in $script:ExpectedFunctionFiles) {
        Assert-ReviewedFileHash -Path (Join-Path $script:phase8Root $file) `
            -ExpectedHash $script:ExpectedFunctionFileHashes[$file] -Label $file
    }
}

function Invoke-Phase8ManagementApi {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('GET', 'POST')][string]$Method,
        [Parameter(Mandatory = $true)][string]$Path,
        [object]$Body,
        [switch]$RawJson
    )

    if (-not $Path.StartsWith("/projects/$script:ExpectedProjectRef/", [StringComparison]::Ordinal) -and
        $Path -cne "/projects/$script:ExpectedProjectRef") {
        throw 'Safety stop: Management API path is outside the approved Planet project.'
    }
    $headers = @{ Authorization = "Bearer $script:accessToken" }
    $uri = "$script:apiBase$Path"
    try {
        if ($RawJson) {
            if ($null -eq $Body) {
                $response = Invoke-WebRequest -UseBasicParsing -Method $Method -Uri $uri -Headers $headers -TimeoutSec 45
            }
            else {
                $jsonBody = ConvertTo-Json -InputObject $Body -Depth 12 -Compress
                $response = Invoke-WebRequest -UseBasicParsing -Method $Method -Uri $uri -Headers $headers `
                    -ContentType 'application/json' -Body $jsonBody -TimeoutSec 45
            }
            return [string]$response.Content
        }
        if ($null -eq $Body) {
            return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -TimeoutSec 45
        }
        $json = ConvertTo-Json -InputObject $Body -Depth 12 -Compress
        return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers `
            -ContentType 'application/json' -Body $json -TimeoutSec 45
    }
    catch {
        $status = 'unknown'
        try { $status = [string][int]$_.Exception.Response.StatusCode } catch { }
        # Never print the response body: secret-management responses can carry values.
        throw "Management API $Method failed for the fixed Phase 8 endpoint (HTTP $status); response body suppressed."
    }
}

function Assert-Phase8CliDirectory {
    param([string]$CurrentDirectory = (Get-Location).Path)
    $current = [System.IO.Path]::GetFullPath($CurrentDirectory).TrimEnd('\')
    $expected = [System.IO.Path]::GetFullPath($script:phase8Root).TrimEnd('\')
    if (-not [string]::Equals($current, $expected, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Safety stop: Supabase CLI current directory is not supabase/phase8-dev/supabase.'
    }
    $workdir = [Environment]::GetEnvironmentVariable('SUPABASE_WORKDIR', 'Process')
    if ([string]::IsNullOrWhiteSpace($workdir) -or
        -not [string]::Equals([System.IO.Path]::GetFullPath($workdir).TrimEnd('\'), $expected, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Safety stop: SUPABASE_WORKDIR does not point to the isolated Phase 8 CLI directory.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $current 'config.toml') -PathType Leaf)) {
        throw 'Safety stop: isolated Phase 8 config.toml is missing.'
    }
    Assert-ApprovedLocalBundle
}

function Assert-LinkedProjectRef {
    param([string]$ActualRef)
    $linkFile = Join-Path (Join-Path $script:phase8Root '.temp') 'project-ref'
    if ([string]::IsNullOrEmpty($ActualRef)) {
        if (-not (Test-Path -LiteralPath $linkFile -PathType Leaf)) {
            throw 'Safety stop: isolated Supabase CLI project-ref file is missing.'
        }
        $ActualRef = [System.IO.File]::ReadAllText($linkFile).TrimEnd("`r", "`n")
    }
    if ($ActualRef -cne $script:ExpectedProjectRef) {
        throw 'Safety stop: isolated Supabase CLI project-ref does not exactly match the approved Phase 8 project.'
    }
}

function Assert-ProjectIdentity {
    param([Parameter(Mandatory = $true)][object]$Project)
    if ($null -eq $Project.PSObject.Properties['ref'] -or
        $null -eq $Project.PSObject.Properties['name'] -or
        [string]$Project.ref -cne $script:ExpectedProjectRef -or
        [string]$Project.name -cne $script:ExpectedProjectName) {
        throw 'Safety stop: Management API must return an exact, non-empty approved project ref and name.'
    }
}

function Assert-OnlyExpectedMigration {
    param([Parameter(Mandatory = $true)][string]$CliOutput)
    $versions = @([regex]::Matches($CliOutput, '(?<!\d)\d{12,14}(?!\d)') | ForEach-Object { $_.Value } | Select-Object -Unique)
    if ($versions.Count -ne 2 -or
        (Compare-Object -ReferenceObject @('202610120001', '202610150001') -DifferenceObject @($versions | Sort-Object))) {
        throw 'Safety stop: CLI dry-run did not select exactly the two approved M1 migrations; output suppressed.'
    }
}

function Assert-CliExitCode {
    param([int]$ExitCode, [string]$Operation)
    if ($ExitCode -ne 0) {
        throw "Supabase CLI operation '$Operation' failed (exit $ExitCode); output suppressed and no later deploy step may run."
    }
}

function Get-CliSecretNames {
    param([Parameter(Mandatory = $true)][string]$CliOutput)
    $plain = [regex]::Replace($CliOutput, '\x1B\[[0-?]*[ -/]*[@-~]', '')
    if ($plain.TrimStart().StartsWith('[')) {
        $response = Convert-JsonArrayResponse -Json $plain -Label 'secret list' -RequiredStringProperties @('name')
        $names = @($response.Items | ForEach-Object { [string]$_.name })
        return $names
    }
    $names = [System.Collections.Generic.List[string]]::new()
    $verticalBar = [string][char]0x2502
    $separatorPattern = '[|\u2502]'
    $tableBorderChars = [char[]]@(
        [char]0x2500, [char]0x2502, [char]0x250C, [char]0x2510, [char]0x2514, [char]0x2518,
        [char]0x251C, [char]0x2524, [char]0x252C, [char]0x2534, [char]0x253C,
        [char]0x2550, [char]0x2551, [char]0x2554, [char]0x2557, [char]0x255A, [char]0x255D,
        [char]'+', [char]'-', [char]' '
    )
    foreach ($line in ($plain -split "`r?`n")) {
        $trimmed = $line.Trim()
        if ($trimmed -match $separatorPattern) {
            $normalized = $trimmed.Trim($tableBorderChars)
            $firstCell = ($normalized -split $separatorPattern, 2)[0].Trim()
            if ($firstCell -match '^[A-Z][A-Z0-9_]{1,127}$' -and $firstCell -cne 'NAME') { $names.Add($firstCell) }
        }
    }
    return @($names | Select-Object -Unique)
}

function Assert-ReviewedFileHash {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$ExpectedHash, [Parameter(Mandatory = $true)][string]$Label)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf) -or
        (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -cne $ExpectedHash) {
        throw "Safety stop: reviewed source hash mismatch at $Label."
    }
}

function Invoke-Phase8SelfTests {
    $passed = 0
    $expectedWorkdir = [System.IO.Path]::GetFullPath($script:phase8Root).TrimEnd('\')
    [Environment]::SetEnvironmentVariable('SUPABASE_WORKDIR', $expectedWorkdir, 'Process')
    $script:accessToken = 'mock-token-never-sent'
    $script:apiBase = 'https://api.supabase.com/v1'

    Assert-ProjectIdentity ([pscustomobject]@{ ref = $script:ExpectedProjectRef; name = $script:ExpectedProjectName }); $passed++
    Assert-LinkedProjectRef -ActualRef $script:ExpectedProjectRef; $passed++
    Assert-Phase8CliDirectory -CurrentDirectory $expectedWorkdir; $passed++
    Assert-OnlyExpectedMigration "Applying migration 202610120001_phase8_drive_sync.sql`nApplying migration 202610150001_phase8_m1_forward_repair.sql`n"; $passed++
    Assert-ReviewedFileHash -Path $script:migrationPath -ExpectedHash $script:ExpectedMigrationSha256 -Label $script:ExpectedMigration; $passed++
    $mockBar = [string][char]0x2502
    $mockSecretNames = @(Get-CliSecretNames ($mockBar + ' NAME ' + $mockBar + ' DIGEST ' + $mockBar + "`n" +
        $mockBar + ' OTHER_SECRET ' + $mockBar + ' redacted ' + $mockBar + "`n" +
        $mockBar + ' PHASE8_CLEANUP_TOKEN ' + $mockBar + ' redacted ' + $mockBar))
    if (@($mockSecretNames | Where-Object { $_ -ceq 'PHASE8_CLEANUP_TOKEN' }).Count -ne 1) { throw 'Self-test failure: exact cleanup secret table row was not recognized.' }; $passed++
    Assert-CliExitCode -ExitCode 0 -Operation 'mock-success'; $passed++

    $emptyHistory = Convert-MigrationHistoryJson -Json '[]'
    if ($emptyHistory.Count -ne 0) { throw 'Self-test failure: [] was not treated as empty migration history.' }; $passed++
    $oneHistory = Convert-MigrationHistoryJson -Json '[{"version":"202610120001","name":"phase8_drive_sync"}]'
    if ($oneHistory.Count -ne 1 -or $oneHistory.Records[0].version -cne '202610120001' -or $oneHistory.Records[0].name -cne 'phase8_drive_sync') { throw 'Self-test failure: one migration record was not preserved.' }; $passed++
    $multipleHistory = Convert-MigrationHistoryJson -Json '[{"version":"202610120001","name":"phase8_drive_sync"},{"version":"202610120002","name":"unexpected"}]'
    if ($multipleHistory.Count -ne 2) { throw 'Self-test failure: multiple migration records were not counted.' }; $passed++
    $badHistoryRejected = $false
    try { $null = Convert-MigrationHistoryJson -Json '[{"version":"202610120001"}' } catch { $badHistoryRejected = $true }
    if (-not $badHistoryRejected) { throw 'Self-test failure: malformed migration history JSON was accepted.' }; $passed++

    $emptyList = Convert-JsonArrayResponse -Json '[]' -Label 'mock buckets' -RequiredStringProperties @('id')
    if ($emptyList.Count -ne 0) { throw 'Self-test failure: empty JSON list was not treated as zero records.' }; $passed++
    $singleList = Convert-JsonArrayResponse -Json '[{"id":"one"}]' -Label 'mock buckets' -RequiredStringProperties @('id')
    if ($singleList.Count -ne 1 -or $singleList.Items[0].id -cne 'one') { throw 'Self-test failure: single JSON list record was not retained.' }; $passed++
    $multipleList = Convert-JsonArrayResponse -Json '[{"id":"one"},{"id":"two"}]' -Label 'mock buckets' -RequiredStringProperties @('id')
    if ($multipleList.Count -ne 2) { throw 'Self-test failure: multiple JSON list records were not counted.' }; $passed++
    $missingListFieldRejected = $false
    try { $null = Convert-JsonArrayResponse -Json '[{"name":"missing-id"}]' -Label 'mock buckets' -RequiredStringProperties @('id') } catch { $missingListFieldRejected = $true }
    if (-not $missingListFieldRejected) { throw 'Self-test failure: JSON list record without id was accepted.' }; $passed++
    $malformedListRejected = $false
    try { $null = Convert-JsonArrayResponse -Json '[{"id":"broken"}' -Label 'mock buckets' -RequiredStringProperties @('id') } catch { $malformedListRejected = $true }
    if (-not $malformedListRejected) { throw 'Self-test failure: malformed JSON list was accepted.' }; $passed++

    $emptySecretNames = @(Get-CliSecretNames -CliOutput '[]')
    if ($emptySecretNames.Count -ne 0) { throw 'Self-test failure: empty secret JSON list was not empty.' }; $passed++
    $singleSecretNames = @(Get-CliSecretNames -CliOutput '[{"name":"PHASE8_CLEANUP_TOKEN"}]')
    if ($singleSecretNames.Count -ne 1 -or $singleSecretNames[0] -cne 'PHASE8_CLEANUP_TOKEN') { throw 'Self-test failure: secret JSON name was not retained.' }; $passed++
    $multipleSecretNames = @(Get-CliSecretNames -CliOutput '[{"name":"OTHER_SECRET"},{"name":"PHASE8_CLEANUP_TOKEN"}]')
    if ($multipleSecretNames.Count -ne 2) { throw 'Self-test failure: multiple secret JSON names were not counted.' }; $passed++
    $missingSecretNameRejected = $false
    try { $null = Get-CliSecretNames -CliOutput '[{"value":"redacted"}]' } catch { $missingSecretNameRejected = $true }
    if (-not $missingSecretNameRejected) { throw 'Self-test failure: secret record without name was accepted.' }; $passed++
    $malformedSecretListRejected = $false
    try { $null = Get-CliSecretNames -CliOutput '[{"name":"PHASE8_CLEANUP_TOKEN"}' } catch { $malformedSecretListRejected = $true }
    if (-not $malformedSecretListRejected) { throw 'Self-test failure: malformed secret JSON list was accepted.' }; $passed++

    $failures = @(
        @{ Name = 'wrong Project Ref'; Action = { Assert-ProjectIdentity ([pscustomobject]@{ ref = 'wrong'; name = $script:ExpectedProjectName }) } },
        @{ Name = 'forbidden separate Phase8 project'; Action = { Assert-ProjectIdentity ([pscustomobject]@{ ref = 'jidyfemjzztlwjmijndx'; name = $script:ExpectedProjectName }) } },
        @{ Name = 'only one M1 migration selected'; Action = { Assert-OnlyExpectedMigration '202610120001_phase8_drive_sync.sql' } },
        @{ Name = 'wrong CLI linked Project Ref'; Action = { Assert-LinkedProjectRef -ActualRef 'wrong' } },
        @{ Name = 'wrong CLI workdir'; Action = { Assert-Phase8CliDirectory -CurrentDirectory 'C:\wrong\project' } },
        @{ Name = 'SUPABASE_WORKDIR redirect'; Action = { [Environment]::SetEnvironmentVariable('SUPABASE_WORKDIR', 'C:\wrong\project', 'Process'); Assert-Phase8CliDirectory -CurrentDirectory $expectedWorkdir } },
        @{ Name = 'wrong migration list'; Action = { Assert-OnlyExpectedMigration "Applying migration 202610120002_wrong.sql`n" } },
        @{ Name = 'bad migration hash'; Action = { Assert-ReviewedFileHash -Path $script:migrationPath -ExpectedHash ('0' * 64) -Label 'mock-source' } },
        @{ Name = 'missing cleanup secret'; Action = { $bar = [string][char]0x2502; $names = @(Get-CliSecretNames ($bar + ' NAME ' + $bar + ' DIGEST ' + $bar + "`n" + $bar + ' OTHER_SECRET ' + $bar + ' redacted ' + $bar)); if (@($names | Where-Object { $_ -ceq 'PHASE8_CLEANUP_TOKEN' }).Count -ne 1) { throw 'missing cleanup secret' } } },
        @{ Name = 'failed migration'; Action = { Assert-CliExitCode -ExitCode 1 -Operation 'db push --linked' } },
        @{ Name = 'failed function deploy'; Action = { Assert-CliExitCode -ExitCode 1 -Operation 'functions deploy phase8-drive-begin' } }
    )
    foreach ($case in $failures) {
        $stopped = $false
        try { & $case.Action } catch { $stopped = $true }
        if (-not $stopped) { throw "Self-test failure: '$($case.Name)' did not stop." }
        $passed++
    }
    Write-Host "Local fail-closed self-tests: $passed passed. No credential, CLI, or network operation was used."
}

function Invoke-Phase8Cli {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    Assert-Phase8CliDirectory
    $output = & npx --yes $script:supabaseCliSpec @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    Assert-CliExitCode -ExitCode $exitCode -Operation ($Arguments -join ' ')
    return (($output | ForEach-Object { [string]$_ }) -join "`n")
}

function Assert-ExpectedMigrationHistory {
    param([switch]$AfterApply)
    $rawHistory = Invoke-Phase8ManagementApi -Method GET `
        -Path "/projects/$script:ExpectedProjectRef/database/migrations" -RawJson
    $history = Convert-MigrationHistoryJson -Json $rawHistory
    $expectedNames = @($script:baselineMigrationNames)
    if ($AfterApply) { $expectedNames += @($script:ExpectedMigrationHashes.Keys) }
    $actualNames = @($history.Records | ForEach-Object { '{0}_{1}.sql' -f $_.version, $_.name } | Sort-Object)
    if ($actualNames.Count -ne $expectedNames.Count -or
        (Compare-Object -ReferenceObject @($expectedNames | Sort-Object) -DifferenceObject $actualNames)) {
        throw 'Safety stop: Planet migration history differs from the approved baseline plus selected M1 versions. No repair/replay is allowed.'
    }
    Write-Host "Remote migration history: exact approved set ($($history.Count) records)."
}

function Convert-MigrationHistoryJson {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Json)
    $response = Convert-JsonArrayResponse -Json $Json -Label 'migration history' `
        -RequiredStringProperties @('version', 'name')
    return [pscustomobject]@{ Count = $response.Count; Records = $response.Items }
}

function Convert-JsonArrayResponse {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Json,
        [Parameter(Mandatory = $true)][string]$Label,
        [string[]]$RequiredStringProperties = @()
    )

    $trimmed = $Json.Trim()
    if ($trimmed.Length -lt 2 -or $trimmed[0] -ne '[' -or $trimmed[$trimmed.Length - 1] -ne ']') {
        throw "Safety stop: $Label response is not a JSON array."
    }
    if ($trimmed -match '^\[\s*\]$') {
        $items = @()
    }
    else {
        try { $parsed = ConvertFrom-Json -InputObject $trimmed -ErrorAction Stop }
        catch { throw "Safety stop: $Label response contains invalid JSON." }
        if ($null -eq $parsed) { throw "Safety stop: $Label response parsed to null." }
        $items = @($parsed)
    }

    foreach ($item in $items) {
        if ($null -eq $item) { throw "Safety stop: $Label contains a null record." }
        foreach ($propertyName in $RequiredStringProperties) {
            $property = $item.PSObject.Properties[$propertyName]
            if ($null -eq $property -or $property.Value -isnot [string] -or
                [string]::IsNullOrWhiteSpace([string]$property.Value)) {
                throw "Safety stop: $Label record is missing valid '$propertyName' field."
            }
        }
    }
    return [pscustomobject]@{ Count = $items.Count; Items = [object[]]$items }
}

function Assert-Phase8ResourcesAbsent {
    # The Management API query endpoint is experimental. It is used only with
    # read_only=true and returns a single boolean, never application rows.
    $sql = @'
select (
  exists (
    select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname = any(array[
      'phase8_drive_upload_intents','phase8_drive_owner_sequences',
      'phase8_drive_manifests','phase8_drive_changes','phase8_drive_snapshots'
    ])
  )
  or exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname = any(array[
      'phase8_reject_immutable_mutation','phase8_can_access_staging_object',
      'phase8_begin_drive_upload','phase8_finalize_drive_upload',
      'phase8_begin_drive_snapshot','phase8_read_drive_snapshot_page',
      'phase8_claim_drive_orphans','phase8_expire_drive_orphan',
      'phase8_drive_sync_capabilities'
    ])
  )
  or exists (
    select 1 from pg_trigger t join pg_class c on c.oid=t.tgrelid
    join pg_namespace n on n.oid=c.relnamespace
    where not t.tgisinternal and n.nspname='public' and t.tgname = any(array[
      'phase8_drive_manifests_immutable','phase8_drive_changes_immutable'
    ])
  )
  or exists (
    select 1 from pg_policy p join pg_class c on c.oid=p.polrelid
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='storage' and c.relname='objects'
      and p.polname='phase8_drive_stage_insert'
  )
  or exists (select 1 from storage.buckets where id='phase8-drive-staging')
) as has_phase8_collision;
'@
    $rawResult = Invoke-Phase8ManagementApi -Method POST `
        -Path "/projects/$ExpectedProjectRef/database/query" `
        -Body @{ query = $sql; read_only = $true } -RawJson
    $rows = Convert-JsonArrayResponse -Json $rawResult -Label 'schema collision query'
    if ($rows.Count -ne 1 -or $null -eq $rows.Items[0].PSObject.Properties['has_phase8_collision'] -or
        $rows.Items[0].has_phase8_collision -isnot [bool]) {
        throw 'Safety stop: read-only schema collision query returned an unknown result shape.'
    }
    if ($rows.Items[0].has_phase8_collision) {
        throw 'Safety stop: one or more Phase 8 object names already exist outside migration history.'
    }
    Write-Host 'Read-only schema collision preflight: clear.'
}

function Assert-FunctionsAbsent {
    $raw = Invoke-Phase8ManagementApi -Method GET -Path "/projects/$ExpectedProjectRef/functions" -RawJson
    $existing = Convert-JsonArrayResponse -Json $raw -Label 'Edge Functions list' -RequiredStringProperties @('slug')
    foreach ($function in $ExpectedFunctions) {
        if (@($existing.Items | Where-Object { $_.slug -eq $function.Slug }).Count -ne 0) {
            throw "Safety stop: remote function '$($function.Slug)' already exists; overwriting is not allowed by this script."
        }
    }
    Write-Host 'Phase 8 Edge Function collision preflight: clear.'
}

function Assert-BucketAbsent {
    $raw = Invoke-Phase8ManagementApi -Method GET -Path "/projects/$ExpectedProjectRef/storage/buckets" -RawJson
    $buckets = Convert-JsonArrayResponse -Json $raw -Label 'Storage bucket list' -RequiredStringProperties @('id')
    if (@($buckets.Items | Where-Object { $_.id -eq $ExpectedBucket }).Count -ne 0) {
        throw 'Safety stop: the Phase 8 staging bucket already exists; inspect manually rather than updating it.'
    }
    Write-Host 'Phase 8 Storage bucket collision preflight: clear.'
}

function Assert-CleanupSecretAbsent {
    # The Management API secret listing returns secret values. Do not call it.
    # The operator must confirm the name is absent in Dashboard before apply.
    Write-Host "Before -Apply, confirm in the Phase 8 DEV Dashboard that $CleanupSecretName does not already exist; this script will never overwrite it."
}

function Confirm-ExactPhrase {
    param([Parameter(Mandatory = $true)][string]$Phrase, [Parameter(Mandatory = $true)][string]$Purpose)
    Write-Host $Purpose
    $answer = Read-Host "Type exactly: $Phrase"
    if ($answer -cne $Phrase) { throw 'Stopped: exact confirmation was not entered.' }
}

function Assert-RlsEnabled {
    $sql = @'
select count(*)::integer as rls_table_count
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public'
  and c.relname = any(array[
    'phase8_drive_upload_intents','phase8_drive_owner_sequences',
    'phase8_drive_manifests','phase8_drive_changes','phase8_drive_snapshots'
  ])
  and c.relrowsecurity;
'@
    $rawResult = Invoke-Phase8ManagementApi -Method POST `
        -Path "/projects/$ExpectedProjectRef/database/query" `
        -Body @{ query = $sql; read_only = $true } -RawJson
    $rows = Convert-JsonArrayResponse -Json $rawResult -Label 'RLS read-back'
    if ($rows.Count -ne 1 -or $null -eq $rows.Items[0].PSObject.Properties['rls_table_count'] -or
        $rows.Items[0].rls_table_count -isnot [ValueType] -or [int]$rows.Items[0].rls_table_count -ne 5) {
        throw 'Safety stop: read-back did not confirm RLS enabled on all five Phase 8 tables.'
    }
    Write-Host 'Database read-back: RLS enabled on all five Phase 8 tables.'
}

function Assert-BucketPrivate {
    $raw = Invoke-Phase8ManagementApi -Method GET -Path "/projects/$ExpectedProjectRef/storage/buckets" -RawJson
    $buckets = Convert-JsonArrayResponse -Json $raw -Label 'Storage bucket list' -RequiredStringProperties @('id')
    $matches = @($buckets.Items | Where-Object { $_.id -eq $ExpectedBucket })
    if ($matches.Count -ne 1 -or [bool]$matches[0].public) {
        throw 'Safety stop: staging bucket is missing, duplicated, or public.'
    }
    $sql = @'
select jsonb_build_object(
  'public', public,
  'file_size_limit', file_size_limit,
  'allowed_mime_types', allowed_mime_types
) as bucket_config
from storage.buckets where id='phase8-drive-staging';
'@
    $rawResult = Invoke-Phase8ManagementApi -Method POST `
        -Path "/projects/$ExpectedProjectRef/database/query" `
        -Body @{ query = $sql; read_only = $true } -RawJson
    $rows = Convert-JsonArrayResponse -Json $rawResult -Label 'bucket configuration read-back'
    if ($rows.Count -ne 1 -or $null -eq $rows.Items[0].PSObject.Properties['bucket_config']) {
        throw 'Safety stop: bucket metadata read-back was missing or had an unknown shape.'
    }
    $config = $rows.Items[0].bucket_config
    if ($null -eq $config -or $null -eq $config.PSObject.Properties['public'] -or
        $null -eq $config.PSObject.Properties['file_size_limit'] -or
        $null -eq $config.PSObject.Properties['allowed_mime_types']) {
        throw 'Safety stop: bucket configuration read-back is missing required fields.'
    }
    $mimeTypes = @($config.allowed_mime_types | ForEach-Object { [string]$_ })
    if ([bool]$config.public -or [int64]$config.file_size_limit -ne 10485760 -or
        $mimeTypes.Count -ne 1 -or $mimeTypes[0] -cne 'application/json') {
        throw 'Safety stop: bucket must be private, exactly 10 MiB, and allow only application/json.'
    }
    Write-Host 'Storage read-back: private, 10 MiB, application/json only.'
}

function Assert-FunctionPresent {
    param([Parameter(Mandatory = $true)][string]$Slug, [Parameter(Mandatory = $true)][bool]$VerifyJwt)
    $raw = Invoke-Phase8ManagementApi -Method GET -Path "/projects/$ExpectedProjectRef/functions" -RawJson
    $functions = Convert-JsonArrayResponse -Json $raw -Label 'Edge Functions list' -RequiredStringProperties @('slug')
    $matches = @($functions.Items | Where-Object { $_.slug -eq $Slug })
    if ($matches.Count -ne 1 -or $null -eq $matches[0].PSObject.Properties['verify_jwt'] -or
        $matches[0].verify_jwt -isnot [bool] -or $matches[0].verify_jwt -ne $VerifyJwt) {
        throw "Safety stop: function '$Slug' is missing or verify_jwt does not match the isolated config."
    }
    Write-Host "Function read-back: $Slug present; verify_jwt=$VerifyJwt."
}

function Assert-CleanupSecretNamePresent {
    # Supabase CLI list output contains names only. Never print that output.
    $list = Invoke-Phase8Cli -Arguments @('secrets', 'list', '--project-ref', $ExpectedProjectRef)
    $names = @(Get-CliSecretNames -CliOutput $list)
    if (@($names | Where-Object { $_ -ceq $CleanupSecretName }).Count -ne 1) {
        throw "Safety stop: secret name $CleanupSecretName was not found; no further step was attempted."
    }
    Write-Host "Cleanup secret read-back: $CleanupSecretName exists (value not read or displayed)."
}
function Get-PlanetDataFingerprint {
    $tables = @('auth.users','public.profiles','public.world_publishes','public.world_validated_roads','public.world_validated_road_sections','public.world_active_world_generations','public.world_active_world_state','public.world_active_world_traces')
    $parts = @($tables | ForEach-Object {
        "select '$_' as relation, count(*)::bigint as rows, md5(coalesce(string_agg(md5(to_jsonb(t)::text),'' order by md5(to_jsonb(t)::text)),'')) as fingerprint from $_ t"
    })
    $query = 'select coalesce(jsonb_agg(q order by relation),''[]''::jsonb) as records from (' + ($parts -join ' union all ') + ') q'
    $raw = Invoke-Phase8ManagementApi -Method POST -Path "/projects/$ExpectedProjectRef/database/query" -Body @{ query=$query; read_only=$true } -RawJson
    $rows = Convert-JsonArrayResponse -Json $raw -Label 'Planet fingerprint'
    if ($rows.Count -ne 1 -or $null -eq $rows.Items[0].PSObject.Properties['records']) { throw 'Unknown Planet fingerprint result.' }
    return (ConvertTo-Json -InputObject $rows.Items[0].records -Depth 8 -Compress)
}

function Assert-VerifiedBackup {
    if ([string]::IsNullOrWhiteSpace($script:BackupDirectory)) { throw 'Safety stop: a restore-verified backup directory is required before remote writes.' }
    $proofPath = Join-Path $script:BackupDirectory 'restore-verification.json'
    if (-not (Test-Path -LiteralPath $proofPath -PathType Leaf)) { throw 'Safety stop: restore verification receipt is missing.' }
    $proof = Get-Content -LiteralPath $proofPath -Raw | ConvertFrom-Json
    if ($proof.projectRef -cne $script:ExpectedProjectRef -or $proof.restorePassed -isnot [bool] -or
        -not $proof.restorePassed -or [int]$proof.authUsers -ne 6 -or [int]$proof.migrationRows -ne 13) {
        throw 'Safety stop: backup restore proof is not the approved Planet baseline.'
    }
    $age = [DateTimeOffset]::UtcNow - [DateTimeOffset]::Parse($proof.verifiedAtUtc)
    if ($age.TotalMinutes -lt 0 -or $age.TotalHours -gt 2) { throw 'Safety stop: backup verification is stale.' }
    foreach ($name in @('roles.sql','schema.sql','data.sql')) {
        $hashProperty = $proof.hashes.PSObject.Properties[$name]
        if ($null -eq $hashProperty) { throw 'Safety stop: backup proof omitted a required file.' }
        Assert-ReviewedFileHash -Path (Join-Path $script:BackupDirectory $name) -ExpectedHash $hashProperty.Value -Label $name
    }
    Write-Host 'Backup integrity and successful isolated PostgreSQL restore receipt verified.'
}

function Initialize-PlanetCliWorkspace {
    $dest = Join-Path $script:deploymentRoot 'supabase'
    $null = New-Item -ItemType Directory -Path (Join-Path $dest 'migrations') -Force
    Copy-Item -LiteralPath $script:configPath -Destination (Join-Path $dest 'config.toml') -Force
    if (Test-Path -LiteralPath (Join-Path $dest 'functions')) {
        throw 'Safety stop: deployment workspace already contains function sources; inspect instead of overwriting.'
    }
    Copy-Item -LiteralPath $script:functionsDirectory -Destination (Join-Path $dest 'functions') -Recurse
    foreach ($name in $script:baselineMigrationNames) {
        Copy-Item -LiteralPath (Join-Path $script:baselineMigrationDirectory $name) -Destination (Join-Path $dest 'migrations') -Force
    }
    foreach ($name in $script:ExpectedMigrationHashes.Keys) {
        Copy-Item -LiteralPath (Join-Path $script:migrationDirectory $name) -Destination (Join-Path $dest 'migrations') -Force
    }
    $actual = @(Get-ChildItem -LiteralPath (Join-Path $dest 'migrations') -File | Select-Object -ExpandProperty Name | Sort-Object)
    $expected = @(@($script:baselineMigrationNames) + @($script:ExpectedMigrationHashes.Keys) | Sort-Object)
    if ($actual.Count -ne $expected.Count -or (Compare-Object $expected $actual)) { throw 'Safety stop: unexpected staged migration candidate.' }
}

function Invoke-PlanetCli {
    param([Parameter(Mandatory=$true)][string[]]$Arguments)
    Assert-ApprovedLocalBundle
    $dest = Join-Path $script:deploymentRoot 'supabase'
    $actualNames = @(Get-ChildItem -LiteralPath (Join-Path $dest 'migrations') -File | Select-Object -ExpandProperty Name | Sort-Object)
    $expectedNames = @(@($script:baselineMigrationNames) + @($script:ExpectedMigrationHashes.Keys) | Sort-Object)
    if ($actualNames.Count -ne $expectedNames.Count -or (Compare-Object $expectedNames $actualNames)) {
        throw 'Safety stop: staged migration allowlist changed before CLI operation.'
    }
    Assert-ReviewedFileHash -Path (Join-Path $dest 'config.toml') -ExpectedHash $script:ExpectedConfigSha256 -Label 'staged config'
    foreach ($name in $script:ExpectedMigrationHashes.Keys) {
        Assert-ReviewedFileHash -Path (Join-Path $dest "migrations/$name") -ExpectedHash $script:ExpectedMigrationHashes[$name] -Label $name
    }
    foreach ($name in $script:baselineMigrationNames) {
        $hash = (Get-FileHash -LiteralPath (Join-Path $script:baselineMigrationDirectory $name) -Algorithm SHA256).Hash
        Assert-ReviewedFileHash -Path (Join-Path $dest "migrations/$name") -ExpectedHash $hash -Label $name
    }
    foreach ($file in $script:ExpectedFunctionFiles) {
        Assert-ReviewedFileHash -Path (Join-Path $dest $file) -ExpectedHash $script:ExpectedFunctionFileHashes[$file] -Label $file
    }
    if ($Arguments[0] -cne 'link') {
        $linkPath = Join-Path $dest '.temp/project-ref'
        if (-not(Test-Path -LiteralPath $linkPath) -or [IO.File]::ReadAllText($linkPath).Trim() -cne $script:ExpectedProjectRef) { throw 'Safety stop: staged CLI link target mismatch.' }
    }
    # Explicit --workdir and no environment override: never use root Planet .temp.
    [Environment]::SetEnvironmentVariable('SUPABASE_WORKDIR',$null,'Process')
    $previousErrorPreference = $ErrorActionPreference
    try {
        # Windows PowerShell 5.1 wraps native stderr in ErrorRecord; the CLI
        # routinely uses stderr for progress. Its exit code remains mandatory.
        $ErrorActionPreference = 'Continue'
        $out = & npx.cmd --yes supabase@2.120.0 @Arguments --workdir $script:deploymentRoot 2>&1
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousErrorPreference }
    Assert-CliExitCode -ExitCode $code -Operation $Arguments[0]
    if ($Arguments -contains 'json') {
        # Progress/version notices are native stderr ErrorRecords in PS 5.1,
        # not part of the JSON response. Never parse merged streams as JSON.
        $out = @($out | Where-Object { $_ -isnot [Management.Automation.ErrorRecord] })
    }
    return (($out | ForEach-Object { [string]$_ }) -join [Environment]::NewLine)
}

function Get-ServerApiKey {
    $raw = Invoke-Phase8ManagementApi -Method GET -Path "/projects/$ExpectedProjectRef/api-keys?reveal=true" -RawJson
    $keys = Convert-JsonArrayResponse -Json $raw -Label 'server API keys' -RequiredStringProperties @('name','api_key')
    $matches = @($keys.Items | Where-Object { $_.name -ceq 'service_role' })
    if ($matches.Count -ne 1) { throw 'Safety stop: expected server-only service_role key is unavailable; no fallback.' }
    return [string]$matches[0].api_key
}

function Invoke-ServerStorage {
    param([string]$ServerKey,[string]$Method,[string]$Path,[object]$Body)
    if ($Path -cne '/bucket' -and $Path -cne "/bucket/$ExpectedBucket") { throw 'Safety stop: unauthorized Storage API path.' }
    $headers = @{ apikey=$ServerKey; Authorization="Bearer $ServerKey" }
    try {
        $params = @{ Method=$Method; Uri="https://$ExpectedProjectRef.supabase.co/storage/v1$Path"; Headers=$headers; TimeoutSec=45; UseBasicParsing=$true }
        if ($null -ne $Body) { $params.ContentType='application/json'; $params.Body=ConvertTo-Json -InputObject $Body -Depth 8 -Compress }
        $response = Invoke-WebRequest @params
        return (ConvertFrom-Json $response.Content)
    } catch {
        $status='unknown'; try { $status=[string][int]$_.Exception.Response.StatusCode } catch {}
        throw "Storage API failed (HTTP $status); response suppressed."
    }
}

if ($SelfTest) {
    try { Invoke-Phase8SelfTests }
    finally { [Environment]::SetEnvironmentVariable('SUPABASE_WORKDIR',$oldSupabaseWorkdir,'Process') }
    return
}

try {
    Assert-ApprovedLocalBundle
    if ($UseProcessAccessToken) {
        if ([string]::IsNullOrWhiteSpace($oldAccessToken)) { throw 'Approved process PAT is absent.' }
        $accessToken=$oldAccessToken
    } else {
        if ($NonInteractive) { throw 'NonInteractive requires explicitly approved -UseProcessAccessToken.' }
        $accessTokenSecure=Read-Host 'Planet DEV Supabase PAT (masked)' -AsSecureString
        $accessToken=ConvertFrom-SecurePrompt -SecureValue $accessTokenSecure -Bstr ([ref]$accessBstr)
        if ([string]::IsNullOrWhiteSpace($accessToken)) { throw 'A non-empty PAT is required.' }
    }
    [Environment]::SetEnvironmentVariable('SUPABASE_ACCESS_TOKEN',$accessToken,'Process')
    $project=Invoke-Phase8ManagementApi -Method GET -Path "/projects/$ExpectedProjectRef"
    Assert-ProjectIdentity -Project $project
    Write-Host "Verified Planet DEV target: $ExpectedProjectRef ($ExpectedProjectName)."
    Write-Host ('Approved migrations: '+(@($ExpectedMigrationHashes.Keys) -join ', '))
    if ($ResumeAfterMigration) {
        Assert-ExpectedMigrationHistory -AfterApply
        Assert-RlsEnabled
        Assert-BucketPrivate
    } else {
        Assert-ExpectedMigrationHistory
        Assert-Phase8ResourcesAbsent
        Assert-BucketAbsent
    }
    Assert-FunctionsAbsent
    if (-not $Apply) {
        Write-Host 'Read-only preflight passed; no migration/bucket/function/secret was written.'
        return
    }

    Assert-VerifiedBackup
    $before=Get-PlanetDataFingerprint
    if (-not $ResumeAfterMigration) {
    Initialize-PlanetCliWorkspace
    $null=Invoke-PlanetCli -Arguments @('link','--project-ref',$ExpectedProjectRef,'--yes')
    $dryRun=Invoke-PlanetCli -Arguments @('db','push','--dry-run','--linked')
    Assert-OnlyExpectedMigration -CliOutput $dryRun
    Write-Host 'Dry-run: exactly the two approved M1 migrations; historical Planet migrations will not run.'
    if (-not $NonInteractive) {
        Confirm-ExactPhrase -Phrase "APPLY $ExpectedProjectRef" -Purpose 'Apply only M1 additions to the approved Planet DEV project.'
    }
    Assert-ProjectIdentity (Invoke-Phase8ManagementApi -Method GET -Path "/projects/$ExpectedProjectRef")
    Assert-ExpectedMigrationHistory
    Assert-ApprovedLocalBundle
    Assert-VerifiedBackup
    if ((Get-PlanetDataFingerprint) -cne $before) { throw 'Safety stop: existing Planet/Auth data changed since preflight.' }
    $null=Invoke-PlanetCli -Arguments @('db','push','--linked','--yes')
    Assert-ExpectedMigrationHistory -AfterApply
    Assert-RlsEnabled
    if ((Get-PlanetDataFingerprint) -cne $before) { throw 'Safety stop: existing Planet/Auth fingerprint changed after migration.' }

    $serverKey=Get-ServerApiKey
    $null=Invoke-ServerStorage -ServerKey $serverKey -Method POST -Path '/bucket' -Body @{
        id=$ExpectedBucket; name=$ExpectedBucket; public=$false
        file_size_limit=10485760; allowed_mime_types=@('application/json')
    }
    Assert-BucketPrivate
    } else {
        Write-Host 'Verified migration/private-bucket stage resumed; no migration replay and no bucket overwrite.'
    }

    # Generate a new server-only secret in memory, never CLI arguments or files.
    $secretsRaw=Invoke-PlanetCli -Arguments @('secrets','list','--project-ref',$ExpectedProjectRef,'--output','json')
    $secretNames=@(Get-CliSecretNames -CliOutput $secretsRaw)
    if ($secretNames -ccontains $CleanupSecretName) { throw 'Safety stop: cleanup secret already exists; no overwrite permitted.' }
    $randomBytes=New-Object byte[] 32
    $rng=[Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($randomBytes) } finally { $rng.Dispose() }
    $cleanupToken=[Convert]::ToBase64String($randomBytes)
    $secretBody=@(@{name=$CleanupSecretName;value=$cleanupToken})
    $null=Invoke-Phase8ManagementApi -Method POST -Path "/projects/$ExpectedProjectRef/secrets" -Body $secretBody
    $secretBody=$null
    [Array]::Clear($randomBytes,0,$randomBytes.Length)
    $cleanupToken=$null
    $secretsRaw=Invoke-PlanetCli -Arguments @('secrets','list','--project-ref',$ExpectedProjectRef,'--output','json')
    if (@(Get-CliSecretNames -CliOutput $secretsRaw) -cnotcontains $CleanupSecretName) { throw 'Cleanup secret name was not confirmed.' }

    foreach ($function in $ExpectedFunctions) {
        Assert-ProjectIdentity (Invoke-Phase8ManagementApi -Method GET -Path "/projects/$ExpectedProjectRef")
        # All four names were absent before migration. No automatic overwrite.
        $raw=Invoke-Phase8ManagementApi -Method GET -Path "/projects/$ExpectedProjectRef/functions" -RawJson
        $functions=Convert-JsonArrayResponse -Json $raw -Label 'functions' -RequiredStringProperties @('slug')
        if (@($functions.Items | Where-Object { $_.slug -ceq $function.Slug }).Count -ne 0) { throw 'Safety stop: function appeared before deploy; no overwrite.' }
        $null=Invoke-PlanetCli -Arguments @('functions','deploy',$function.Slug,'--project-ref',$ExpectedProjectRef,'--use-api')
        Assert-FunctionPresent -Slug $function.Slug -VerifyJwt $function.VerifyJwt
    }
    if ((Get-PlanetDataFingerprint) -cne $before) { throw 'Safety stop: existing Planet/Auth data fingerprint changed.' }
    Write-Host 'M1 deployment/read-backs completed. Synthetic remote E2E acceptance remains a separate result.'
}
catch {
    throw "STOP: $($_.Exception.Message)"
}
finally {
    [Environment]::SetEnvironmentVariable('SUPABASE_ACCESS_TOKEN',$oldAccessToken,'Process')
    [Environment]::SetEnvironmentVariable('SUPABASE_DB_PASSWORD',$oldDbPassword,'Process')
    [Environment]::SetEnvironmentVariable('SUPABASE_WORKDIR',$oldSupabaseWorkdir,'Process')
    if ($accessBstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($accessBstr) }
    if ($dbBstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($dbBstr) }
    if ($cleanupBstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($cleanupBstr) }
    $accessToken=$null; $dbPassword=$null; $cleanupToken=$null; $serverKey=$null
}
