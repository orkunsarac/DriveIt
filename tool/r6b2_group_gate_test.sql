BEGIN;
INSERT INTO auth.users(id,aud,role,email,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
VALUES ('00000000-0000-4000-8000-000000000001','authenticated','authenticated','r6b2-gate@example.invalid','','{}','{}',now(),now());
SET LOCAL request.jwt.claim.sub = '00000000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  BEGIN
    PERFORM public.phase8_group_command('create',NULL::uuid,NULL::text,NULL::uuid,false);
    RAISE EXCEPTION 'group create unexpectedly accepted';
  EXCEPTION WHEN SQLSTATE '42501' THEN
    IF SQLERRM <> 'group_feature_disabled' THEN RAISE; END IF;
  END;
END $$;
RESET ROLE;
SET LOCAL ROLE service_role;
DO $$ BEGIN
  BEGIN
    PERFORM public.phase8_group_accept_location('00000000-0000-4000-8000-000000000001'::uuid,NULL::uuid,NULL::uuid,NULL::uuid,NULL::bigint,NULL::double precision,NULL::double precision,NULL::double precision,NULL::bigint,NULL::timestamptz);
    RAISE EXCEPTION 'group publish unexpectedly accepted';
  EXCEPTION WHEN SQLSTATE '42501' THEN
    IF SQLERRM <> 'group_feature_disabled' THEN RAISE; END IF;
  END;
END $$;
ROLLBACK;
