-- Apply only to a newly created isolated HTTP test stack. These statements
-- narrow the clean reference to the observed DEV effective privileges.
BEGIN;
REVOKE DELETE ON public.phase8_drive_leases FROM service_role;
REVOKE DELETE, UPDATE ON public.phase8_drive_tombstones FROM service_role;
REVOKE EXECUTE ON FUNCTION public.phase8_can_access_staging_object(text) FROM service_role;
REVOKE EXECUTE ON FUNCTION public.phase8_group_command(text,uuid,text,uuid,boolean) FROM service_role;
REVOKE EXECUTE ON FUNCTION public.world_section_geometry_length_meters(extensions.geometry) FROM service_role;
COMMIT;
