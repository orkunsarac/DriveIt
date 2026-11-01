$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
function Encode-Define([string]$value) { [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($value)) }
function Test-Guard([string]$label, [string]$entry, [bool]$expectSuccess) {
    $encoded = Encode-Define $entry
    $output = (& .\gradlew.bat help --console=plain "-Pdart-defines=$encoded" 2>&1 | Out-String)
    $code = $LASTEXITCODE
    if (($code -eq 0) -ne $expectSuccess) { throw "Guard test failed: $label (exit $code)" }
    if (!$expectSuccess -and $output -notmatch 'forbidden') { throw "Unexpected failure: $label" }
    $value = $entry.Substring($entry.IndexOf('=') + 1)
    if (!$expectSuccess -and ($output.Contains($value) -or $output.Contains($encoded))) {
        throw "Guard diagnostics exposed a synthetic value: $label"
    }
    Write-Output "PASS $label (Gradle exit $code)"
}
Push-Location (Join-Path $root 'android')
try {
    Test-Guard 'publishable' 'SUPABASE_PUBLISHABLE_KEY=sb_publishable_synthetic' $true
    Test-Guard 'secret' 'SUPABASE_PUBLISHABLE_KEY=sb_secret_synthetic' $false
    $payload = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('{"role":"service_role"}')).TrimEnd('=').Replace('+','-').Replace('/','_')
    Test-Guard 'service role JWT' "SUPABASE_PUBLISHABLE_KEY=x.$payload.x" $false
} finally { Pop-Location }
exit 0
