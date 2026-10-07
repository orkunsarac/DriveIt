const sql=await Deno.readTextFile(new URL('../../migrations/202610060003_planet_map_read.sql',import.meta.url));
function assert(v:boolean){if(!v)throw new Error('Planet read contract regression');}
Deno.test('Planet read is authenticated and contains only minimal map properties',()=>{
 assert(sql.includes("auth.uid() is null")&&sql.includes("from public,anon;"));
 assert(sql.includes('to authenticated,service_role;'));
 const payload=sql.slice(sql.indexOf("'geometry',extensions.ST_AsGeoJSON")-200,sql.indexOf('into result'));
 assert(!/telemetry|source_path|email|user_id/.test(payload));
 assert(!/update public|insert into public|delete from public/.test(sql));
});
Deno.test('one STABLE snapshot, current partial GiST predicate, bounded work and dateline boxes',()=>{
 assert(sql.includes('language plpgsql stable security definer'));
 assert(sql.includes('active_to_generation is null and active_from_generation<=g'));
 assert(sql.includes('bounds && box1')&&sql.includes('bounds && box2'));
 assert(sql.includes('limit 201')&&sql.includes('vertices>100000')&&sql.includes('1048576'));
 assert(sql.includes('p_zoom<10')&&sql.includes('order by trace_id'));
});
Deno.test('canonical cumulative and spherical interpolation are not planar substring/rounding',()=>{
 assert(sql.includes('order by section_order loop'));
 assert(sql.includes('world_section_geometry_length_meters(p_line)'));
 assert(sql.includes('(start_offset_meters-prefix)/len'));
 assert(!sql.includes('ST_LineSubstring(')&&!sql.includes('round('));
});
Deno.test('optimized clipping retains spherical ordered accumulation and source endpoints',async()=>{
 const optimized=await Deno.readTextFile(new URL('../../migrations/202610060004_planet_clip_set_based.sql',import.meta.url));
 assert(optimized.includes('6371008.8')&&optimized.includes('sum(distance) over(order by seq rows'));
 assert(optimized.includes('array_agg(point order by seq,priority)'));
 assert(!optimized.includes('round(')&&!optimized.includes('ST_LineSubstring('));
});
