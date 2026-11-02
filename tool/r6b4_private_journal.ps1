param([switch]$Read)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security
$root = Join-Path $env:LOCALAPPDATA 'DriveIt\Recovery\R6B3-DEV-20261103-013444-8089709d'
if (!(Test-Path -LiteralPath $root)) { throw 'Protected recovery directory missing.' }
$acl = Get-Acl -LiteralPath $root
if (!$acl.AreAccessRulesProtected -or $acl.Access.Count -ne 2) { throw 'Recovery directory ACL is not restricted.' }
$allowed = @([Security.Principal.WindowsIdentity]::GetCurrent().User.Value,'S-1-5-18')
foreach ($rule in $acl.Access) {
  $sid = $rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value
  if ($sid -notin $allowed -or $rule.AccessControlType -ne 'Allow') { throw 'Unexpected recovery directory principal.' }
}
$path = Join-Path $root 'r6b4-http-journal.dpapi'
if ($Read) {
  $plain = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($path),$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
  Write-Output ([Text.Encoding]::UTF8.GetString($plain))
} else {
  $content = [Console]::In.ReadToEnd()
  if (!$content) { throw 'Empty journal is forbidden.' }
  $encrypted = [Security.Cryptography.ProtectedData]::Protect([Text.Encoding]::UTF8.GetBytes($content),$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
  [IO.File]::WriteAllBytes($path,$encrypted)
}
