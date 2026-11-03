param([Parameter(Mandatory)][string]$Root,[string]$Container='driveit-r6b5-restore-20261103-b',[switch]$Resume)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.IO.Compression.FileSystem

$base = Join-Path $env:LOCALAPPDATA 'DriveIt\Recovery'
$baseResolved = (Resolve-Path -LiteralPath $base).Path.TrimEnd('\')
$rootResolved = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')
if (!$rootResolved.StartsWith($baseResolved + '\',[StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $rootResolved) -notmatch '^R6B5-DEV-[0-9]{8}-[0-9]{6}-[a-f0-9]{8}$') { throw 'Invalid protected backup root.' }

$manifest = Get-Content -LiteralPath (Join-Path $rootResolved 'manifest.json') -Raw | ConvertFrom-Json
$artifact = Join-Path $rootResolved 'driveit-dev-r6b5.zip.dpapi'
$cipher = [IO.File]::ReadAllBytes($artifact)
$cipherHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($cipher)).ToLowerInvariant()
if ($manifest.project_ref -cne 'viqngnjfgknpxtoapzcg' -or $manifest.encryption -cne 'Windows DPAPI CurrentUser' -or $manifest.sha256 -cne $cipherHash) { throw 'Protected backup identity or hash mismatch.' }

$work = Join-Path $rootResolved 'restore-work'
if (!(Test-Path -LiteralPath $work)) { New-Item -ItemType Directory -Path $work | Out-Null }
$workItem = Get-Item -LiteralPath $work
if (!$workItem.PSIsContainer -or ($workItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Restore work path is not a safe directory.' }
$allowed = @([Security.Principal.WindowsIdentity]::GetCurrent().User.Value,'S-1-5-18')
$workAcl = Get-Acl -LiteralPath $work
if ($workAcl.Access.Count -ne 2) { throw 'Restore work ACL has an unexpected principal count.' }
foreach ($rule in $workAcl.Access) { if ($rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value -notin $allowed -or $rule.AccessControlType -ne 'Allow') { throw 'Restore work ACL includes an unexpected principal.' } }

$plain = [Security.Cryptography.ProtectedData]::Unprotect($cipher,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
$memory = [IO.MemoryStream]::new($plain)
$archive = [IO.Compression.ZipArchive]::new($memory,[IO.Compression.ZipArchiveMode]::Read)
try {
  $payloadEntry = @($archive.Entries | Where-Object FullName -CEQ 'payload_manifest.json')
  if ($payloadEntry.Count -ne 1) { throw 'Encrypted payload manifest missing.' }
  $reader = [IO.StreamReader]::new($payloadEntry[0].Open())
  try { $payloadManifest = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
  $written = 0
  foreach ($entry in $archive.Entries) {
    if ($entry.FullName -ceq 'payload_manifest.json') { continue }
    if ($entry.FullName.StartsWith('/') -or $entry.FullName -match '(^|/)\.\.(/|$)') { throw 'Unsafe archive path.' }
    $target = Join-Path $work ($entry.FullName.Replace('/',[string][char]92))
    $parent = Split-Path -Parent $target
    if (!(Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $expected = @($payloadManifest.files | Where-Object path -CEQ $entry.FullName)
    if ($expected.Count -ne 1) { throw 'Payload manifest path missing or duplicated.' }
    if (!(Test-Path -LiteralPath $target)) {
      $source = $entry.Open(); $destination = [IO.File]::Create($target); $sha = [Security.Cryptography.SHA256]::Create()
      try { $source.CopyTo($destination); $destination.Flush(); $destination.Position = 0; $hash = [Convert]::ToHexString($sha.ComputeHash($destination)).ToLowerInvariant() } finally { $source.Dispose(); $destination.Dispose(); $sha.Dispose() }
    } else { $hash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant() }
    if ((Get-Item -LiteralPath $target).Length -ne [long]$expected[0].bytes -or $hash -cne $expected[0].sha256) { throw 'Restored payload member hash mismatch.' }
    $written++
  }
  if ($written -ne [int]$manifest.payload_files) { throw 'Restored payload member count mismatch.' }
} finally { $archive.Dispose(); $memory.Dispose(); [Array]::Clear($plain,0,$plain.Length) }

$container = $Container
$existing = @(& docker ps -a --filter ("name=^/$container$") --format '{{.Names}}' 2>$null)
if ($LASTEXITCODE -ne 0) { throw 'Docker inventory failed.' }
if ($existing.Count -and !$Resume) { throw 'Dedicated restore container already exists; no container was changed.' }
if (!$existing.Count -and $Resume) { throw 'Resume requested but the dedicated restore container is absent.' }
$image = 'public.ecr.aws/supabase/postgres:17.11.0.004'
$images = @(& docker images --format '{{.Repository}}:{{.Tag}}' 2>$null)
if ($LASTEXITCODE -ne 0 -or $images -notcontains $image) { throw 'Pinned Supabase PostgreSQL image is unavailable locally.' }
if ($existing.Count) {
  $ErrorActionPreference = 'Continue'; $identity=@(& docker inspect --format '{{index .Config.Labels "driveit.test"}}|{{.State.Status}}|{{.Config.Image}}' $container 2>$null); $identityExit=$LASTEXITCODE; $ErrorActionPreference='Stop'
  if ($identityExit -ne 0 -or ($identity -join '').Trim() -cne ('r6b5-restore|running|' + $image)) { throw 'Resume target is not the owned isolated restore container.' }
} else {
  $password = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
  $ErrorActionPreference = 'Continue'
  $created = @(& docker run --detach --name $container --network none --label driveit.test=r6b5-restore --env ("POSTGRES_PASSWORD=" + $password) $image 2>$null)
  $createExit = $LASTEXITCODE
  $ErrorActionPreference = 'Stop'
  $password = $null
  if ($createExit -ne 0) { throw 'Isolated offline restore container creation failed.' }
}
try {
  $ready = $false
  for ($i=0; $i -lt 90; $i++) {
    $ErrorActionPreference = 'Continue'
    $health = @(& docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' $container 2>$null)
    $healthExit = $LASTEXITCODE
    $probe = @(& docker exec --user postgres $container psql -U supabase_admin -d postgres -Atqc 'SELECT 1' 2>$null)
    $probeExit = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($healthExit -eq 0 -and ($health -join '').Trim() -ceq 'healthy' -and $probeExit -eq 0 -and ($probe -join '').Trim() -ceq '1') { $ready = $true; break }
    Start-Sleep -Seconds 2
  }
  if (!$ready) { throw 'Isolated PostgreSQL did not become ready.' }

  function Docker-Copy([string]$source,[string]$destination) {
    $ErrorActionPreference = 'Continue'; $output=@(& docker cp $source ($container + ':' + $destination) 2>&1); $rc=$LASTEXITCODE; $ErrorActionPreference='Stop'
    if ($rc -ne 0) { throw 'Unable to transfer verified SQL into the isolated container.' }
  }
  function Psql-File([string]$database,[string]$containerFile) {
    $ErrorActionPreference = 'Continue'; $output=@(& docker exec --user postgres $container psql -X --set=VERBOSITY=verbose -v ON_ERROR_STOP=1 -U supabase_admin -d $database -f $containerFile 2>&1); $rc=$LASTEXITCODE; $ErrorActionPreference='Stop'
    if ($rc -ne 0) {
      $codes=@(); foreach ($line in $output) { if ($line.ToString() -match '(?i)(?:ERROR|FATAL):\s*([0-9A-Z]{5}):') { $codes += $Matches[1] } }
      throw "PostgreSQL restore step failed in the isolated $database database at $(Split-Path -Leaf $containerFile); SQLSTATE=$($codes -join ',')."
    }
  }

  $sourceFile = Join-Path $work 'inventory\catalog.json'
  $sourceCatalog = Get-Content -LiteralPath $sourceFile -Raw | ConvertFrom-Json
  $rolesFile = Join-Path $work 'database\roles.sql'
  $schemaFile = Join-Path $work 'database\full-schema.sql'
  $dataFile = Join-Path $work 'database\full-data.sql'
  foreach ($file in @($rolesFile,$schemaFile,$dataFile)) { if (!(Test-Path -LiteralPath $file) -or (Get-Item -LiteralPath $file).Length -eq 0) { throw 'Required database dump missing.' } }
  if (!$Resume) {
  Docker-Copy $rolesFile '/tmp/r6b5-roles.sql'
  function Restore-RoleSettings([string]$file) {
    $created = 0
    for ($attempt=0; $attempt -lt 16; $attempt++) {
      $ErrorActionPreference='Continue'; $roleOutput=@(& docker exec --user postgres $container psql -X --set=VERBOSITY=verbose -v ON_ERROR_STOP=1 -U supabase_admin -d postgres -f /tmp/r6b5-roles.sql 2>&1); $roleExit=$LASTEXITCODE; $ErrorActionPreference='Stop'
      if ($roleExit -eq 0) { return $created }
      $missingRole=$null
      foreach ($line in $roleOutput) { if ($line.ToString() -match 'role "([A-Za-z_][A-Za-z0-9_$]*)" does not exist') { $missingRole=$Matches[1]; break } }
      if (!$missingRole) { throw 'Role dump failed with a non-recoverable isolated PostgreSQL error.' }
      $ErrorActionPreference='Continue'; $exists=@(& docker exec --user postgres $container psql -X -A -t -U supabase_admin -d postgres -c ("SELECT count(*) FROM pg_roles WHERE rolname='" + $missingRole.Replace("'","''") + "'") 2>&1); $existsExit=$LASTEXITCODE; $ErrorActionPreference='Stop'
      if ($existsExit -ne 0 -or ($exists -join '').Trim() -ne '0') { throw 'Missing role could not be safely identified for isolated restore.' }
      $createRole='CREATE ROLE "' + $missingRole.Replace('"','""') + '" NOLOGIN'
      $ErrorActionPreference='Continue'; $createOutput=@(& docker exec --user postgres $container psql -X -v ON_ERROR_STOP=1 -U supabase_admin -d postgres -c $createRole 2>&1); $createExit=$LASTEXITCODE; $ErrorActionPreference='Stop'
      if ($createExit -ne 0) { throw 'Missing role creation failed in isolated restore.' }
      $created++
    }
    throw 'Role dump referenced too many missing roles; restore stopped.'
  }
  $roleCount = Restore-RoleSettings $rolesFile
  $ErrorActionPreference = 'Continue'; $createDbOutput=@(& docker exec --user postgres $container psql -X -v ON_ERROR_STOP=1 -U supabase_admin -d postgres -c 'CREATE DATABASE driveit_r6b5_restore TEMPLATE template0 OWNER postgres' 2>&1); $createDbExit=$LASTEXITCODE; $ErrorActionPreference='Stop'
  if ($createDbExit -ne 0) { throw 'Isolated restore database creation failed.' }
  $quoteIdent = { param([string]$value) '"' + $value.Replace('"','""') + '"' }
  $extensionSql = [System.Collections.Generic.List[string]]::new()
  foreach ($schemaName in @('extensions','vault')) { $extensionSql.Add('CREATE SCHEMA IF NOT EXISTS ' + (& $quoteIdent $schemaName) + ' AUTHORIZATION postgres;') }
  foreach ($extension in $sourceCatalog.extensions) {
    if ($extension.schema -ceq 'pg_catalog' -and $extension.name -ceq 'plpgsql') { continue }
    $availabilityQuery = "SELECT count(*) FROM pg_available_extensions WHERE name='" + $extension.name.Replace("'","''") + "' AND default_version='" + $extension.version.Replace("'","''") + "'"
    $ErrorActionPreference='Continue'; $available=@(& docker exec --user postgres $container psql -X -A -t -U supabase_admin -d driveit_r6b5_restore -c $availabilityQuery 2>&1); $availableExit=$LASTEXITCODE; $ErrorActionPreference='Stop'
    if ($availableExit -ne 0 -or ($available -join '').Trim() -ne '1') { throw ('Required extension version unavailable in isolated image: ' + $extension.name) }
    $extensionSql.Add('CREATE EXTENSION IF NOT EXISTS ' + (& $quoteIdent $extension.name) + ' WITH SCHEMA ' + (& $quoteIdent $extension.schema) + ' VERSION ' + ("'" + $extension.version.Replace("'","''") + "'") + ';')
  }
  $extensionsRestore = Join-Path $work 'database\extensions-restore.sql'
  [IO.File]::WriteAllLines($extensionsRestore,$extensionSql,[Text.UTF8Encoding]::new($false))
  Docker-Copy $extensionsRestore '/tmp/r6b5-extensions.sql'
  Psql-File 'driveit_r6b5_restore' '/tmp/r6b5-extensions.sql'
  Docker-Copy $schemaFile '/tmp/r6b5-schema.sql'
  Psql-File 'driveit_r6b5_restore' '/tmp/r6b5-schema.sql'
  Docker-Copy $dataFile '/tmp/r6b5-data.sql'
  Psql-File 'driveit_r6b5_restore' '/tmp/r6b5-data.sql'
  } else {
    $ErrorActionPreference='Continue'; $restoreDb=@(& docker exec --user postgres $container psql -X -A -t -U supabase_admin -d postgres -c "SELECT count(*) FROM pg_database WHERE datname='driveit_r6b5_restore'" 2>&1); $restoreDbExit=$LASTEXITCODE; $ErrorActionPreference='Stop'
    if ($restoreDbExit -ne 0 -or ($restoreDb -join '').Trim() -ne '1') { throw 'Resume target does not contain the isolated restore database.' }
    $quoteIdent = { param([string]$value) '"' + $value.Replace('"','""') + '"' }
  }

  $triggerSql = [System.Collections.Generic.List[string]]::new()
  # DEV's final `postgres` role is not a superuser, but creating PostgreSQL
  # event triggers requires a superuser-owned handler. Recreate the source's
  # creation-time privilege inside this offline test DB only, transactionally,
  # and restore the captured NOSUPERUSER state before commit.
  $triggerSql.Add('BEGIN;')
  $triggerSql.Add('ALTER ROLE postgres WITH SUPERUSER;')
  $triggerSql.Add('DO $driveit$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = ''extensions'') THEN CREATE SCHEMA extensions; END IF; END $driveit$;')
  $triggerQuery = "SELECT coalesce(json_agg(jsonb_build_object('name',e.evtname,'event',e.evtevent,'enabled',e.evtenabled::text,'tags',e.evttags,'owner',pg_get_userbyid(e.evtowner),'function_schema',n.nspname,'function_name',p.proname) ORDER BY e.evtname),'[]'::json)::text FROM pg_event_trigger e JOIN pg_proc p ON p.oid=e.evtfoid JOIN pg_namespace n ON n.oid=p.pronamespace"
  $triggerQueryFile = Join-Path $work 'event-trigger-inventory.sql'
  [IO.File]::WriteAllText($triggerQueryFile,$triggerQuery,[Text.UTF8Encoding]::new($false))
  Docker-Copy $triggerQueryFile '/tmp/r6b5-event-inventory.sql'
  $ErrorActionPreference = 'Continue'; $presentText = @(& docker exec --user postgres $container psql -X -A -t -U supabase_admin -d driveit_r6b5_restore -f /tmp/r6b5-event-inventory.sql 2>&1); $presentExit=$LASTEXITCODE; $ErrorActionPreference='Stop'
  if ($presentExit -ne 0) { throw 'Event-trigger inventory failed in isolated restore.' }
  $present = @(($presentText -join "`n" | ConvertFrom-Json))
  foreach ($expected in $sourceCatalog.event_triggers) {
    $found = @($present | Where-Object name -CEQ $expected.name)
    if (!$found.Count) {
      if ($expected.event -notin @('ddl_command_end','sql_drop')) { throw 'Unrecognized event-trigger type in backup.' }
      $tags = @($expected.tags | Where-Object { $null -ne $_ -and $_.ToString().Length -gt 0 })
      $when = if ($tags.Count) { ' WHEN TAG IN (' + (($tags | ForEach-Object { "'" + $_.Replace("'","''") + "'" }) -join ',') + ')' } else { '' }
      $triggerSql.Add('CREATE EVENT TRIGGER ' + (& $quoteIdent $expected.name) + ' ON ' + $expected.event + $when + ' EXECUTE FUNCTION ' + (& $quoteIdent $expected.function_schema) + '.' + (& $quoteIdent $expected.function_name) + '();')
    } else {
      if ($found.Count -ne 1 -or $found[0].event -cne $expected.event -or $found[0].function_schema -cne $expected.function_schema -or $found[0].function_name -cne $expected.function_name -or (($found[0].tags -join '|') -cne (@($expected.tags) -join '|'))) { throw ('Existing event-trigger definition differs: ' + $expected.name) }
    }
    $triggerSql.Add('ALTER EVENT TRIGGER ' + (& $quoteIdent $expected.name) + ' OWNER TO ' + (& $quoteIdent $expected.owner) + ';')
    switch ($expected.enabled) {
      'O' { $triggerSql.Add('ALTER EVENT TRIGGER ' + (& $quoteIdent $expected.name) + ' ENABLE;') }
      'D' { $triggerSql.Add('ALTER EVENT TRIGGER ' + (& $quoteIdent $expected.name) + ' DISABLE;') }
      'R' { $triggerSql.Add('ALTER EVENT TRIGGER ' + (& $quoteIdent $expected.name) + ' ENABLE REPLICA;') }
      'A' { $triggerSql.Add('ALTER EVENT TRIGGER ' + (& $quoteIdent $expected.name) + ' ENABLE ALWAYS;') }
      default { throw 'Unknown event-trigger enabled state.' }
    }
  }
  $triggerSql.Add('ALTER ROLE postgres WITH NOSUPERUSER;')
  $triggerSql.Add('COMMIT;')
  $triggerRestore = Join-Path $work 'event-triggers-restore.sql'
  [IO.File]::WriteAllLines($triggerRestore,$triggerSql,[Text.UTF8Encoding]::new($false))
  Docker-Copy $triggerRestore '/tmp/r6b5-event-restore.sql'
  Psql-File 'driveit_r6b5_restore' '/tmp/r6b5-event-restore.sql'

  $extensionSchema = $sourceCatalog.extensions_schema
  $aclSql = [System.Collections.Generic.List[string]]::new()
  $aclSql.Add('ALTER SCHEMA extensions OWNER TO ' + (& $quoteIdent $extensionSchema.owner) + ';')
  $aclSql.Add('REVOKE ALL PRIVILEGES ON SCHEMA extensions FROM PUBLIC;')
  $ErrorActionPreference = 'Continue'; $roleText = @(& docker exec --user postgres $container psql -X -A -t -U supabase_admin -d driveit_r6b5_restore -c 'SELECT rolname FROM pg_roles' 2>&1); $roleExit=$LASTEXITCODE; $ErrorActionPreference='Stop'
  if ($roleExit -ne 0) { throw 'Role inventory failed in isolated restore.' }
  foreach ($role in $roleText) { if ($role.Trim() -and $role.Trim() -cne $extensionSchema.owner) { $aclSql.Add('REVOKE ALL PRIVILEGES ON SCHEMA extensions FROM ' + (& $quoteIdent $role.Trim()) + ';') } }
  foreach ($grant in $extensionSchema.acl) {
    $equal = $grant.IndexOf('='); $slash = $grant.IndexOf('/')
    if ($equal -lt 0 -or $slash -le $equal) { throw 'Unsupported extensions schema ACL format.' }
    $grantee = $grant.Substring(0,$equal); $privileges = $grant.Substring($equal+1,$slash-$equal-1)
    if ($privileges.Contains('*')) { throw 'Grant-option ACL requires manual restore review.' }
    $names = [System.Collections.Generic.List[string]]::new()
    if ($privileges.Contains('U')) { $names.Add('USAGE') }; if ($privileges.Contains('C')) { $names.Add('CREATE') }
    if ($names.Count -ne $privileges.Length) { throw 'Unsupported extensions schema privilege.' }
    $targetRole = if ($grantee) { & $quoteIdent $grantee } else { 'PUBLIC' }
    $aclSql.Add('GRANT ' + ($names -join ', ') + ' ON SCHEMA extensions TO ' + $targetRole + ';')
  }
  $aclRestore = Join-Path $work 'extensions-acl-restore.sql'
  [IO.File]::WriteAllLines($aclRestore,$aclSql,[Text.UTF8Encoding]::new($false))
  Docker-Copy $aclRestore '/tmp/r6b5-extensions-acl.sql'
  Psql-File 'driveit_r6b5_restore' '/tmp/r6b5-extensions-acl.sql'

  $catalogFile = Join-Path (Split-Path -Parent $PSScriptRoot) 'tool\r6b5_catalog.sql'
  Docker-Copy $catalogFile '/tmp/r6b5-catalog.sql'
  $ErrorActionPreference='Continue'; $beforeCatalogOutput=@(& docker exec --user postgres $container psql -X -A -t -U supabase_admin -d driveit_r6b5_restore -f /tmp/r6b5-catalog.sql 2>&1); $beforeCatalogExit=$LASTEXITCODE; $ErrorActionPreference='Stop'
  if ($beforeCatalogExit -ne 0) { throw 'Pre-reconciliation catalog query failed.' }
  $beforeCatalog=($beforeCatalogOutput -join "`n").Trim()|ConvertFrom-Json
  $sourceDefaults=@{}; foreach($entry in $sourceCatalog.default_acl){$sourceDefaults[('{0}|{1}|{2}' -f $entry.owner,$entry.schema,$entry.kind)]=$entry}
  $targetDefaults=@{}; foreach($entry in $beforeCatalog.default_acl){$targetDefaults[('{0}|{1}|{2}' -f $entry.owner,$entry.schema,$entry.kind)]=$entry}
  $defaultKeys=@($sourceDefaults.Keys)+@($targetDefaults.Keys)|Sort-Object -Unique
  $defaultSql=[System.Collections.Generic.List[string]]::new();$defaultSql.Add('BEGIN;');$defaultChanges=0
  function Default-Objects([string]$kind){switch -CaseSensitive ($kind){'r'{'TABLES'}'S'{'SEQUENCES'}'f'{'FUNCTIONS'}'T'{'TYPES'}'n'{'SCHEMAS'}default{throw 'Unsupported default privilege object kind.'}}}
  function Default-Privilege([string]$kind,[char]$code){switch -CaseSensitive ($kind){'r'{switch -CaseSensitive ($code){'a'{'INSERT'}'r'{'SELECT'}'w'{'UPDATE'}'d'{'DELETE'}'D'{'TRUNCATE'}'x'{'REFERENCES'}'t'{'TRIGGER'}'m'{'MAINTAIN'}default{throw 'Unsupported table default privilege.'}}}'S'{switch -CaseSensitive ($code){'r'{'SELECT'}'w'{'UPDATE'}'U'{'USAGE'}default{throw 'Unsupported sequence default privilege.'}}}'f'{if($code -cne 'X'){throw 'Unsupported function default privilege.'};'EXECUTE'}'T'{if($code -cne 'U'){throw 'Unsupported type default privilege.'};'USAGE'}'n'{switch -CaseSensitive ($code){'U'{'USAGE'}'C'{'CREATE'}default{throw 'Unsupported schema default privilege.'}}}default{throw 'Unsupported default privilege object kind.'}}}
  foreach($key in $defaultKeys){
    $desired=$sourceDefaults[$key];$current=$targetDefaults[$key]
    $desiredAcl=if($desired){@($desired.acl|Sort-Object)-join ','}else{''};$currentAcl=if($current){@($current.acl|Sort-Object)-join ','}else{''}
    if($desiredAcl -ceq $currentAcl){continue}
    $row=if($desired){$desired}else{$current};$ownerSql=& $quoteIdent $row.owner;$scope=if($row.schema -ceq 'global'){' '}else{' IN SCHEMA '+(& $quoteIdent $row.schema)+' '};$objectType=Default-Objects $row.kind;$prefix='ALTER DEFAULT PRIVILEGES FOR ROLE '+$ownerSql+$scope
    $allAcl=@();if($current){$allAcl+=@($current.acl)};if($desired){$allAcl+=@($desired.acl)}
    foreach($aclItem in $allAcl){$aclMatch=[regex]::Match($aclItem,'^(?<grantee>[^=]*)=(?<privileges>[^/]*)/(?<grantor>.+)$');if(!$aclMatch.Success){throw 'Unsupported default ACL item format.'};$granteeName=$aclMatch.Groups['grantee'].Value;$grantor=$aclMatch.Groups['grantor'].Value;$granteeSql=if($granteeName){& $quoteIdent $granteeName}else{'PUBLIC'}
      $defaultSql.Add('SET ROLE '+(& $quoteIdent $grantor)+';');$defaultSql.Add($prefix+'REVOKE ALL ON '+$objectType+' FROM '+$granteeSql+';');$defaultSql.Add('RESET ROLE;')
    }
    if($desired){foreach($aclItem in $desired.acl){$aclMatch=[regex]::Match($aclItem,'^(?<grantee>[^=]*)=(?<privileges>[^/]*)/(?<grantor>.+)$');$granteeName=$aclMatch.Groups['grantee'].Value;$grantor=$aclMatch.Groups['grantor'].Value;$granteeSql=if($granteeName){& $quoteIdent $granteeName}else{'PUBLIC'};$privileges=$aclMatch.Groups['privileges'].Value
        $defaultSql.Add('SET ROLE '+(& $quoteIdent $grantor)+';')
        for($i=0;$i -lt $privileges.Length;$i++){if($privileges[$i] -ceq '*'){continue};$grantOption=($i+1 -lt $privileges.Length -and $privileges[$i+1] -ceq '*');if($grantOption){$i++};$privilege=Default-Privilege $row.kind $privileges[$i - [int]$grantOption];$grant=$prefix+'GRANT '+$privilege+' ON '+$objectType+' TO '+$granteeSql+$(if($grantOption){' WITH GRANT OPTION'}else{''})+';';$defaultSql.Add($grant)}
        $defaultSql.Add('RESET ROLE;')
      }
    }
    $defaultChanges++
  }
  if($defaultChanges){$defaultSql.Add('COMMIT;');$defaultRestore=Join-Path $work 'database\default-acl-restore.sql';[IO.File]::WriteAllLines($defaultRestore,$defaultSql,[Text.UTF8Encoding]::new($false));Docker-Copy $defaultRestore '/tmp/r6b5-default-acl.sql';Psql-File 'driveit_r6b5_restore' '/tmp/r6b5-default-acl.sql'}
  $ErrorActionPreference = 'Continue'; $catalogOutput = @(& docker exec --user postgres $container psql -X -A -t -U supabase_admin -d driveit_r6b5_restore -f /tmp/r6b5-catalog.sql 2>&1); $catalogExit=$LASTEXITCODE; $ErrorActionPreference='Stop'
  if ($catalogExit -ne 0) { throw 'Catalog comparison query failed in isolated restore.' }
  $restored = ($catalogOutput -join "`n").Trim() | ConvertFrom-Json
  $repoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
  $cli=Join-Path $repoRoot 'tmp\supabase-cli-npm-cache\_npx\6f1b058a4d9555af\node_modules\.bin\supabase.cmd'
  $devWork=Join-Path $repoRoot 'supabase\phase8-dev'
  $env:SUPABASE_TELEMETRY_DISABLED='1'
  $ErrorActionPreference='Continue'; $remoteOutput=@(& $cli db query --linked --project-ref viqngnjfgknpxtoapzcg --workdir $devWork --file $catalogFile --output-format json 2>&1); $remoteExit=$LASTEXITCODE; $ErrorActionPreference='Stop'
  if ($remoteExit -ne 0) { throw 'Read-only DEV catalog recheck failed; raw CLI output suppressed.' }
  $remoteText=($remoteOutput|ForEach-Object{$_.ToString()})-join "`n";$jsonStart=$remoteText.IndexOf('{');$jsonEnd=$remoteText.LastIndexOf('}')
  if ($jsonStart -lt 0 -or $jsonEnd -lt $jsonStart) { throw 'Read-only DEV catalog response was not valid JSON.' }
  $remoteCatalog=($remoteText.Substring($jsonStart,$jsonEnd-$jsonStart+1)|ConvertFrom-Json).rows[0].catalog
  function Normalize-PolicyExpression([string]$expression){
    # pg_policies deparses relation/function names according to search_path.
    # The original export used the service default path, while the stable
    # catalog query pins pg_catalog. Qualify only the four exact public objects
    # proven present in DEV; leave every other token byte-for-byte intact.
    foreach($name in @('world_validated_roads','phase8_group_topic_authorized','phase8_can_access_staging_object')){
      $expression=[regex]::Replace($expression,'(?<![A-Za-z0-9_.])'+[regex]::Escape($name)+'\b','public.'+$name)
    }
    return $expression
  }
  function Catalog-Key($x,[string]$kind){switch($kind){
    'schemaacl'{return @($x.owner,(@($x.acl|Sort-Object)-join ','))-join '|'}
    'table'{return @($x.schema,$x.table,$x.owner,$x.rls,$x.force_rls,(@($x.acl|Sort-Object)-join ','))-join '|'}
    'policy'{return @($x.schema,$x.table,$x.name,$x.mode,(@($x.roles|Sort-Object)-join ','),$x.command,(Normalize-PolicyExpression ([string]$x.'using')),(Normalize-PolicyExpression ([string]$x.check)))-join '|'}
    'trigger'{return @($x.schema,$x.table,$x.name,$x.enabled,$x.definition)-join '|'}
    'function'{$signature=$x.signature;if(!$signature.StartsWith($x.schema+'.')){$signature=$x.schema+'.'+$signature};return @($x.schema,$signature,$x.owner,$x.definer,(@($x.config|Sort-Object)-join ','),(@($x.acl|Sort-Object)-join ','),$x.definition_hash)-join '|'}
    'event'{return @($x.name,$x.event,$x.enabled,(@($x.tags|Sort-Object)-join ','),$x.owner,$x.function_schema,$x.function_name,$x.function_owner,(@($x.function_acl|Sort-Object)-join ','),$x.definition)-join '|'}
    'defacl'{return @($x.owner,$x.schema,$x.kind,(@($x.acl|Sort-Object)-join ','))-join '|'}
    'extension'{return @($x.name,$x.version,$x.schema,$x.schema_owner)-join '|'}
  }}
  function Catalog-Array-Equal($left,$right,[string]$kind){$leftKeys=@($left|ForEach-Object{Catalog-Key $_ $kind}|Sort-Object);$rightKeys=@($right|ForEach-Object{Catalog-Key $_ $kind}|Sort-Object);return (@(Compare-Object $leftKeys $rightKeys).Count -eq 0)}
  function Catalog-Data-Equal($left,$right){foreach($field in @('auth_users','auth_hash','migrations','migration_hash','storage_buckets','storage_objects','storage_hash','manifest_rows','manifest_hash')){if([string]$left.$field -cne [string]$right.$field){return $false}};return $true}
  $remoteRestoreDifferences=[System.Collections.Generic.List[string]]::new()
  foreach($entry in @(@('extensions','extension'),@('event_triggers','event'),@('tables','table'),@('policies','policy'),@('triggers','trigger'),@('functions','function'),@('default_acl','defacl'))){if(!(Catalog-Array-Equal $remoteCatalog.($entry[0]) $restored.($entry[0]) $entry[1])){$remoteRestoreDifferences.Add($entry[0])}}
  $remoteExtensionAcl=Catalog-Key $remoteCatalog.extensions_schema 'schemaacl';$restoreExtensionAcl=Catalog-Key $restored.extensions_schema 'schemaacl';if($remoteExtensionAcl -cne $restoreExtensionAcl){$remoteRestoreDifferences.Add('extensions_schema')}
  if(!(Catalog-Data-Equal $remoteCatalog.data $restored.data)){$remoteRestoreDifferences.Add('data')}
  $backupDifferences=[System.Collections.Generic.List[string]]::new()
  foreach($entry in @(@('extensions','extension'),@('event_triggers','event'),@('tables','table'),@('policies','policy'),@('default_acl','defacl'))){if(!(Catalog-Array-Equal $sourceCatalog.($entry[0]) $remoteCatalog.($entry[0]) $entry[1])){$backupDifferences.Add($entry[0])}}
  $backupExtensionAcl=Catalog-Key $sourceCatalog.extensions_schema 'schemaacl';if($backupExtensionAcl -cne $remoteExtensionAcl){$backupDifferences.Add('extensions_schema')}
  if(!(Catalog-Data-Equal $sourceCatalog.data $remoteCatalog.data)){$backupDifferences.Add('data')}
  $differences=@($backupDifferences|ForEach-Object{'backup:'+$_})+@($remoteRestoreDifferences|ForEach-Object{'restore:'+$_})
  $storageFiles = @(Get-ChildItem -LiteralPath (Join-Path $work 'storage') -File -Recurse)
  if ($differences.Count) { throw ('Isolated restore catalog mismatch: ' + ($differences -join ',')) }
  $summary = [pscustomobject]@{project_ref=$manifest.project_ref;container=$container;database='driveit_r6b5_restore';payload_files=$written;storage_files=$storageFiles.Count;storage_bytes=($storageFiles|Measure-Object Length -Sum).Sum;migrations=$restored.data.migrations;auth_users=$restored.data.auth_users;event_triggers=@($restored.event_triggers).Count;rls_tables=@($restored.tables|Where-Object rls).Count;catalog_properties_matched=9;image=$image;database_version=$restored.server_version;source_database_version=$remoteCatalog.server_version;network='none'}
  $summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $work 'restore-summary.json') -Encoding utf8
  Write-Output ('PASS: isolated offline PostgreSQL restore; payload=' + $written + '; storage files=' + $storageFiles.Count + '; catalog properties matched=9; migrations=' + $restored.data.migrations + '; event triggers=' + @($restored.event_triggers).Count + '.')
} catch {
  Write-Output ('RESTORE_FAILED: ' + $_.Exception.Message)
  throw
}
