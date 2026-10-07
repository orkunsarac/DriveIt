param([string]$ProjectRef='viqngnjfgknpxtoapzcg')
$ErrorActionPreference='Stop'
if($ProjectRef -ne 'viqngnjfgknpxtoapzcg'){throw 'DEV-only diagnostic'}
$taskToken=$env:SUPABASE_ACCESS_TOKEN
if(-not $taskToken){$taskToken=[Environment]::GetEnvironmentVariable('SUPABASE_ACCESS_TOKEN','User')}
try {
  # Privileged SERVER read diagnostic, not client endpoint/auth bypass.
  # Secrets and private source stay in memory and never enter argv/disk/logs.
  $taskKeys=Invoke-RestMethod -Uri "https://api.supabase.com/v1/projects/$ProjectRef/api-keys?reveal=true" -Headers @{Authorization=('Bearer '+$taskToken)}
  $taskServerKey=($taskKeys|Where-Object {$_.name -eq 'service_role'}|Select-Object -First 1).api_key
  if(-not $taskServerKey){throw 'Server read credential unavailable'}
  $taskHeaders=@{apikey=$taskServerKey;Authorization=('Bearer '+$taskServerKey)}
  foreach($taskId in @('d325c0c777bd1fd062bc54d71142a1f2','b58b483cd1db1a4b0b0e958a8c397591')){
    $taskContext=Invoke-RestMethod -Method Post -Uri "https://$ProjectRef.supabase.co/rest/v1/rpc/read_planet_trace_detail_context" -Headers $taskHeaders -ContentType 'application/json' -Body (@{p_trace_id=$taskId}|ConvertTo-Json)
    if(-not $taskContext){throw 'Active trace not found'}
    $taskWatch=[Diagnostics.Stopwatch]::StartNew()
    $taskSource=Invoke-WebRequest -Uri ("https://$ProjectRef.supabase.co/storage/v1/object/authenticated/world-drive-sources/"+$taskContext.publish.source_path) -Headers $taskHeaders
    $taskStorageMs=$taskWatch.Elapsed.TotalMilliseconds
    $taskContent=$taskSource.Content
    if($taskContent -is [byte[]]){$taskContent=[Text.Encoding]::UTF8.GetString($taskContent)}
    $taskInput=@{context=$taskContext;source=($taskContent|ConvertFrom-Json)}|ConvertTo-Json -Depth 20 -Compress
    $taskInfo=[Diagnostics.ProcessStartInfo]::new()
    $taskInfo.FileName=Join-Path $PSScriptRoot '../tmp/supabase-cli-npm-cache/_npx/05b6ef7b13673c57/node_modules/@deno/win32-x64/deno.exe'
    $taskInfo.Arguments='run --allow-read tool/planet_detail_acceptance.ts'
    $taskInfo.WorkingDirectory=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $taskInfo.UseShellExecute=$false;$taskInfo.CreateNoWindow=$true
    $taskInfo.RedirectStandardInput=$true;$taskInfo.RedirectStandardOutput=$true;$taskInfo.RedirectStandardError=$true
    $taskProcess=[Diagnostics.Process]::Start($taskInfo)
    $taskProcess.StandardInput.Write($taskInput);$taskProcess.StandardInput.Close()
    $taskPublic=$taskProcess.StandardOutput.ReadToEnd()|ConvertFrom-Json
    $taskProcess.WaitForExit()
    if($taskProcess.ExitCode -ne 0){throw 'Summary diagnostic failed'}
    [ordered]@{trace_id=$taskId;generation=$taskContext.generation;driver=$taskContext.display_name;username=$taskContext.username;
      ownership_distance_meters=$taskContext.ownership_distance_meters;drive_date=$taskPublic.drive_date;
      distance_meters=$taskPublic.distance_meters;duration_seconds=$taskPublic.duration_seconds;
      average_speed_kmh=$taskPublic.average_speed_kmh;maximum_speed_kmh=$taskPublic.maximum_speed_kmh;
      drive_score=$taskPublic.score.displayScore;score_ms=$taskPublic.score_ms;storage_ms=$taskStorageMs;
      warm_summary_ms=$taskPublic.warm_summary_ms;source_loads=$taskPublic.source_loads;
      summary_payload_bytes=[Text.Encoding]::UTF8.GetByteCount(($taskPublic|ConvertTo-Json -Depth 10 -Compress))}|ConvertTo-Json -Compress
  }
}catch{Write-Output 'Read-only DEV source acceptance failed; private error payload omitted';exit 1}
