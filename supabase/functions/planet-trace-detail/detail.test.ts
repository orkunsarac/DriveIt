import {
  type Context,
  DetailFailure,
  readDetail,
  summarize,
  SummaryCache,
} from "./detail.ts";
import { rules } from "../process-world-publish/world_validation.ts";
function assert(value: unknown) {
  if (!value) throw new Error("assertion failed");
}
function fixture() {
  const context: Context = {
    generation: "4",
    trace_id: "a".repeat(32),
    ownership_distance_meters: 250,
    display_name: "Test Sürücü",
    username: "test_driver",
    publish: {
      id: "publish",
      user_id: "owner",
      local_drive_id: "drive",
      source_path: "owner/publish.json",
      source_ready_at: "2026-01-01",
      source_schema_version: 1,
      telemetry_version: 1,
      drive_score_algorithm_version: rules.driveScoreAlgorithmVersion,
      world_rules_version: rules.worldRulesVersion,
      raw_route_point_count: 2,
      telemetry_point_count: 120,
    },
  };
  const source = {
    publish_id: "publish",
    local_drive_id: "drive",
    schema_version: 1,
    telemetry_version: 1,
    drive_score_algorithm_version: rules.driveScoreAlgorithmVersion,
    world_rules_version: rules.worldRulesVersion,
    started_at: "2026-01-01T00:00:00Z",
    ended_at: "2026-01-01T00:02:00Z",
    recorded_distance_meters: 1000,
    raw_route: [{ latitude: 40, longitude: 29 }, {
      latitude: 40,
      longitude: 29.01,
    }],
    canonical_telemetry: Array.from(
      { length: 120 },
      (_, i) => ({
        latitude: 40,
        longitude: 29 + i * .0001,
        timestamp: new Date(Date.parse("2026-01-01T00:00:00Z") + i * 1000)
          .toISOString(),
        speed_mps: 10,
        heading_degrees: 90,
        altitude_meters: 50,
        accuracy_meters: 5,
        distance_from_previous_meters: i ? 10 : 0,
        acceleration_mps2: 0,
      }),
    ),
  };
  return { context, source };
}
Deno.test("full-source metrics, genuine Dart score, partial ownership and privacy", async () => {
  const { context, source } = fixture();
  const response = await readDetail(context.trace_id, {
    context: async () => context,
    download: async () => source,
  }, new SummaryCache());
  assert(
    response.distance_meters === 1000 && response.duration_seconds === 120,
  );
  assert(
    Math.abs(response.average_speed_kmh - 30) < 1e-10 &&
      response.maximum_speed_kmh === 36,
  );
  assert(response.ownership_distance_meters === 250);
  const score = response.score as {
    displayScore: number;
    categories: Record<string, unknown>;
  };
  assert(
    Number.isInteger(score.displayScore) &&
      Object.keys(score.categories).length === 7,
  );
  // Native oracle tool/planet_detail_oracle.dart, identical synthetic telemetry.
  assert(score.displayScore === 711);
  assert(
    Math.abs((response.score as { totalScore: number }).totalScore - 711.475) <
      1e-10,
  );
  const body = JSON.stringify(response);
  for (
    const privateField of [
      "canonical_telemetry",
      "source_path",
      "user_id",
      "raw_route",
      "local_drive_id",
      "email",
      "diagnostics",
      "processing_version",
    ]
  ) {
    assert(!body.includes(privateField));
  }
});
Deno.test("summary cache avoids repeat source/scoring while ownership/profile revalidate", async () => {
  const { context, source } = fixture();
  let downloads = 0, reads = 0;
  const cache = new SummaryCache();
  const gateway = {
    context: async () => {
      reads++;
      return context;
    },
    download: async () => {
      downloads++;
      return source;
    },
  };
  await readDetail(context.trace_id, gateway, cache);
  context.generation = "5";
  context.display_name = "Changed";
  const second = await readDetail(context.trace_id, gateway, cache);
  assert(
    downloads === 1 && reads === 4 && second.generation === "5" &&
      second.display_name === "Changed",
  );
});
Deno.test("retired during calculation rejected; unknown trace never downloads", async () => {
  const { context, source } = fixture();
  let reads = 0, downloads = 0;
  try {
    await readDetail(context.trace_id, {
      context: async () => ++reads === 1 ? context : null,
      download: async () => {
        downloads++;
        return source;
      },
    }, new SummaryCache());
    throw new Error("not rejected");
  } catch (e) {
    assert(
      e instanceof DetailFailure && e.code === "trace_retired" &&
        e.status === 410,
    );
  }
  try {
    await readDetail("unknown", {
      context: async () => null,
      download: async () => {
        downloads++;
        return source;
      },
    }, new SummaryCache());
  } catch (e) {
    assert(e instanceof DetailFailure && e.code === "trace_retired");
  }
  assert(downloads === 1);
});
Deno.test("missing profile allowed, corrupt/mismatched source safely rejected", async () => {
  const { context, source } = fixture();
  context.display_name = null;
  context.username = null;
  const response = await readDetail(context.trace_id, {
    context: async () => context,
    download: async () => source,
  }, new SummaryCache());
  assert(response.display_name === null && response.username === null);
  for (
    const bad of [null, {}, { ...source, publish_id: "other" }, {
      ...source,
      ended_at: source.started_at,
    }]
  ) {
    try {
      summarize(bad, context);
      throw new Error("not rejected");
    } catch (e) {
      assert(e instanceof DetailFailure && e.code === "source_invalid");
    }
  }
});
Deno.test("cache bounded/TTL, duplicate read coalescing, failed entry not cached", async () => {
  let now = 0, loads = 0;
  const cache = new SummaryCache(1, 10, () => now);
  const { context, source } = fixture();
  const load = async () => {
    loads++;
    return summarize(source, context);
  };
  await Promise.all([cache.get("a", load), cache.get("a", load)]);
  assert(loads === 1);
  await cache.get("b", load);
  await cache.get("a", load);
  assert(loads === 3);
  now = 20;
  await cache.get("a", load);
  assert(loads === 4);
  try {
    await cache.get("failure", async () => {
      throw new Error("private data");
    });
  } catch { /* safe */ }
  await cache.get("failure", load);
  assert(loads === 5);
});
Deno.test("RPC is server-only, active published predicate, minimal profile projection", async () => {
  const sql = await Deno.readTextFile(
    new URL(
      "../../migrations/202610070001_planet_trace_detail_read.sql",
      import.meta.url,
    ),
  );
  assert(
    sql.includes("from public,anon,authenticated") &&
      sql.includes("to service_role"),
  );
  assert(
    sql.includes("w.status='published'") &&
      sql.includes("s.current_generation"),
  );
  assert(
    !sql.includes("p.email") && !sql.includes("insert into") &&
      !sql.includes("update public"),
  );
});
Deno.test("long drive remains bounded public response, no route/telemetry leaks", () => {
  const { context, source } = fixture();
  source.canonical_telemetry = Array.from(
    { length: 12000 },
    (_, i) => ({
      ...source.canonical_telemetry[i % 120],
      timestamp: new Date(Date.parse(source.started_at) + i * 1000)
        .toISOString(),
      longitude: 29 + i * .00001,
    }),
  );
  context.publish.telemetry_point_count = 12000;
  source.ended_at = "2026-01-01T03:20:00Z";
  source.recorded_distance_meters = 120000;
  const response = summarize(source, context);
  assert(
    response.duration_seconds === 12000 &&
      JSON.stringify(response).length < 2048,
  );
});
Deno.test("generated score bundle matches normalized Dart dependency hashes", async () => {
  const manifest = JSON.parse(
    await Deno.readTextFile(new URL("./score.manifest.json", import.meta.url)),
  );
  async function hash(url: URL) {
    const text = (await Deno.readTextFile(url)).replaceAll("\r\n", "\n");
    const digest = await crypto.subtle.digest(
      "SHA-256",
      new TextEncoder().encode(text),
    );
    return Array.from(
      new Uint8Array(digest),
      (b) => b.toString(16).padStart(2, "0"),
    ).join("");
  }
  assert(
    await hash(new URL("./score.generated.js", import.meta.url)) ===
      manifest.artifact_sha256,
  );
  for (const [path, expected] of Object.entries(manifest.sources)) {
    assert(
      await hash(new URL("../../../" + path, import.meta.url)) === expected,
    );
  }
});
