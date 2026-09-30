import assert from "node:assert/strict";
import test from "node:test";
import {
  postgrestErrorFields,
  publishColumns,
  publishLookupFailure,
  resolveAdminKey,
} from "./admin_client.ts";

test("hosted secret dictionary default key takes precedence", () => {
  assert.equal(
    resolveAdminKey('{"default":"new-server-key","other":"other-key"}', "legacy-key"),
    "new-server-key",
  );
});

test("legacy service role key remains a fallback", () => {
  assert.equal(resolveAdminKey(undefined, " legacy-server-key "), "legacy-server-key");
  assert.equal(resolveAdminKey("{malformed", "legacy-server-key"), "legacy-server-key");
  assert.equal(resolveAdminKey(undefined, undefined), null);
});

test("publish lookup columns match the server-side source contract", () => {
  assert.deepEqual(publishColumns.split(","), [
    "id", "user_id", "local_drive_id", "status", "source_path",
    "source_ready_at", "source_schema_version", "telemetry_version",
    "drive_score_algorithm_version", "world_rules_version",
    "raw_route_point_count", "telemetry_point_count",
  ]);
});

test("lookup DB failure is safely logged and returns the stable 503 payload", async () => {
  const previous = console.error;
  const logs: string[] = [];
  console.error = (...values: unknown[]) => logs.push(values.join(" "));
  try {
    const response = publishLookupFailure({
      code: "42501",
      message: "permission denied for table world_publishes",
      details: "safe database detail",
      hint: "safe hint",
      jwt: "jwt-must-not-leak",
      apiKey: "key-must-not-leak",
      source: { telemetry: "source-must-not-leak" },
    });
    assert.equal(response.status, 503);
    assert.deepEqual(await response.json(), {
      ok: false,
      error_code: "publish_lookup_failed",
    });
    assert.equal(logs.length, 1);
    const log = JSON.parse(logs[0]);
    assert.deepEqual(Object.keys(log).sort(), [
      "code", "details", "hint", "message", "operation",
    ]);
    assert.equal(log.operation, "world_publish_lookup");
    assert.equal(log.code, "42501");
    assert.equal(log.message, "permission denied for table world_publishes");
    assert.equal(log.details, "safe database detail");
    assert.equal(log.hint, "safe hint");
    assert.doesNotMatch(logs[0], /jwt-must-not-leak|key-must-not-leak|source-must-not-leak/);
  } finally {
    console.error = previous;
  }
});

test("PostgREST fields are allowlisted rather than serializing the error object", () => {
  assert.deepEqual(postgrestErrorFields({ code: "PGRST204", secret: "private" }), {
    code: "PGRST204", message: null, details: null, hint: null,
  });
});
