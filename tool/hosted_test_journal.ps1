param([Parameter(Mandatory)][string]$RunId,[switch]$Read)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($RunId -cnotmatch '^[0-9a-f-]{36}$'){throw 'Invalid run identifier'}
$folder=Join-Path $env:USERPROFILE '.driveit-secrets/hosted-acceptance'
$path=Join-Path $folder ($RunId+'.clixml')
if($Read){
 if(!(Test-Path -LiteralPath $path)){Write-Output 'null';return}
 $secure=Import-Clixml -LiteralPath $path
 $ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
 try{[Console]::Out.Write([Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr))}finally{[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr);$secure.Dispose()}
 return
}
$text=[Console]::In.ReadToEnd()
$record=$text|ConvertFrom-Json
if($record.runId -cne $RunId){throw 'Journal identity mismatch'}
if(!(Test-Path -LiteralPath $folder)){New-Item -ItemType Directory -Path $folder|Out-Null}
$secure=ConvertTo-SecureString $text -AsPlainText -Force
$temporary=Join-Path $folder ($RunId+'.'+[guid]::NewGuid().ToString('N')+'.pending')
try{$secure|Export-Clixml -LiteralPath $temporary;Move-Item -LiteralPath $temporary -Destination $path -Force}finally{$secure.Dispose();$text=$null}
