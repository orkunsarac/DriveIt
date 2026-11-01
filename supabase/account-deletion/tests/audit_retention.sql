-- Run only against the isolated P-GR6A stack. All fixture writes roll back.
begin;
do $$
declare
  v_job uuid := gen_random_uuid();
  v_owner uuid := gen_random_uuid();
  v_email text := 'pgr6h-audit-' || gen_random_uuid()::text || '@example.invalid';
  v_event bigint;
  v_audit_count integer;
begin
  if has_table_privilege('anon', 'public.account_deletion_erasure_audit', 'select')
     or has_table_privilege('authenticated', 'public.account_deletion_erasure_audit', 'select')
     or has_table_privilege('service_role', 'public.account_deletion_erasure_audit', 'select')
     or has_table_privilege('anon', 'public.account_deletion_erasure_audit', 'insert')
     or has_table_privilege('authenticated', 'public.account_deletion_erasure_audit', 'insert')
     or has_table_privilege('service_role', 'public.account_deletion_erasure_audit', 'insert') then
    raise exception 'audit_client_privilege_leak';
  end if;

  insert into auth.users(
    id, aud, role, email, encrypted_password,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
  ) values (
    v_owner, 'authenticated', 'authenticated', v_email, '',
    '{"provider":"email","providers":["email"]}', '{}', clock_timestamp(), clock_timestamp()
  );
  insert into public.account_deletion_jobs(id, owner_id, receipt_hash)
  values (v_job, v_owner, repeat('a', 64));
  select event_id into v_event
  from public.account_deletion_erasure_audit
  where operation_id = v_job;
  if v_event is null then raise exception 'audit_event_not_captured'; end if;

  select count(*) into v_audit_count from public.account_deletion_erasure_audit
  where event_id = v_event;
  if v_audit_count <> 1 then raise exception 'audit_event_not_idempotent'; end if;

  -- Reinsert a synthetic event with the same source event identity. The
  -- durable copy must remain one row (simulates replay/lost acknowledgement).
  delete from public.account_deletion_events where id = v_event;
  insert into public.account_deletion_events(id, job_id, state, occurred_at)
  overriding system value
  values (v_event, v_job, 'pending', clock_timestamp());
  select count(*) into v_audit_count from public.account_deletion_erasure_audit
  where event_id = v_event;
  if v_audit_count <> 1 then raise exception 'audit_replay_duplicated'; end if;

  begin
    update public.account_deletion_erasure_audit
    set event_state = 'changed' where event_id = v_event;
    raise exception 'audit_update_was_not_rejected';
  exception when sqlstate '55000' then null;
  end;
  begin
    delete from public.account_deletion_erasure_audit where event_id = v_event;
    raise exception 'audit_delete_was_not_rejected';
  exception when sqlstate '55000' then null;
  end;

  delete from auth.users where id = v_owner;
  update public.account_deletion_jobs
  set state = 'completed', owner_id = null, owner_email = null,
      completed_at = clock_timestamp() - interval '48 hours'
  where id = v_job;
  perform public.account_deletion_prune_receipts();
  if exists(select 1 from public.account_deletion_jobs where id = v_job) then
    raise exception 'operational_receipt_not_pruned';
  end if;
  if exists(select 1 from public.account_deletion_events where job_id = v_job) then
    raise exception 'operational_events_not_cascaded';
  end if;
  if (select count(*) from public.account_deletion_erasure_audit where operation_id = v_job) < 2 then
    raise exception 'durable_audit_cascaded_with_job';
  end if;
  if (select retain_until < occurred_at + interval '3 years'
      from public.account_deletion_erasure_audit where event_id = v_event) then
    raise exception 'retention_shorter_than_three_years';
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='account_deletion_erasure_audit'
      and column_name in ('email','owner_email','owner_id','user_id','gps','route','token','receipt_hash')
  ) then raise exception 'audit_contains_forbidden_personal_payload_column'; end if;
end;
$$;
rollback;
