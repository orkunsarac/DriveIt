$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
$root = Join-Path $env:LOCALAPPDATA 'DriveIt\Recovery\R6B3-DEV-20261103-013444-8089709d'
$descriptor = Get-Content (Join-Path $root 'r6b4-http-descriptor.json') -Raw | ConvertFrom-Json
if ($descriptor.name -notmatch '^pgr6a-[a-f0-9]{10}$') { throw 'Invalid isolated descriptor.' }
$target = @(docker ps --filter ('label=com.supabase.stack=' + $descriptor.id) --filter 'label=com.supabase.service=database' --format '{{.Names}}')
$restore = @(docker ps --filter 'label=com.supabase.service=database' --format '{{.Names}}' | Where-Object { $_ -like 'supabase-r6b2-rehearsal-r6b2-rehearsal-20261103-database-*' })
if ($target.Count -ne 1 -or $restore.Count -ne 1 -or !$target[0].StartsWith('supabase-'+$descriptor.name+'-'+$descriptor.name+'-database-')) { throw 'Ambiguous local stack.' }
$system = docker exec $target[0] psql -U postgres -d postgres -X -At -c 'select system_identifier from pg_control_system();'
if ($LASTEXITCODE -ne 0 -or $system -cne $descriptor.system) { throw 'Physical test cluster mismatch.' }
$hash = docker exec $restore[0] psql -U postgres -d r6b2_rehearsal_v2 -X -At -c "SELECT md5(replace(pg_get_functiondef('public.rls_auto_enable()'::regprocedure),E'\r\n',E'\n'));"
if ($LASTEXITCODE -ne 0 -or $hash -cne '6998ea6b4c2480f5d2e34b5dcf3f8d36') { throw 'Restored function differs from observed DEV definition.' }
$existing = docker exec $target[0] psql -U postgres -d postgres -X -At -c "SELECT coalesce(to_regprocedure('public.rls_auto_enable()')::text,'absent');"
if ($existing -cne 'absent') { throw 'Test stack already has the function; refusing to overwrite.' }
$body = @(docker exec $restore[0] psql -U postgres -d r6b2_rehearsal_v2 -X -q -At -c "SELECT pg_get_functiondef('public.rls_auto_enable()'::regprocedure);") -join "`n"
if ($LASTEXITCODE -ne 0 -or !$body.Contains('pg_event_trigger_ddl_commands()')) { throw 'Function source unavailable.' }
$sql = "\set VERBOSITY verbose`nBEGIN;`n" + $body + ";`n" + @'

REVOKE ALL ON FUNCTION public.rls_auto_enable() FROM PUBLIC,anon,authenticated,service_role;
CREATE EVENT TRIGGER r6b4_ensure_rls ON ddl_command_end WHEN TAG IN ('CREATE TABLE','CREATE TABLE AS','SELECT INTO') EXECUTE FUNCTION public.rls_auto_enable();
ALTER FUNCTION public.rls_auto_enable() OWNER TO postgres;
DO $$ BEGIN
  IF (SELECT pg_get_userbyid(proowner) FROM pg_proc WHERE oid='public.rls_auto_enable()'::regprocedure) <> 'postgres' THEN RAISE EXCEPTION 'unexpected_event_function_owner'; END IF;
END $$;
SET LOCAL ROLE postgres;
CREATE TABLE public.r6b4_event_probe(id integer);
DO $$ BEGIN
  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid='public.r6b4_event_probe'::regclass) THEN RAISE EXCEPTION 'event_trigger_did_not_enable_rls'; END IF;
END $$;
ROLLBACK;
'@
$sql | docker exec -i $target[0] psql -U supabase_admin -d postgres -X -q -v ON_ERROR_STOP=1
if ($LASTEXITCODE -ne 0) { throw 'Local event trigger behavior failed.' }
Write-Output 'PASS: matching DEV function enables RLS for a new public table in an isolated transaction.'
