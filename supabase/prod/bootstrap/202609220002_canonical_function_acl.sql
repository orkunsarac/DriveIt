-- Reconcile managed default EXECUTE grants with live canonical metadata.
begin;
revoke all on function public.attach_world_publish_source(p_publish_id uuid, p_source_schema_version integer, p_telemetry_version integer, p_drive_score_algorithm_version integer, p_raw_route_point_count integer, p_telemetry_point_count integer) from public,anon,authenticated,service_role;
grant execute on function public.attach_world_publish_source(p_publish_id uuid, p_source_schema_version integer, p_telemetry_version integer, p_drive_score_algorithm_version integer, p_raw_route_point_count integer, p_telemetry_point_count integer) to authenticated;
revoke all on function public.handle_new_user() from public,anon,authenticated,service_role;
grant execute on function public.handle_new_user() to PUBLIC;
revoke all on function public.is_username_available(candidate text) from public,anon,authenticated,service_role;
grant execute on function public.is_username_available(candidate text) to anon;
grant execute on function public.is_username_available(candidate text) to authenticated;
revoke all on function public.set_updated_at() from public,anon,authenticated,service_role;
grant execute on function public.set_updated_at() to PUBLIC;
commit;
