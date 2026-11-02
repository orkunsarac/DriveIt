import { sourceMatches } from "./source_contract.ts";
import {
  RequestSourceLoader,
  ScoringSourceError,
} from "./world_scoring_stage.ts";
function assert(value: unknown) {
  if (!value) throw new Error("reliable source contract failed");
}
Deno.test("reliable schema is rejected by legacy comparison loader before downloading private source", async () => {
  let downloads = 0;
  const loader = new RequestSourceLoader({
    metadata: async () => [{
      id: "p",
      local_drive_id: "d",
      user_id: "u",
      source_path: "u/p.json",
      source_ready_at: "ready",
      source_schema_version: 2,
      telemetry_version: 1,
      drive_score_algorithm_version: 1,
      world_rules_version: 6,
      raw_route_point_count: 2,
      telemetry_point_count: 2,
    }],
    download: async () => {
      downloads++;
      return {};
    },
  });
  await loader.prepare(["p"]);
  try {
    await loader.load("p", "d");
    throw new Error("unexpected comparison");
  } catch (e) {
    assert(
      e instanceof ScoringSourceError &&
        e.code === "world_score_version_unsupported",
    );
  }
  assert(downloads === 0);
});
Deno.test("unknown source schemas cannot be relabelled as legacy", () => {
  assert(
    !sourceMatches({ schema_version: 99 }, {
      id: "p",
      local_drive_id: "d",
      source_schema_version: 99,
      telemetry_version: 1,
      drive_score_algorithm_version: 1,
      world_rules_version: 6,
      raw_route_point_count: 2,
      telemetry_point_count: 2,
    }),
  );
});
