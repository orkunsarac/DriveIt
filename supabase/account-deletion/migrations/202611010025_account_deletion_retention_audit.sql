-- Forward-only local candidate. Separates short-lived retry receipts from
-- the minimized record of completed/attempted erasure operations.
begin;

create table public.account_deletion_erasure_audit (
  event_id bigint primary key,
  operation_id uuid not null,
  event_state text not null check (event_state ~ '^[a-z_]{1,64}$'),
  occurred_at timestamptz not null,
  -- 1096 fixed days is at least three calendar years, including a leap day;
  -- epoch arithmetic avoids session-time-zone/DST-dependent interval math.
  retain_until timestamptz not null,
  check (extract(epoch from retain_until) >= extract(epoch from occurred_at) + 94694400)
);

comment on table public.account_deletion_erasure_audit is
  'Append-only minimized erasure-operation evidence; operation_id is opaque/pseudonymous and remains subject to legal review.';
comment on column public.account_deletion_erasure_audit.retain_until is
  'Technical minimum-retention candidate of 1096 days; legal applicability and any later disposal remain subject to counsel approval.';

alter table public.account_deletion_erasure_audit enable row level security;
revoke all on public.account_deletion_erasure_audit from public, anon, authenticated, service_role;

-- Backfill still-present events before enabling the durable copy trigger.
-- This cannot recover events that an earlier receipt prune already cascaded.
insert into public.account_deletion_erasure_audit
  (event_id, operation_id, event_state, occurred_at, retain_until)
select id, job_id, state, occurred_at,
  to_timestamp(extract(epoch from occurred_at) + 94694400)
from public.account_deletion_events
on conflict (event_id) do nothing;

create function public.account_deletion_capture_erasure_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.account_deletion_erasure_audit
    (event_id, operation_id, event_state, occurred_at, retain_until)
  values (
    new.id, new.job_id, new.state, new.occurred_at,
    to_timestamp(extract(epoch from new.occurred_at) + 94694400)
  )
  on conflict (event_id) do nothing;
  return new;
end;
$$;
revoke all on function public.account_deletion_capture_erasure_event()
  from public, anon, authenticated, service_role;

create trigger account_deletion_durable_audit
after insert on public.account_deletion_events
for each row execute function public.account_deletion_capture_erasure_event();

create function public.account_deletion_reject_audit_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'erasure_audit_append_only' using errcode = '55000';
end;
$$;
revoke all on function public.account_deletion_reject_audit_mutation()
  from public, anon, authenticated, service_role;

create trigger account_deletion_erasure_audit_immutable
before update or delete on public.account_deletion_erasure_audit
for each row execute function public.account_deletion_reject_audit_mutation();

commit;
