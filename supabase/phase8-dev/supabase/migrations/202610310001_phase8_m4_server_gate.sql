begin;

-- Administrative rollout state. No API role may read or mutate this table.
create table public.phase8_group_rollout (
  singleton boolean primary key default true check (singleton),
  enabled boolean not null default false
);
insert into public.phase8_group_rollout values (true, false);
alter table public.phase8_group_rollout enable row level security;
revoke all on public.phase8_group_rollout from public, anon, authenticated, service_role;

create function public.phase8_group_enabled() returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  return coalesce((select enabled from public.phase8_group_rollout where singleton), false);
exception when others then return false;
end;
$$;
revoke all on function public.phase8_group_enabled() from public, anon, authenticated;
grant execute on function public.phase8_group_enabled() to service_role;

-- Preserve the installed M4 implementation, signatures and ACLs. Abort rather
-- than silently accepting an unexpected predecessor function definition.
do $migration$
declare definition text;
begin
  definition := pg_get_functiondef('public.phase8_group_command(text,uuid,text,uuid,boolean)'::regprocedure);
  if definition !~* '\mbegin\M' then raise exception 'M4 command body missing'; end if;
  definition := regexp_replace(definition, '\mbegin\M',
    'begin
  if p_action is null or p_action not in (''current'',''leave'',''end'',''share_stop'',''share_pause'') then
    if not public.phase8_group_enabled() then
      raise exception using errcode=''42501'', message=''group_feature_disabled'';
    end if;
  end if;', 'i');
  execute definition;
  definition := pg_get_functiondef('public.phase8_group_accept_location(uuid,uuid,uuid,uuid,bigint,double precision,double precision,double precision,bigint,timestamp with time zone)'::regprocedure);
  if definition !~* '\mbegin\M' then raise exception 'M4 publisher body missing'; end if;
  definition := regexp_replace(definition, '\mbegin\M',
    'begin
  if not public.phase8_group_enabled() then
    raise exception using errcode=''42501'', message=''group_feature_disabled'';
  end if;', 'i');
  execute definition;
end;
$migration$;

create or replace function public.phase8_group_topic_authorized() returns boolean
language sql security definer set search_path = '' as $$
 select public.phase8_group_enabled() and exists (
   select 1 from public.phase8_groups g join public.phase8_group_memberships m on m.group_id=g.id
   where m.account_id=auth.uid() and m.state='active' and g.status='active' and g.expires_at>clock_timestamp()
     and realtime.topic()='driveit:group:'||g.id::text||':'||g.generation::text
 );
$$;
commit;
