param([string]$DartExecutable = 'dart')
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$entry = Join-Path $repo 'tool/world_scoring_js.dart'
$output = Join-Path $repo 'supabase/functions/process-world-publish/world_scoring.generated.js'
$boundaryEntry = Join-Path $repo 'tool/world_scoring_boundary_js.dart'
$boundaryOutput = Join-Path $repo 'test/fixtures/world_scoring_boundary.generated.js'
$sources = [Collections.Generic.HashSet[string]]::new()
function Add-Source([string]$sourcePath) {
  $absolute = [IO.Path]::GetFullPath($sourcePath)
  if (-not $sources.Add($absolute)) { return }
  $source = [IO.File]::ReadAllText($absolute)
  $imports = [regex]::Matches($source, "(?:import|export)\s+'([^']+)'")
  foreach ($match in $imports) {
    $relative = $match.Groups[1].Value
    if ($relative.StartsWith('dart:')) { continue }
    if ($relative.StartsWith('package:')) { throw 'Unexpected package dependency in pure scoring compiler.' }
    Add-Source (Join-Path ([IO.Path]::GetDirectoryName($absolute)) $relative)
  }
}
Add-Source $entry
Add-Source $boundaryEntry
& $DartExecutable compile js -O2 --no-source-maps $entry -o $output
if ($LASTEXITCODE -ne 0) { throw 'Scoring compilation failed.' }
& $DartExecutable compile js -O2 --no-source-maps $boundaryEntry -o $boundaryOutput
if ($LASTEXITCODE -ne 0) { throw 'Boundary test compilation failed.' }
# Generated compiler dependency paths are machine-specific, not source artifacts.
foreach ($artifact in @($output, $boundaryOutput)) {
  if (Test-Path -LiteralPath ($artifact + '.deps')) { Remove-Item -LiteralPath ($artifact + '.deps') }
}
function Get-NormalizedHash([string]$sourcePath) {
  $bytes = [Text.Encoding]::UTF8.GetBytes([IO.File]::ReadAllText($sourcePath).Replace("`r`n", "`n"))
  $digest = [Security.Cryptography.SHA256]::HashData($bytes)
  return [Convert]::ToHexString($digest).ToLowerInvariant()
}
$hashes = [ordered]@{}
foreach ($sourcePath in ($sources | Sort-Object)) {
  $relative = [IO.Path]::GetRelativePath($repo, $sourcePath).Replace('\', '/')
  $hashes[$relative] = Get-NormalizedHash $sourcePath
}
$manifest = [ordered]@{ compiler = (& $DartExecutable --version 2>&1 | Out-String).Trim();
  artifact_sha256 = (Get-NormalizedHash $output);
  boundary_artifact_sha256 = (Get-NormalizedHash $boundaryOutput); sources = $hashes }
[IO.File]::WriteAllText((Join-Path $repo 'supabase/functions/process-world-publish/world_scoring.manifest.json'),
  ($manifest | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
