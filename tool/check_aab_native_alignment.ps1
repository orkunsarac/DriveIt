param([Parameter(Mandatory)][string]$Bundle)
# Read-only ELF check. APK ZIP alignment and 16 KB device testing remain separate.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive=[IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Bundle))
$checked=0;$failed=0
try {
 foreach($entry in $archive.Entries){
  if($entry.FullName -notmatch '/lib/[^/]+/[^/]+\.so$'){continue}
  $stream=$entry.Open();$buffer=[IO.MemoryStream]::new()
  try{$stream.CopyTo($buffer);$data=$buffer.ToArray()}finally{$stream.Dispose();$buffer.Dispose()}
  if($data.Length -lt 64 -or $data[0] -ne 127 -or [Text.Encoding]::ASCII.GetString($data,1,3) -cne 'ELF'){throw 'Malformed native library'}
  if($data[4] -ne 2){continue}
  if($data[5] -ne 1){throw 'Unsupported ELF byte order'}
  $offset=[BitConverter]::ToUInt64($data,32);$size=[BitConverter]::ToUInt16($data,54);$count=[BitConverter]::ToUInt16($data,56)
  if($size -lt 56 -or $offset+$size*$count -gt $data.Length){throw 'Malformed ELF program header'}
  $loads=0;$valid=$true
  for($i=0;$i -lt $count;$i++){
   $position=[int]($offset+$size*$i)
   if([BitConverter]::ToUInt32($data,$position) -ne 1){continue}
   $loads++
   $fileOffset=[BitConverter]::ToUInt64($data,$position+8)
   $virtual=[BitConverter]::ToUInt64($data,$position+16)
   $align=[BitConverter]::ToUInt64($data,$position+48)
   if($align -lt 16384 -or $fileOffset%16384 -ne $virtual%16384){$valid=$false}
  }
  $checked++
  if(!$valid -or $loads -eq 0){$failed++;Write-Output ('FAIL: '+$entry.FullName)}
 }
} finally {$archive.Dispose()}
if($checked -eq 0){throw 'No 64-bit native libraries found'}
Write-Output "64-bit ELF libraries: $checked; failed: $failed"
if($failed){throw 'Native ELF 16 KB alignment failed'}
