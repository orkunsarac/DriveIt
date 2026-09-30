export const publishColumns = [
  "id",
  "user_id",
  "local_drive_id",
  "status",
  "source_path",
  "source_ready_at",
  "source_schema_version",
  "telemetry_version",
  "drive_score_algorithm_version",
  "world_rules_version",
  "raw_route_point_count",
  "telemetry_point_count",
].join(",");

/** New hosted Edge Functions expose secret keys as a JSON dictionary. */
export function resolveAdminKey(
  secretKeysJson: string | undefined,
  legacyServiceRoleKey: string | undefined,
): string | null {
  if (secretKeysJson) {
    try {
      const keys: unknown = JSON.parse(secretKeysJson);
      if (keys && typeof keys === "object" && !Array.isArray(keys)) {
        const value = (keys as Record<string, unknown>).default;
        if (typeof value === "string" && value.trim()) return value.trim();
      }
    } catch {
      // Ignore malformed/missing new-format config and allow legacy fallback.
    }
  }
  return legacyServiceRoleKey?.trim() || null;
}

type PostgrestErrorFields = {
  code: string | null;
  message: string | null;
  details: string | null;
  hint: string | null;
};

function safeText(value: unknown): string | null {
  return typeof value === "string" ? value : null;
}

export function postgrestErrorFields(error: unknown): PostgrestErrorFields {
  if (!error || typeof error !== "object") {
    return { code: null, message: null, details: null, hint: null };
  }
  const fields = error as Record<string, unknown>;
  return {
    code: safeText(fields.code),
    message: safeText(fields.message),
    details: safeText(fields.details),
    hint: safeText(fields.hint),
  };
}

export function publishLookupFailure(error: unknown): Response {
  console.error(JSON.stringify({
    operation: "world_publish_lookup",
    ...postgrestErrorFields(error),
  }));
  return new Response(
    JSON.stringify({ ok: false, error_code: "publish_lookup_failed" }),
    { status: 503, headers: { "content-type": "application/json; charset=utf-8" } },
  );
}
