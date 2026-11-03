function Get-R6B5MigrationIdentity($entry){
  $name=[IO.Path]::GetFileNameWithoutExtension($entry.path)
  if($name -cnotmatch '^([0-9]{12})_([a-z0-9_]+)$'){throw 'Unexpected migration filename.'}
  return @{version=$Matches[1];name=$Matches[2]}
}

function New-R6B5AtomicMigrationStatement([string]$sql,$entry){
  $identity=Get-R6B5MigrationIdentity $entry
  $sourceLines=[System.Collections.Generic.List[string]]::new();$removedBegin=$false
  foreach($line in ($sql -split "`n")){
    if(!$removedBegin -and $line.Trim() -ieq 'begin;'){$removedBegin=$true;continue}
    $sourceLines.Add($line)
  }
  # Some reviewed migrations are single statements without explicit
  # transaction markers. The outer wrapper supplies their transaction
  # boundary; when a source COMMIT exists, remove it from the outer body.
  $body=($sourceLines -join "`n").TrimEnd()
  if($body -match '(?is)commit\s*;\s*$'){$body=[regex]::Replace($body,'(?is)commit\s*;\s*$','')}
  $encoded=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($sql))
  $record="INSERT INTO supabase_migrations.schema_migrations(version,name,statements) VALUES ('$($identity.version)','$($identity.name)',ARRAY[convert_from(decode('$encoded','base64'),'UTF8')]);"
  return "BEGIN;`n$body`n$record`nCOMMIT;`n"
}
