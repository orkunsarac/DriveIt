param([string]$DartExecutable='dart')
$ErrorActionPreference='Stop'
$taskRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$taskEntry=Join-Path $taskRoot 'tool/planet_detail_js.dart'
$taskOutput=Join-Path $taskRoot 'supabase/functions/planet-trace-detail/score.generated.js'
& $DartExecutable compile js -O2 --no-source-maps $taskEntry -o $taskOutput
if($LASTEXITCODE -ne 0){throw 'Detail score compilation failed'}
Remove-Item -LiteralPath ($taskOutput+'.deps') -ErrorAction SilentlyContinue
$taskSources=[Collections.Generic.HashSet[string]]::new()
function Add-DetailSource([string]$sourcePath){
  $taskPath=[IO.Path]::GetFullPath($sourcePath)
  if(-not $taskSources.Add($taskPath)){return}
  foreach($taskMatch in [regex]::Matches([IO.File]::ReadAllText($taskPath),"(?:import|export)\s+'([^']+)'") ){
    $taskRelative=$taskMatch.Groups[1].Value
    if($taskRelative.StartsWith('dart:')){continue}
    if($taskRelative.StartsWith('package:')){throw 'Unexpected non-pure Dart import'}
    Add-DetailSource (Join-Path ([IO.Path]::GetDirectoryName($taskPath)) $taskRelative)
  }
}
Add-DetailSource $taskEntry
function Detail-Hash([string]$path){
  $taskBytes=[Text.Encoding]::UTF8.GetBytes([IO.File]::ReadAllText($path).Replace("`r`n","`n"))
  [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($taskBytes)).ToLowerInvariant()
}
$taskHashes=[ordered]@{}
foreach($taskSource in ($taskSources|Sort-Object)){
  $taskHashes[[IO.Path]::GetRelativePath($taskRoot,$taskSource).Replace('\','/')]=Detail-Hash $taskSource
}
$taskManifest=@{artifact_sha256=(Detail-Hash $taskOutput);sources=$taskHashes}
[IO.File]::WriteAllText((Join-Path $taskRoot 'supabase/functions/planet-trace-detail/score.manifest.json'),
  ($taskManifest|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
