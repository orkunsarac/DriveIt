begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(31);

insert into auth.users(id,aud,role,email,raw_user_meta_data) values
 ('10101010-1010-4010-8010-101010101010','authenticated','authenticated','m4-a@example.invalid','{"display_name":"Synthetic A"}'),
 ('20202020-2020-4020-8020-202020202020','authenticated','authenticated','m4-b@example.invalid','{"display_name":"Synthetic B"}');
insert into auth.users(id,aud,role,email) select gen_random_uuid(),'authenticated','authenticated',
  'm4-'||n::text||'@example.invalid' from generate_series(3,11) n;
create temporary table m4_group_state(group_id uuid, invite_code text, response jsonb);
create temporary table m4_candidates(ordinal integer, account_id uuid);
insert into m4_candidates select row_number() over(order by email)::integer,id from auth.users
 where email like 'm4-%@example.invalid' and id not in
 ('10101010-1010-4010-8010-101010101010'::uuid,'20202020-2020-4020-8020-202020202020'::uuid);
grant select,insert,update on m4_group_state to authenticated;
grant select on m4_candidates to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub','10101010-1010-4010-8010-101010101010',true);
select lives_ok($q$with r as (select public.phase8_group_command('create') j)
 insert into m4_group_state select (j->>'id')::uuid,j->>'inviteCode',j from r$q$,'authenticated owner creates group');
select is((select response->>'status' from m4_group_state),'active','new group active');
select is((select jsonb_array_length(response->'members') from m4_group_state),1,'creator is initial member');
select is((select response->'members'->0->>'sharingStatus' from m4_group_state),'off','sharing defaults off');
select ok((select invite_code ~* '^[0-9a-f-]{36}$' from m4_group_state),'server returns invitation code');
 select ok((select abs(extract(epoch from ((response->>'expiresAt')::timestamptz-(response->>'createdAt')::timestamptz-interval '12 hours'))) < 1 from m4_group_state),'initial lifetime is 12 hours');

select set_config('request.jwt.claim.sub','20202020-2020-4020-8020-202020202020',true);
select lives_ok($q$with r as (select public.phase8_group_command('join',null,(select invite_code from m4_group_state)) j)
 update m4_group_state set response=r.j from r$q$,'second authenticated owner joins');
select is((select jsonb_array_length(response->'members') from m4_group_state),2,'both members visible to member');
select lives_ok($q$do $$ declare c record; begin
 for c in select account_id from m4_candidates where ordinal<=8 order by ordinal loop
   perform set_config('request.jwt.claim.sub',c.account_id::text,true);
   perform public.phase8_group_command('join',null,(select invite_code from m4_group_state));
 end loop; end $$;$q$,'remaining seats join serially');
select is((select jsonb_array_length(public.phase8_group_command('current')->'members')),10,'group admits ten participants');
select set_config('request.jwt.claim.sub',(select account_id::text from m4_candidates where ordinal=9),true);
select throws_ok($q$select public.phase8_group_command('join',null,(select invite_code from m4_group_state))$q$,
 'PT409','group_full','eleventh participant rejected');
select set_config('request.jwt.claim.sub','20202020-2020-4020-8020-202020202020',true);
select throws_ok($q$select public.phase8_group_command('end',(select group_id from m4_group_state))$q$,
 '42501','administrator_required','member cannot end group');
select set_config('request.jwt.claim.sub','10101010-1010-4010-8010-101010101010',true);
select lives_ok($q$select public.phase8_group_command('start',(select group_id from m4_group_state))$q$,'administrator starts ride');
select set_config('request.jwt.claim.sub','20202020-2020-4020-8020-202020202020',true);
select throws_ok($q$select public.phase8_group_command('share_start',(select group_id from m4_group_state),null,null,false)$q$,
 '42501','consent_required','sharing requires explicit consent');
select lives_ok($q$select public.phase8_group_command('share_start',(select group_id from m4_group_state),null,null,true)$q$,
 'explicitly consented sharing starts');
select is((select (public.phase8_group_command('current')->'members'->1->>'sharingStatus')),'sharing','only consented member shares');
select lives_ok($q$select public.phase8_group_command('share_heartbeat',(select group_id from m4_group_state))$q$,
 'active foreground publisher renews bounded server authorization');
select lives_ok($q$select public.phase8_group_command('share_pause',(select group_id from m4_group_state))$q$,
 'pause revokes publication');
select ok((select (public.phase8_group_command('current')->'generation')::bigint)>1,'pause rotates server topic generation');
select is((select jsonb_typeof(public.phase8_group_command('current')->'members'->1->'location')),'null','snapshot never stores locations');
select set_config('request.jwt.claim.sub','10101010-1010-4010-8010-101010101010',true);
select lives_ok($q$select public.phase8_group_command('extend',(select group_id from m4_group_state))$q$,'administrator first extension');
select lives_ok($q$select public.phase8_group_command('extend',(select group_id from m4_group_state))$q$,'administrator second extension');
select is((public.phase8_group_command('current')->>'extensionCount')::int,2,'two extensions persisted');
select throws_ok($q$select public.phase8_group_command('extend',(select group_id from m4_group_state))$q$,
 'PT409','extension_limit','third extension rejected');
select lives_ok($q$select public.phase8_group_command('leave',(select group_id from m4_group_state))$q$,'administrator can leave safely');
select set_config('request.jwt.claim.sub','20202020-2020-4020-8020-202020202020',true);
select is((public.phase8_group_command('current')->>'status'),'active','remaining members keep group active');
select is((public.phase8_group_command('current')->'members'->0->>'role'),'administrator','administrator transfers on leave');
reset role;
update public.phase8_groups set expires_at=clock_timestamp()-interval '1 second'
 where id=(select group_id from m4_group_state);
set local role authenticated;
select set_config('request.jwt.claim.sub','20202020-2020-4020-8020-202020202020',true);
select ok(public.phase8_group_command('current') is null,'expired group is no longer visible to members');
select throws_ok($q$select public.phase8_group_command('share_start',(select group_id from m4_group_state),null,null,true)$q$,
 '42501','membership_required','expired group cannot restart sharing');
reset role;
select is((select status from public.phase8_groups where id=(select group_id from m4_group_state)),'expired',
 'server persists the expired group state');

set local role anon;
select throws_ok($q$select public.phase8_group_command('current')$q$,'42501',null,'anonymous group access denied');
reset role;
select * from finish();
rollback;
