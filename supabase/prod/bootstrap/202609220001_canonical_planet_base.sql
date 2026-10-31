-- Canonical Planet DEV schema-only archive SHA256: bdbdcac292e9ce2116db82e33325fdfd2e343bc158896fde8c69c48e538ab687
-- Live function bodies verified; no data dump used.
begin;
create extension if not exists postgis with schema extensions;
CREATE TABLE IF NOT EXISTS "public"."world_publishes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "local_drive_id" "text" NOT NULL,
    "started_at" timestamp with time zone NOT NULL,
    "ended_at" timestamp with time zone NOT NULL,
    "distance_meters" double precision NOT NULL,
    "world_rules_version" integer NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "error_code" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "processed_at" timestamp with time zone,
    "source_path" "text",
    "source_schema_version" integer,
    "telemetry_version" integer,
    "drive_score_algorithm_version" integer,
    "raw_route_point_count" integer,
    "telemetry_point_count" integer,
    "source_ready_at" timestamp with time zone,
    "validation_claim_token" "uuid",
    "validation_claimed_at" timestamp with time zone,
    CONSTRAINT "world_publishes_distance_meters_check" CHECK (("distance_meters" >= (0)::double precision)),
    CONSTRAINT "world_publishes_drive_score_algorithm_version_check" CHECK ((("drive_score_algorithm_version" IS NULL) OR ("drive_score_algorithm_version" > 0))),
    CONSTRAINT "world_publishes_raw_route_point_count_check" CHECK ((("raw_route_point_count" IS NULL) OR ("raw_route_point_count" > 0))),
    CONSTRAINT "world_publishes_source_schema_version_check" CHECK ((("source_schema_version" IS NULL) OR ("source_schema_version" > 0))),
    CONSTRAINT "world_publishes_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'processing'::"text", 'published'::"text", 'failed'::"text"]))),
    CONSTRAINT "world_publishes_telemetry_point_count_check" CHECK ((("telemetry_point_count" IS NULL) OR ("telemetry_point_count" >= 2))),
    CONSTRAINT "world_publishes_telemetry_version_check" CHECK ((("telemetry_version" IS NULL) OR ("telemetry_version" > 0))),
    CONSTRAINT "world_publishes_valid_time" CHECK (("ended_at" >= "started_at"))
);

CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "username" "text",
    "display_name" "text",
    "avatar_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "username_format_check" CHECK ((("username" IS NULL) OR ("username" ~ '^[a-z0-9_]{3,20}$'::"text")))
);

CREATE TABLE IF NOT EXISTS "public"."world_validated_road_sections" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "validated_road_id" "uuid" NOT NULL,
    "section_key" "text" NOT NULL,
    "section_order" integer NOT NULL,
    "distance_meters" double precision NOT NULL,
    "confidence" double precision,
    "source_trace_index" integer NOT NULL,
    "source_chunk_index" integer NOT NULL,
    "geometry" "extensions"."geometry"(LineString,4326) NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "world_validated_road_sections_confidence_check" CHECK ((("confidence" IS NULL) OR (("confidence" >= (0)::double precision) AND ("confidence" <= (1)::double precision)))),
    CONSTRAINT "world_validated_road_sections_distance_meters_check" CHECK (("distance_meters" >= (0)::double precision)),
    CONSTRAINT "world_validated_road_sections_section_order_check" CHECK (("section_order" >= 0)),
    CONSTRAINT "world_validated_road_sections_source_chunk_index_check" CHECK (("source_chunk_index" >= 0)),
    CONSTRAINT "world_validated_road_sections_source_trace_index_check" CHECK (("source_trace_index" >= 0))
);

CREATE TABLE IF NOT EXISTS "public"."world_validated_roads" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "publish_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "provider_id" "text" NOT NULL,
    "processing_version" integer NOT NULL,
    "valid_distance_meters" double precision NOT NULL,
    "validation_status" "text" NOT NULL,
    "confidence" double precision,
    "direction_key" "text" NOT NULL,
    "average_heading_degrees" double precision,
    "section_count" integer NOT NULL,
    "geometry" "extensions"."geometry"(MultiLineString,4326) NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "world_validated_roads_confidence_check" CHECK ((("confidence" IS NULL) OR (("confidence" >= (0)::double precision) AND ("confidence" <= (1)::double precision)))),
    CONSTRAINT "world_validated_roads_processing_version_check" CHECK (("processing_version" > 0)),
    CONSTRAINT "world_validated_roads_section_count_check" CHECK (("section_count" > 0)),
    CONSTRAINT "world_validated_roads_valid_distance_meters_check" CHECK (("valid_distance_meters" >= (0)::double precision)),
    CONSTRAINT "world_validated_roads_validation_status_check" CHECK (("validation_status" = ANY (ARRAY['validated'::"text", 'partially_validated'::"text"])))
);

CREATE OR REPLACE FUNCTION "public"."attach_world_publish_source"("p_publish_id" "uuid", "p_source_schema_version" integer, "p_telemetry_version" integer, "p_drive_score_algorithm_version" integer, "p_raw_route_point_count" integer, "p_telemetry_point_count" integer) RETURNS "public"."world_publishes"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_user_id uuid;
  v_source_path text;
  v_result public.world_publishes;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if p_source_schema_version <= 0
     or p_telemetry_version <= 0
     or p_drive_score_algorithm_version <= 0
     or p_raw_route_point_count <= 0
     or p_telemetry_point_count < 2 then
    raise exception 'Invalid source metadata';
  end if;

  v_source_path :=
    v_user_id::text || '/' ||
    p_publish_id::text || '.json';

  if not exists (
    select 1
    from storage.objects
    where bucket_id = 'world-drive-sources'
      and name = v_source_path
  ) then
    raise exception 'Published drive source file not found';
  end if;

  update public.world_publishes
  set
    source_path = v_source_path,
    source_schema_version = p_source_schema_version,
    telemetry_version = p_telemetry_version,
    drive_score_algorithm_version = p_drive_score_algorithm_version,
    raw_route_point_count = p_raw_route_point_count,
    telemetry_point_count = p_telemetry_point_count,
    source_ready_at = now()
  where id = p_publish_id
    and user_id = v_user_id
    and status = 'pending'
    and source_path is null
  returning * into v_result;

  if not found then
    raise exception 'Publish is unavailable or source is already attached';
  end if;

  return v_result;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  insert into public.profiles (
    id,
    username,
    display_name
  )
  values (
    new.id,
    nullif(lower(trim(new.raw_user_meta_data ->> 'username')), ''),
    nullif(trim(new.raw_user_meta_data ->> 'display_name'), '')
  );

  return new;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."is_username_available"("candidate" "text") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
  select
    candidate is not null
    and lower(trim(candidate)) ~ '^[a-z0-9_]{3,20}$'
    and not exists (
      select 1
      from public.profiles
      where username = lower(trim(candidate))
    );
$_$;

CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;

ALTER TABLE "public"."world_publishes" OWNER TO "postgres";

ALTER TABLE "public"."profiles" OWNER TO "postgres";

ALTER TABLE "public"."world_validated_road_sections" OWNER TO "postgres";

ALTER TABLE "public"."world_validated_roads" OWNER TO "postgres";

ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_username_key" UNIQUE ("username");

ALTER TABLE ONLY "public"."world_publishes"
    ADD CONSTRAINT "world_publishes_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."world_publishes"
    ADD CONSTRAINT "world_publishes_source_path_key" UNIQUE ("source_path");

ALTER TABLE ONLY "public"."world_publishes"
    ADD CONSTRAINT "world_publishes_unique_drive" UNIQUE ("user_id", "local_drive_id");

ALTER TABLE ONLY "public"."world_validated_road_sections"
    ADD CONSTRAINT "world_validated_road_sections_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."world_validated_road_sections"
    ADD CONSTRAINT "world_validated_road_sections_unique_key" UNIQUE ("validated_road_id", "section_key");

ALTER TABLE ONLY "public"."world_validated_road_sections"
    ADD CONSTRAINT "world_validated_road_sections_unique_order" UNIQUE ("validated_road_id", "section_order");

ALTER TABLE ONLY "public"."world_validated_roads"
    ADD CONSTRAINT "world_validated_roads_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."world_validated_roads"
    ADD CONSTRAINT "world_validated_roads_publish_id_key" UNIQUE ("publish_id");

CREATE INDEX "world_publishes_status_created_at_idx" ON "public"."world_publishes" USING "btree" ("status", "created_at");

CREATE INDEX "world_publishes_user_id_idx" ON "public"."world_publishes" USING "btree" ("user_id");

CREATE INDEX "world_validated_road_sections_geometry_idx" ON "public"."world_validated_road_sections" USING "gist" ("geometry");

CREATE UNIQUE INDEX "world_validated_road_sections_order_unique" ON "public"."world_validated_road_sections" USING "btree" ("validated_road_id", "section_order");

CREATE INDEX "world_validated_road_sections_road_idx" ON "public"."world_validated_road_sections" USING "btree" ("validated_road_id");

CREATE INDEX "world_validated_roads_geometry_idx" ON "public"."world_validated_roads" USING "gist" ("geometry");

CREATE UNIQUE INDEX "world_validated_roads_publish_id_unique" ON "public"."world_validated_roads" USING "btree" ("publish_id");

CREATE INDEX "world_validated_roads_user_id_idx" ON "public"."world_validated_roads" USING "btree" ("user_id");

ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."world_publishes"
    ADD CONSTRAINT "world_publishes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."world_validated_road_sections"
    ADD CONSTRAINT "world_validated_road_sections_validated_road_id_fkey" FOREIGN KEY ("validated_road_id") REFERENCES "public"."world_validated_roads"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."world_validated_roads"
    ADD CONSTRAINT "world_validated_roads_publish_id_fkey" FOREIGN KEY ("publish_id") REFERENCES "public"."world_publishes"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."world_validated_roads"
    ADD CONSTRAINT "world_validated_roads_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;

ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."world_publishes" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."world_validated_road_sections" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."world_validated_roads" ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE TRIGGER "on_auth_user_created" AFTER INSERT ON "auth"."users" FOR EACH ROW EXECUTE FUNCTION "public"."handle_new_user"();

CREATE OR REPLACE TRIGGER "profiles_set_updated_at" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "world_publishes_set_updated_at" BEFORE UPDATE ON "public"."world_publishes" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "world_validated_roads_set_updated_at" BEFORE UPDATE ON "public"."world_validated_roads" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE POLICY "Authenticated users can read profiles" ON "public"."profiles" FOR SELECT TO "authenticated" USING (true);

CREATE POLICY "Users can create own pending world publishes" ON "public"."world_publishes" FOR INSERT TO "authenticated" WITH CHECK (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND ("status" = 'pending'::"text")));

CREATE POLICY "Users can read own validated road sections" ON "public"."world_validated_road_sections" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."world_validated_roads" "road"
  WHERE (("road"."id" = "world_validated_road_sections"."validated_road_id") AND ("road"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))));

CREATE POLICY "Users can read own validated roads" ON "public"."world_validated_roads" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));

CREATE POLICY "Users can read own world publishes" ON "public"."world_publishes" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));

CREATE POLICY "Users can update own profile" ON "public"."profiles" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "id"));

CREATE POLICY "Users can upload own world drive sources" ON "storage"."objects" FOR INSERT TO "authenticated" WITH CHECK ((("bucket_id" = 'world-drive-sources'::"text") AND (("storage"."foldername"("name"))[1] = ( SELECT ("auth"."uid"())::"text" AS "uid"))));
revoke all on table public.profiles, public.world_publishes, public.world_validated_roads, public.world_validated_road_sections from public, anon, authenticated, service_role;
ALTER FUNCTION "public"."attach_world_publish_source"("p_publish_id" "uuid", "p_source_schema_version" integer, "p_telemetry_version" integer, "p_drive_score_algorithm_version" integer, "p_raw_route_point_count" integer, "p_telemetry_point_count" integer) OWNER TO "postgres";

ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";

ALTER FUNCTION "public"."is_username_available"("candidate" "text") OWNER TO "postgres";

ALTER FUNCTION "public"."set_updated_at"() OWNER TO "postgres";

GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."world_publishes" TO "service_role";

GRANT SELECT ON TABLE "public"."world_publishes" TO "authenticated";

GRANT INSERT("local_drive_id") ON TABLE "public"."world_publishes" TO "authenticated";

GRANT INSERT("started_at") ON TABLE "public"."world_publishes" TO "authenticated";

GRANT INSERT("ended_at") ON TABLE "public"."world_publishes" TO "authenticated";

GRANT INSERT("distance_meters") ON TABLE "public"."world_publishes" TO "authenticated";

GRANT INSERT("world_rules_version") ON TABLE "public"."world_publishes" TO "authenticated";

REVOKE ALL ON FUNCTION "public"."attach_world_publish_source"("p_publish_id" "uuid", "p_source_schema_version" integer, "p_telemetry_version" integer, "p_drive_score_algorithm_version" integer, "p_raw_route_point_count" integer, "p_telemetry_point_count" integer) FROM PUBLIC;

GRANT ALL ON FUNCTION "public"."attach_world_publish_source"("p_publish_id" "uuid", "p_source_schema_version" integer, "p_telemetry_version" integer, "p_drive_score_algorithm_version" integer, "p_raw_route_point_count" integer, "p_telemetry_point_count" integer) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."is_username_available"("candidate" "text") FROM PUBLIC;

GRANT ALL ON FUNCTION "public"."is_username_available"("candidate" "text") TO "anon";

GRANT ALL ON FUNCTION "public"."is_username_available"("candidate" "text") TO "authenticated";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."profiles" TO "service_role";

GRANT SELECT ON TABLE "public"."profiles" TO "authenticated";

GRANT UPDATE("username") ON TABLE "public"."profiles" TO "authenticated";

GRANT UPDATE("display_name") ON TABLE "public"."profiles" TO "authenticated";

GRANT UPDATE("avatar_url") ON TABLE "public"."profiles" TO "authenticated";

GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."world_validated_road_sections" TO "service_role";

GRANT SELECT ON TABLE "public"."world_validated_road_sections" TO "authenticated";

GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."world_validated_roads" TO "service_role";

GRANT SELECT ON TABLE "public"."world_validated_roads" TO "authenticated";
commit;
