-- Synthetic fixture, entirely rolled back. No trigger, FK, RLS or ACL bypass.
BEGIN;
DO $$
DECLARE
  a uuid := gen_random_uuid(); b uuid := gen_random_uuid(); owner_id uuid;
  job uuid := gen_random_uuid(); lease_id uuid := gen_random_uuid();
  intent uuid; source_id uuid; object_path text; result jsonb; state text;
  key text := 'owner-sync-v2:' || repeat('c',64);
BEGIN
  IF has_function_privilege('authenticated','public.account_deletion_request(uuid,uuid,text)','execute')
     OR has_function_privilege('anon','public.account_deletion_claim(uuid,text,uuid)','execute')
     OR NOT has_function_privilege('service_role','public.account_deletion_request(uuid,uuid,text)','execute') THEN
    RAISE EXCEPTION 'request_or_receipt_acl_invalid';
  END IF;
  FOREACH owner_id IN ARRAY ARRAY[a,b] LOOP
    INSERT INTO auth.users(id,aud,role,email,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
      VALUES(owner_id,'authenticated','authenticated',owner_id::text||'@example.invalid','','{}','{}',now(),now());
    intent:=gen_random_uuid(); source_id:=gen_random_uuid(); object_path:=owner_id::text||'/'||intent::text||'/envelope.json';
    INSERT INTO public.phase8_drive_upload_intents(id,owner_id,idempotency_key,source_identity,owner_scope,contract_version,payload_fingerprint,object_sha256,object_bytes,staging_path,state,receipt,finalized_at)
      VALUES(intent,owner_id,key,source_id,format('["local_account_store_v1","account","%s"]',owner_id),2,repeat('a',64),repeat('b',64),2,object_path,'finalized','{}',now());
    INSERT INTO public.phase8_drive_owner_sequences(owner_id,high_water) VALUES(owner_id,1);
    INSERT INTO public.phase8_drive_manifests(owner_id,source_identity,drive_id,idempotency_key,contract_version,payload_fingerprint,object_sha256,object_bytes,object_path,change_sequence)
      VALUES(owner_id,source_id,'synthetic',key,2,repeat('a',64),repeat('b',64),2,object_path,1);
    INSERT INTO public.phase8_drive_changes(owner_id,sequence,source_identity,operation,idempotency_key,payload_fingerprint,object_sha256,object_path)
      VALUES(owner_id,1,source_id,'drive_upsert',key,repeat('a',64),repeat('b',64),object_path);
    INSERT INTO public.phase8_drive_snapshots(owner_id,high_water) VALUES(owner_id,1);
  END LOOP;
  result:=public.account_deletion_request(a,job,repeat('a',64));
  IF result->>'state'<>'pending' THEN RAISE EXCEPTION 'request_not_pending'; END IF;
  BEGIN
    PERFORM public.account_deletion_claim(job,repeat('b',64),lease_id);
    RAISE EXCEPTION 'wrong_receipt_accepted';
  EXCEPTION WHEN SQLSTATE '42501' THEN
    IF SQLERRM<>'receipt_invalid' THEN RAISE; END IF;
  END;
  result:=public.account_deletion_claim(job,repeat('a',64),lease_id);
  IF result->>'owner'<>a::text THEN RAISE EXCEPTION 'wrong_owner_claimed'; END IF;
  state:=public.account_deletion_purge(job,lease_id);
  IF state<>'purged' THEN RAISE EXCEPTION 'purge_unexpected: %',state; END IF;
  IF EXISTS(SELECT 1 FROM public.phase8_drive_manifests m WHERE m.owner_id=a)
     OR NOT EXISTS(SELECT 1 FROM public.phase8_drive_manifests m WHERE m.owner_id=b)
     OR NOT EXISTS(SELECT 1 FROM auth.users u WHERE u.id=a)
     OR NOT EXISTS(SELECT 1 FROM auth.users u WHERE u.id=b) THEN
    RAISE EXCEPTION 'owner_isolation_or_auth_order_failed';
  END IF;
  BEGIN
    PERFORM public.account_deletion_complete(job,lease_id);
    RAISE EXCEPTION 'premature_completion_accepted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM<>'auth_deletion_unconfirmed' THEN RAISE; END IF;
  END;
  DELETE FROM auth.users WHERE id=a;
  PERFORM public.account_deletion_complete(job,lease_id);
  IF NOT EXISTS(SELECT 1 FROM public.account_deletion_jobs j WHERE j.id=job AND j.state='completed' AND j.owner_id IS NULL)
     OR NOT EXISTS(SELECT 1 FROM auth.users u WHERE u.id=b)
     OR NOT EXISTS(SELECT 1 FROM public.phase8_drive_manifests m WHERE m.owner_id=b) THEN
    RAISE EXCEPTION 'completion_or_other_owner_failed';
  END IF;
END $$;
ROLLBACK;
