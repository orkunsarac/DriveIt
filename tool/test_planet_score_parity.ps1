param(
  [string]$DartExecutable='dart',
  [string]$DenoExecutable='deno',
  [string]$BaselineBundle
)
$ErrorActionPreference='Stop'
$taskRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Push-Location $taskRoot
try {
  $taskFixtures=& $DartExecutable run tool/planet_score_parity_oracle.dart
  if($LASTEXITCODE -ne 0){throw 'Native Dart parity oracle failed'}
  $taskFixtures | & $DenoExecutable run --allow-read tool/test_planet_score_parity.ts
  if($LASTEXITCODE -ne 0){throw 'Current Planet bundle parity failed'}
  if($BaselineBundle){
    $taskBaseline=[IO.Path]::GetFullPath($BaselineBundle)
    if(-not (Test-Path -LiteralPath $taskBaseline -PathType Leaf)){throw 'Baseline bundle missing'}
    $taskFixtures | & $DenoExecutable run --allow-read tool/test_planet_score_parity.ts ([Uri]::new($taskBaseline).AbsoluteUri)
    if($LASTEXITCODE -ne 0){throw 'Baseline Planet bundle parity failed'}
  }
} finally { Pop-Location }
