-- Phase 8 M4 candidate. Apply only after isolated PostgreSQL/Realtime tests
-- and explicit Planet DEV approval. Coordinates are never persisted here.
begin;

create table public.phase8_groups (
  id uuid primary key default gen_random_uuid(),
  administrator_id uuid not null references auth.users(id) on delete restrict,
  status text not null default 'active' check (status in ('active','ended','expired')),
  created_at timestamptz not null default clock_timestamp(),
  expires_at timestamptz not null default clock_timestamp() + interval '12 hours',
  extension_count smallint not null default 0 check (extension_count between 0 and 2),
  generation bigint not null default 1 check (generation > 0),
  revision bigint not null default 1 check (revision > 0),
  invite_code uuid not null unique,
  invite_hash bytea not null unique,
  next_join_order integer not null default 1
);

create table public.phase8_group_memberships (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.phase8_groups(id) on delete restrict,
  account_id uuid not null references auth.users(id) on delete restrict,
  role text not null check (role in ('administrator','member')),
  state text not null default 'active' check (state in ('active','left','banned')),
  joined_at timestamptz not null default clock_timestamp(),
  join_order integer not null,
  sharing_state text not null default 'off' check (sharing_state in ('off','sharing','paused')),
  publication_id uuid,
  publisher_expires_at timestamptz,
  last_sequence bigint not null default 0 check (last_sequence >= 0),
  last_sample_at timestamptz,
  unique(group_id,account_id)
);

create unique index phase8_one_active_group_per_account
  on public.phase8_group_memberships(account_id)
  where state = 'active';
create index phase8_active_members_by_group
  on public.phase8_group_memberships(group_id,join_order) where state = 'active';

alter table public.phase8_groups enable row level security;
alter table public.phase8_group_memberships enable row level security;
revoke all on public.phase8_groups, public.phase8_group_memberships from public, anon, authenticated, service_role;

-- Membership data and invite hashes are available only through guarded RPCs.
create or replace function public.phase8_group_command(
  p_action text,
  p_group_id uuid default null,
  p_invite_code text default null,
  p_member_id uuid default null,
  p_consent boolean default false
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_actor uuid := auth.uid();
  g public.phase8_groups%rowtype;
  m public.phase8_group_memberships%rowtype;
  v_invite text;
  v_expired_group uuid;
  v_active_group uuid;
  v_expired_publishers integer := 0;
  v_now timestamptz := clock_timestamp();
  v_snapshot jsonb;
begin
  if v_actor is null then raise exception using errcode='42501',message='account_required'; end if;
  if p_action not in ('current','create','join','extend','leave','ban','end','share_start','share_pause','share_stop','share_heartbeat') then
    raise exception using errcode='22023',message='action_invalid';
  end if;
  select group_id into v_active_group from public.phase8_group_memberships where account_id=v_actor and state='active' limit 1;
  update public.phase8_groups gg set status='expired',generation=generation+1,revision=revision+1
    where gg.id=v_active_group
      and gg.status='active' and gg.expires_at<=v_now returning id into v_expired_group;
  if v_expired_group is not null then
    update public.phase8_group_memberships set state='left',sharing_state='off',publication_id=null,publisher_expires_at=null
      where group_id=v_expired_group and state='active';
  elsif v_active_group is not null then
    perform 1 from public.phase8_groups where id=v_active_group for update;
    update public.phase8_group_memberships set sharing_state='paused',publication_id=null,publisher_expires_at=null,
      last_sequence=0,last_sample_at=null
      where group_id=v_active_group and state='active' and sharing_state='sharing'
        and (publisher_expires_at is null or publisher_expires_at<=v_now);
    get diagnostics v_expired_publishers = row_count;
    if v_expired_publishers>0 then
      update public.phase8_groups set generation=generation+1,revision=revision+1 where id=v_active_group;
    end if;
  end if;
  -- Expiry revokes active memberships and rotates the channel fence.
  update public.phase8_groups set status='expired',generation=generation+1,revision=revision+1
    where status='active' and expires_at<=v_now;
  update public.phase8_group_memberships set state='left',sharing_state='off',publication_id=null
    where state='active' and group_id in (select id from public.phase8_groups where status='expired' and expires_at<=v_now);
  select mm into m
  from public.phase8_group_memberships mm join public.phase8_groups gg on gg.id=mm.group_id
  where mm.account_id=v_actor and mm.state='active' and gg.status='active'
    and gg.expires_at>v_now limit 1;
  if m.id is not null then select * into g from public.phase8_groups where id=m.group_id; end if;

  if p_action='current' then
    if g.id is null then return null; end if;
  elsif p_action='create' then
    if m.id is not null then p_action := 'current';
    else
    v_invite := lower(gen_random_uuid()::text);
    insert into public.phase8_groups(administrator_id,invite_code,invite_hash)
      values(v_actor,v_invite::uuid,extensions.digest(convert_to(v_invite,'UTF8'),'sha256')) returning * into g;
    insert into public.phase8_group_memberships(group_id,account_id,role,join_order)
      values(g.id,v_actor,'administrator',0) returning * into m;
    end if;
  elsif p_action='join' then
    if p_invite_code is null or p_invite_code !~* '^[0-9a-f-]{36}$' then
      raise exception using errcode='22023',message='invalid_invite';
    end if;
    select * into g from public.phase8_groups where invite_hash=extensions.digest(convert_to(lower(p_invite_code),'UTF8'),'sha256') for update;
    if not found or g.status<>'active' or g.expires_at<=v_now then
      raise exception using errcode='P0002',message='invite_unavailable';
    end if;
    if m.id is not null and m.group_id<>g.id then raise exception using errcode='PT409',message='already_in_group'; end if;
    if not exists(select 1 from public.phase8_group_memberships where group_id=g.id and state='active' and account_id=v_actor) then
      if (select count(*) from public.phase8_group_memberships where group_id=g.id and state='active')>=10 then
        raise exception using errcode='PT409',message='group_full';
      end if;
      insert into public.phase8_group_memberships(group_id,account_id,role,join_order)
        values(g.id,v_actor,'member',g.next_join_order) returning * into m;
      update public.phase8_groups set next_join_order=next_join_order+1,generation=generation+1,revision=revision+1 where id=g.id returning * into g;
    end if;
  else
    if g.id is null or (p_group_id is not null and g.id<>p_group_id) then
      raise exception using errcode='42501',message='membership_required';
    end if;
    -- Consistent lock order with publish: group, then membership. This makes
    -- pause/revoke and an in-flight location authorization serialize cleanly.
    select * into g from public.phase8_groups where id=g.id for update;
    select * into m from public.phase8_group_memberships where id=m.id and state='active' for update;
    if not found then raise exception using errcode='42501',message='membership_required'; end if;
    if p_action in ('extend','ban','end') and m.role<>'administrator' then
      raise exception using errcode='42501',message='administrator_required';
    end if;
    if p_action='extend' then
      if g.extension_count>=2 then raise exception using errcode='PT409',message='extension_limit'; end if;
      update public.phase8_groups set expires_at=expires_at+interval '6 hours',extension_count=extension_count+1,revision=revision+1
        where id=g.id returning * into g;
    elsif p_action='leave' then
      update public.phase8_group_memberships set state='left',sharing_state='off',publication_id=null,publisher_expires_at=null where id=m.id;
      if g.administrator_id=v_actor then
        update public.phase8_group_memberships set role='administrator'
          where id=(select id from public.phase8_group_memberships where group_id=g.id and state='active' and account_id<>v_actor order by join_order limit 1);
      end if;
      update public.phase8_groups set generation=generation+1,revision=revision+1,
        status=case when (select count(*) from public.phase8_group_memberships where group_id=g.id and state='active')=0 then 'ended' else status end,
        administrator_id=case when g.administrator_id=v_actor then coalesce((select account_id from public.phase8_group_memberships where group_id=g.id and state='active' and account_id<>v_actor order by join_order limit 1),v_actor) else administrator_id end
        where id=g.id returning * into g;
    elsif p_action='ban' then
      if p_member_id is null or p_member_id=m.id then raise exception using errcode='22023',message='member_invalid'; end if;
      update public.phase8_group_memberships set state='banned',sharing_state='off',publication_id=null,publisher_expires_at=null
        where id=p_member_id and group_id=g.id and state='active';
      if not found then raise exception using errcode='P0002',message='member_not_found'; end if;
      update public.phase8_groups set generation=generation+1,revision=revision+1 where id=g.id returning * into g;
    elsif p_action='end' then
      update public.phase8_groups set status='ended',generation=generation+1,revision=revision+1 where id=g.id returning * into g;
      update public.phase8_group_memberships set state='left',sharing_state='off',publication_id=null,publisher_expires_at=null where group_id=g.id and state='active';
    elsif p_action in ('share_start','share_pause','share_stop') then
      if p_action='share_start' and p_consent is distinct from true then
        raise exception using errcode='42501',message='consent_required';
      end if;
      update public.phase8_group_memberships set
        sharing_state=case p_action when 'share_start' then 'sharing' when 'share_pause' then 'paused' else 'off' end,
        publication_id=case when p_action='share_start' then gen_random_uuid() else null end,
        publisher_expires_at=case when p_action='share_start' then v_now+interval '30 seconds' else null end,
        last_sequence=0,last_sample_at=null
        where id=m.id returning * into m;
      update public.phase8_groups set generation=generation+1,revision=revision+1 where id=g.id returning * into g;
    elsif p_action='share_heartbeat' then
      update public.phase8_group_memberships set publisher_expires_at=v_now+interval '30 seconds'
        where id=m.id and sharing_state='sharing' and publication_id is not null and publisher_expires_at>v_now
        returning * into m;
      if not found then raise exception using errcode='42501',message='publication_revoked'; end if;
    end if;
  end if;

  select jsonb_build_object(
    'id',g.id,'createdAt',g.created_at,'observedAt',v_now,'expiresAt',g.expires_at,
    'status',case when g.status='active' and g.expires_at<=v_now then 'expired' else g.status end,
    'extensionCount',g.extension_count,'revision',g.revision,'generation',g.generation,
    'inviteCode',g.invite_code::text,
    'grant',case when p_action='share_start' then jsonb_build_object('membershipId',m.id,'publicationId',m.publication_id,'startedAt',v_now,'generation',g.generation) else null end,
    'members',coalesce((select jsonb_agg(jsonb_build_object(
      'membershipId',mm.id,'accountId',case when mm.account_id=v_actor then v_actor::text else mm.id::text end,
      'displayName',coalesce(u.raw_user_meta_data->>'display_name','DriveIt üyesi'),
      'joinedAt',mm.joined_at,'joinOrder',mm.join_order,'role',mm.role,
      'sharingStatus',case when mm.sharing_state='sharing' and mm.last_sample_at>=v_now-interval '15 seconds' then 'sharing' else mm.sharing_state end,
      'location',null,'colorIndex',mod(mm.join_order,10)
    ) order by mm.join_order) from public.phase8_group_memberships mm join auth.users u on u.id=mm.account_id where mm.group_id=g.id and mm.state='active'),'[]'::jsonb)
  ) into v_snapshot;
  return v_snapshot;
end; $$;

create or replace function public.phase8_group_accept_location(
 p_actor uuid,p_group uuid,p_membership uuid,p_publication uuid,p_generation bigint,
 p_lat double precision,p_lon double precision,p_accuracy double precision,p_sequence bigint,p_recorded_at timestamptz
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare g public.phase8_groups%rowtype; m public.phase8_group_memberships%rowtype; v_now timestamptz:=clock_timestamp();
begin
 if p_actor is null or p_group is null or p_membership is null or p_publication is null or p_recorded_at is null then
   raise exception using errcode='22023',message='location_invalid';
 end if;
 select * into g from public.phase8_groups where id=p_group for update;
 if not found or g.status<>'active' or g.expires_at<=v_now or g.generation<>p_generation then
   raise exception using errcode='42501',message='group_generation_revoked';
 end if;
 select * into m from public.phase8_group_memberships where id=p_membership and group_id=g.id and account_id=p_actor and state='active' for update;
 if not found or m.sharing_state<>'sharing' or m.publication_id<>p_publication or m.publisher_expires_at<=v_now then
   raise exception using errcode='42501',message='publication_revoked';
 end if;
 if p_lat is null or p_lon is null or abs(p_lat)>90 or abs(p_lon)>180 or p_accuracy is null or p_accuracy<0 or p_accuracy>75
    or p_sequence<=m.last_sequence or p_recorded_at>v_now+interval '3 seconds' or p_recorded_at<v_now-interval '15 seconds'
    or (m.last_sample_at is not null and p_recorded_at<=m.last_sample_at+interval '250 milliseconds') then
   raise exception using errcode='22023',message='location_invalid_or_stale';
 end if;
 update public.phase8_group_memberships set last_sequence=p_sequence,last_sample_at=p_recorded_at where id=m.id;
 return jsonb_build_object('topic','driveit:group:'||g.id||':'||g.generation,'event','location',
   'payload',jsonb_build_object('generation',g.generation,'membershipId',m.id,'latitude',p_lat,'longitude',p_lon,
     'accuracyMeters',p_accuracy,'sequence',p_sequence,'recordedAt',p_recorded_at));
end; $$;

revoke all on function public.phase8_group_command(text,uuid,text,uuid,boolean) from public,anon;
grant execute on function public.phase8_group_command(text,uuid,text,uuid,boolean) to authenticated;
revoke all on function public.phase8_group_accept_location(uuid,uuid,uuid,uuid,bigint,double precision,double precision,double precision,bigint,timestamptz) from public,anon,authenticated;
grant execute on function public.phase8_group_accept_location(uuid,uuid,uuid,uuid,bigint,double precision,double precision,double precision,bigint,timestamptz) to service_role;

-- Only private current-generation topics can be joined. Clients have no send
-- policy; location enters via the authenticated Edge function above.
create or replace function public.phase8_group_topic_authorized() returns boolean
language sql security definer set search_path = '' as $$
 select exists(
   select 1 from public.phase8_groups g join public.phase8_group_memberships m on m.group_id=g.id
   where m.account_id=auth.uid() and m.state='active' and g.status='active' and g.expires_at>clock_timestamp()
     and realtime.topic()='driveit:group:'||g.id::text||':'||g.generation::text
 );
$$;
revoke all on function public.phase8_group_topic_authorized() from public,anon;
grant execute on function public.phase8_group_topic_authorized() to authenticated;
create policy phase8_group_current_member_read on realtime.messages for select to authenticated
 using (
   extension = 'broadcast' and
   public.phase8_group_topic_authorized()
 );
-- Restrictive topic-scoped fences prevent a permissive policy from another
-- Planet feature from exposing or accepting direct client broadcasts here,
-- without changing behavior for unrelated Realtime topics.
create policy phase8_group_current_member_fence on realtime.messages as restrictive
 for select to authenticated using (
   realtime.topic() not like 'driveit:group:%' or public.phase8_group_topic_authorized()
 );
create policy phase8_group_no_client_publish on realtime.messages as restrictive
 for insert to authenticated with check (realtime.topic() not like 'driveit:group:%');

commit;
