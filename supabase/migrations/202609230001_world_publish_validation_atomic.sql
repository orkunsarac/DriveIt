-- Server-only validation claim and atomic road/section persistence.
-- Run after world_publishes, world_validated_roads and
-- world_validated_road_sections have been created.
begin;

alter table public.world_publishes
  add column if not exists validation_claim_token uuid,
  add column if not exists validation_claimed_at timestamptz;

create unique index if not exists world_validated_roads_publish_id_unique
  on public.world_validated_roads (publish_id);
create unique index if not exists world_validated_road_sections_order_unique
  on public.world_validated_road_sections (validated_road_id, section_order);

create or replace function public.claim_world_publish_validation(
  p_publish_id uuid,
  p_user_id uuid
) returns jsonb
language plpgsql security definer
set search_path = pg_catalog, extensions, pg_temp
as $$
declare
  v_publish public.world_publishes%rowtype;
  v_road public.world_validated_roads%rowtype;
  v_token uuid;
begin
  select * into v_publish from public.world_publishes
    where id = p_publish_id for update;
  if not found or v_publish.user_id <> p_user_id then
    return jsonb_build_object('state', 'not_found');
  end if;
  select * into v_road from public.world_validated_roads
    where publish_id = p_publish_id;
  if found then
    return jsonb_build_object(
      'state', 'exists', 'validated_road_id', v_road.id,
      'valid_distance_meters', v_road.valid_distance_meters,
      'section_count', v_road.section_count
    );
  end if;
  if v_publish.source_path is null or v_publish.source_ready_at is null then
    return jsonb_build_object('state', 'source_not_ready');
  end if;
  if v_publish.status = 'failed' or v_publish.status = 'published' then
    return jsonb_build_object('state', 'blocked');
  end if;
  -- A crashed function can be reclaimed; the old token can no longer write.
  if v_publish.status = 'processing'
      and v_publish.validation_claim_token is not null
      and v_publish.validation_claimed_at > now() - interval '1 hour' then
    return jsonb_build_object('state', 'busy');
  end if;
  v_token := gen_random_uuid();
  update public.world_publishes
    set status = 'processing', error_code = null,
      validation_claim_token = v_token,
      validation_claimed_at = now(), updated_at = now()
    where id = p_publish_id;
  return jsonb_build_object('state', 'claimed', 'claim_token', v_token);
end;
$$;

create or replace function public.finish_world_publish_validation(
  p_publish_id uuid,
  p_user_id uuid,
  p_claim_token uuid,
  p_road jsonb,
  p_sections jsonb
) returns jsonb
language plpgsql security definer
set search_path = pg_catalog, extensions, pg_temp
as $$
declare
  v_publish public.world_publishes%rowtype;
  v_road public.world_validated_roads%rowtype;
  v_id uuid;
  v_item jsonb;
  v_section_count integer;
  v_multi geometry;
  v_line geometry;
begin
  select * into v_publish from public.world_publishes
    where id = p_publish_id for update;
  if not found or v_publish.user_id <> p_user_id then
    return jsonb_build_object('state', 'not_found');
  end if;
  select * into v_road from public.world_validated_roads
    where publish_id = p_publish_id;
  if found then
    return jsonb_build_object(
      'state', 'exists', 'validated_road_id', v_road.id,
      'valid_distance_meters', v_road.valid_distance_meters,
      'section_count', v_road.section_count
    );
  end if;
  if v_publish.status <> 'processing'
      or v_publish.validation_claim_token is distinct from p_claim_token then
    return jsonb_build_object('state', 'stale_claim');
  end if;
  if jsonb_typeof(p_sections) <> 'array' or jsonb_array_length(p_sections) < 1
      or jsonb_typeof(p_road->'geometry') <> 'object' then
    raise exception 'invalid validation geometry';
  end if;
  v_section_count := jsonb_array_length(p_sections);
  if v_section_count <> (p_road->>'section_count')::integer then
    raise exception 'section count mismatch';
  end if;
  v_multi := st_setsrid(st_geomfromgeojson((p_road->'geometry')::text), 4326);
  if geometrytype(v_multi) <> 'MULTILINESTRING' or st_isempty(v_multi)
      or not st_isvalid(v_multi)
      or st_numgeometries(v_multi) <> v_section_count then
    raise exception 'invalid multi-line geometry';
  end if;
  insert into public.world_validated_roads (
    publish_id, user_id, provider_id, processing_version,
    valid_distance_meters, validation_status, confidence, direction_key,
    average_heading_degrees, section_count, geometry, created_at, updated_at
  ) values (
    p_publish_id, p_user_id, p_road->>'provider_id',
    (p_road->>'processing_version')::integer,
    (p_road->>'valid_distance_meters')::double precision,
    p_road->>'validation_status',
    (p_road->>'confidence')::double precision,
    p_road->>'direction_key',
    (p_road->>'average_heading_degrees')::double precision,
    v_section_count, v_multi, now(), now()
  )
  on conflict (publish_id) do nothing
  returning id into v_id;
  if v_id is null then
    select * into v_road from public.world_validated_roads
      where publish_id = p_publish_id;
    update public.world_publishes
      set validation_claim_token = null, validation_claimed_at = null,
        updated_at = now()
      where id = p_publish_id;
    return jsonb_build_object(
      'state', 'exists', 'validated_road_id', v_road.id,
      'valid_distance_meters', v_road.valid_distance_meters,
      'section_count', v_road.section_count
    );
  end if;
  for v_item in select value from jsonb_array_elements(p_sections) loop
    v_line := st_setsrid(st_geomfromgeojson((v_item->'geometry')::text), 4326);
    if geometrytype(v_line) <> 'LINESTRING' or st_isempty(v_line)
        or not st_isvalid(v_line) or st_npoints(v_line) < 2 then
      raise exception 'invalid section line geometry';
    end if;
    insert into public.world_validated_road_sections (
      validated_road_id, section_key, section_order, distance_meters,
      confidence, source_trace_index, source_chunk_index, geometry, created_at
    ) values (
      v_id, v_item->>'section_key', (v_item->>'section_order')::integer,
      (v_item->>'distance_meters')::double precision,
      (v_item->>'confidence')::double precision,
      (v_item->>'source_trace_index')::integer,
      (v_item->>'source_chunk_index')::integer, v_line, now()
    );
  end loop;
  update public.world_publishes
    set validation_claim_token = null, validation_claimed_at = null,
      updated_at = now()
    where id = p_publish_id;
  -- Status deliberately remains processing until a later World Engine stage.
  return jsonb_build_object(
    'state', 'created', 'validated_road_id', v_id,
    'valid_distance_meters', (p_road->>'valid_distance_meters')::double precision,
    'section_count', v_section_count
  );
end;
$$;

create or replace function public.fail_world_publish_validation(
  p_publish_id uuid,
  p_user_id uuid,
  p_claim_token uuid,
  p_retryable boolean,
  p_error_code text
) returns boolean
language plpgsql security definer
set search_path = pg_catalog, extensions, pg_temp
as $$
begin
  if p_error_code !~ '^[a-z0-9_]{1,64}$' then
    raise exception 'invalid error code';
  end if;
  if p_retryable then
    update public.world_publishes
      set status = 'pending', error_code = p_error_code,
        validation_claim_token = null, validation_claimed_at = null,
        updated_at = now()
      where id = p_publish_id and user_id = p_user_id
        and status = 'processing' and validation_claim_token = p_claim_token;
  else
    update public.world_publishes
      set status = 'failed', error_code = p_error_code,
        validation_claim_token = null, validation_claimed_at = null,
        updated_at = now()
      where id = p_publish_id and user_id = p_user_id
        and status = 'processing' and validation_claim_token = p_claim_token;
  end if;
  return found;
end;
$$;

revoke all on function public.claim_world_publish_validation(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.finish_world_publish_validation(
  uuid, uuid, uuid, jsonb, jsonb) from public, anon, authenticated;
revoke all on function public.fail_world_publish_validation(
  uuid, uuid, uuid, boolean, text) from public, anon, authenticated;
grant execute on function public.claim_world_publish_validation(uuid, uuid)
  to service_role;
grant execute on function public.finish_world_publish_validation(
  uuid, uuid, uuid, jsonb, jsonb) to service_role;
grant execute on function public.fail_world_publish_validation(
  uuid, uuid, uuid, boolean, text) to service_role;
commit;
