param([switch]$SelfTest,[string]$LeftContainer,[string]$RightContainer)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Assert-PhysicalPgIsolation($Left,$Right) {
  $keys=@()
  foreach($item in @($Left,$Right)) {
    if($item.Target -cne '/var/lib/postgresql/data' -or [string]::IsNullOrWhiteSpace($item.Volume)) { throw 'Unknown PGDATA mount.' }
    $sub=[string]$item.Subpath
    if($sub -match '(^|/)\.\.?(/|$)|\\|//' -or $sub.StartsWith('/') -or $sub.EndsWith('/')) { throw 'Noncanonical volume subpath.' }
    $keys+=@{Volume=$item.Volume;Subpath=$sub}
  }
  if($keys[0].Volume -ceq $keys[1].Volume) {
    $a=$keys[0].Subpath; $b=$keys[1].Subpath
    if(!$a -or !$b -or $a -ceq $b -or $a.StartsWith($b+'/',[StringComparison]::Ordinal) -or $b.StartsWith($a+'/',[StringComparison]::Ordinal)) { throw 'Shared or overlapping physical directory.' }
  }
}
if(!$SelfTest) {
  $mounts=@(); $ids=@()
  foreach($container in @($LeftContainer,$RightContainer)) {
    if($container -cnotmatch '^supabase[-_][a-z0-9_-]+$'){throw 'Two explicit Supabase container names required.'}
    $info=(docker inspect $container|ConvertFrom-Json)[0]
    if($LASTEXITCODE -ne 0 -or $info.State.Status -ne 'running'){throw 'Running database required for read-only system ID query.'}
    $mount=@($info.HostConfig.Mounts|Where-Object Target -eq '/var/lib/postgresql/data')
    if($mount.Count -ne 1 -or $mount[0].Type -ne 'volume'){throw 'Unsupported or ambiguous PGDATA mount.'}
    $sub=''
    if($mount[0].VolumeOptions -and $mount[0].VolumeOptions.PSObject.Properties['Subpath']){$sub=$mount[0].VolumeOptions.Subpath}
    $mounts+=@{Volume=$mount[0].Source;Subpath=$sub;Target=$mount[0].Target}
    $id=docker exec $container psql -U postgres -d postgres -X -At -v ON_ERROR_STOP=1 -c 'select system_identifier from pg_control_system();'
    if($LASTEXITCODE -ne 0 -or $id -cnotmatch '^\d+$'){throw 'System identifier unavailable.'}; $ids+=$id
  }
  Assert-PhysicalPgIsolation $mounts[0] $mounts[1]
  if($ids[0] -ceq $ids[1]){throw 'Same PostgreSQL system identifier.'}
  'PASS: disjoint physical mounts and different PostgreSQL system identifiers (read-only).'
  return
}
$passed=0
foreach($case in @(
  @('v','a/data','v','b/data',$true),
  @('v','a/data','v','a/data',$false),
  @('v','','v','b/data',$false),
  @('v','a','v','a/data',$false),
  @('v','a/../b','v','b/data',$false),
  @('v','/a','v','b',$false),
  @('v','','w','',$true),
  @('v','a/data','v','a/data2',$true)
)) {
  $left=@{Volume=$case[0];Subpath=$case[1];Target='/var/lib/postgresql/data'}
  $right=@{Volume=$case[2];Subpath=$case[3];Target='/var/lib/postgresql/data'}
  $accepted=$true
  try { Assert-PhysicalPgIsolation $left $right } catch { $accepted=$false }
  if($accepted -ne $case[4]) { throw 'Isolation self-test failed.' }; $passed++
}
"PASS: $passed physical mount isolation checks."
