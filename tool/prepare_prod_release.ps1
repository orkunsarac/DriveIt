param([Parameter(Mandatory)][string]$OutputDirectory)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $root
try {
  & ./tool/prepare_prod.ps1 -SelfTest
  $out=[IO.Path]::GetFullPath((Join-Path $root $OutputDirectory))
  $tmp=[IO.Path]::GetFullPath((Join-Path $root 'tmp'))+[IO.Path]::DirectorySeparatorChar
  if(!$out.StartsWith($tmp,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $out)){throw 'Output must be a new repository tmp subdirectory.'}
  $manifest=Get-Content -Raw supabase/prod/preparation_manifest.json|ConvertFrom-Json
  $config=Get-Content -Raw supabase/prod/config.toml
  foreach($f in $manifest.functions){
    $jwt=if($f -eq 'phase8-drive-cleanup'){'false'}else{'true'}
    if($config -notmatch ('(?s)\[functions\.'+[regex]::Escape($f)+'\]\s*(?:#[^\n]*\n\s*)?verify_jwt\s*=\s*'+$jwt)){throw 'Missing/mismatched function JWT policy'}
  }
  New-Item -ItemType Directory -Path (Join-Path $out 'supabase')|Out-Null
  Copy-Item supabase/prod/config.toml (Join-Path $out 'supabase/config.toml')
  foreach($entry in $manifest.files){
    if($entry.path -match '^supabase/(?:phase8-dev/supabase/)?functions/(.+)$'){
      $relative=$Matches[1]
      if($relative -match '\.test\.|_test\.|(^|/)\.'){throw 'Unexpected function/test path'}
      $dest=Join-Path $out ('supabase/functions/'+$relative)
      New-Item -ItemType Directory -Path (Split-Path $dest) -Force|Out-Null
      Copy-Item -LiteralPath $entry.path -Destination $dest
    }
  }
  # The builder accepts only a direct tmp/*.sql artifact; stage there then copy.
  $intermediate='tmp/pgr4a-review-'+[guid]::NewGuid().ToString('N')+'.sql'
  & 'C:\Users\PC\.deno\bin\deno.exe' run --allow-read --allow-write=tmp tool/build_prod_transaction.ts $intermediate
  if($LASTEXITCODE -ne 0){throw 'Atomic bundle failed'}
  Copy-Item -LiteralPath $intermediate -Destination (Join-Path $out 'atomic.sql')
  Set-Content -LiteralPath (Join-Path $out '.gitignore') '*'
  'Prepared offline release artifacts only; no project link, secret or deployment.'
} finally {Pop-Location}
