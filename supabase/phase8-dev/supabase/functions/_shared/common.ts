import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2.117.2";

export const bucket = "phase8-drive-staging";
export const maxObjectBytes = 10 * 1024 * 1024;
export const uuidV4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const sha256Pattern = /^[0-9a-f]{64}$/;

export type AuthenticatedAdmin = { admin: SupabaseClient; userId: string };

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
  });
}

export function failure(code: string, status: number): Response {
  return json({ ok: false, error_code: code }, status);
}

export async function authenticatedAdmin(request: Request): Promise<AuthenticatedAdmin | null> {
  const token = request.headers.get("authorization")?.match(/^Bearer\s+(.+)$/i)?.[1];
  const url = Deno.env.get("SUPABASE_URL");
  const key = resolveAdminKey(Deno.env.get("SUPABASE_SECRET_KEYS"), Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"));
  if (!token || !url || !key) return null;
  const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user?.id || !uuidV4.test(data.user.id)) return null;
  return { admin, userId: data.user.id.toLowerCase() };
}

function resolveAdminKey(secretKeysJson: string | undefined, serviceRoleKey: string | undefined): string | null {
  if (secretKeysJson) {
    try {
      const parsed: unknown = JSON.parse(secretKeysJson);
      if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
        const value = (parsed as Record<string, unknown>).default;
        if (typeof value === "string" && value.trim()) return value.trim();
      }
    } catch { /* Use legacy server-only fallback below. */ }
  }
  return serviceRoleKey?.trim() || null;
}

export async function readJson(request: Request, maxBytes = 32 * 1024): Promise<Record<string, unknown> | null> {
  const stated = Number(request.headers.get("content-length") ?? "0");
  if (stated > maxBytes) return null;
  try {
    const text = await request.text();
    if (new TextEncoder().encode(text).byteLength > maxBytes) return null;
    const value: unknown = JSON.parse(text);
    return value && typeof value === "object" && !Array.isArray(value)
      ? value as Record<string, unknown> : null;
  } catch { return null; }
}

export function isSha256(value: unknown): value is string {
  return typeof value === "string" && sha256Pattern.test(value);
}

export async function sha256Hex(bytes: Uint8Array): Promise<string> {
  // Deno's current WebCrypto BufferSource typing requires an ArrayBuffer-backed
  // view. Copying preserves the exact bytes while excluding SharedArrayBuffer.
  const stableBuffer = new ArrayBuffer(bytes.byteLength);
  new Uint8Array(stableBuffer).set(bytes);
  const digest = await crypto.subtle.digest("SHA-256", stableBuffer);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

// Dart's sync v2 number rendering follows ECMAScript/JCS thresholds. JS
// JSON.stringify uses the same IEEE-754 shortest representation; unsafe integer
// values are rejected before any server persistence.
export function canonicalJson(value: unknown): string {
  if (value === null) return "null";
  if (typeof value === "string") return JSON.stringify(value);
  if (typeof value === "boolean") return value ? "true" : "false";
  if (typeof value === "number") {
    if (!Number.isFinite(value) || (Number.isInteger(value) && !Number.isSafeInteger(value))) {
      throw new Error("canonical_number_invalid");
    }
    return JSON.stringify(Object.is(value, -0) ? 0 : value);
  }
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(",")}]`;
  if (typeof value === "object") {
    const object = value as Record<string, unknown>;
    const keys = Object.keys(object).sort();
    return `{${keys.map((key) => `${JSON.stringify(key)}:${canonicalJson(object[key])}`).join(",")}}`;
  }
  throw new Error("canonical_value_invalid");
}

export async function canonicalSha256(value: unknown): Promise<string> {
  return sha256Hex(new TextEncoder().encode(canonicalJson(value)));
}

export function ownerScope(userId: string): string {
  return JSON.stringify(["local_account_store_v1", "account", userId]);
}

export async function expectedDriveUpsertKey(userId: string, sourceIdentity: string): Promise<string> {
  const scope = ownerScope(userId);
  return `owner-sync-v2:${await sha256Hex(new TextEncoder().encode(`${scope}|${userId}|driveUpsert|${sourceIdentity}`))}`;
}

export async function validateV2DriveEnvelope(
  envelope: unknown,
  expected: { userId: string; sourceIdentity: string; idempotencyKey: string; payloadFingerprint: string },
): Promise<{ driveId: string; mutation: Record<string, unknown> }> {
  if (!envelope || typeof envelope !== "object" || Array.isArray(envelope)) throw new Error("envelope_invalid");
  const mutation = envelope as Record<string, unknown>;
  const payload = mutation.payload;
  const source = mutation.sourceIdentity;
  const scope = ownerScope(expected.userId);
  if (mutation.version !== 2 || mutation.kind !== "driveUpsert" ||
      mutation.ownerId !== expected.userId || mutation.ownerScope !== scope ||
      source !== expected.sourceIdentity || !uuidV4.test(String(source)) ||
      mutation.idempotencyKey !== await expectedDriveUpsertKey(expected.userId, expected.sourceIdentity) ||
      mutation.idempotencyKey !== expected.idempotencyKey ||
      mutation.payloadFingerprint !== expected.payloadFingerprint ||
      !payload || typeof payload !== "object" || Array.isArray(payload)) {
    throw new Error("mutation_claim_mismatch");
  }
  if (await canonicalSha256(payload) !== expected.payloadFingerprint) throw new Error("payload_fingerprint_mismatch");
  const bundle = payload as Record<string, unknown>;
  const drive = bundle.drive as Record<string, unknown> | null;
  const telemetry = bundle.telemetry as Record<string, unknown> | null;
  const provenance = bundle.sourceProvenance as Record<string, unknown> | null;
  const metadata = telemetry?.metadata as Record<string, unknown> | null;
  const route = drive?.route;
  const points = telemetry?.points;
  if (bundle.version !== 2 || bundle.ownerScope !== scope || !drive ||
      typeof drive.id !== "string" || drive.id.length < 1 || drive.id.length > 128 ||
      !telemetry || telemetry.driveId !== drive.id || !Array.isArray(points) || points.length === 0 ||
      !Array.isArray(route) || typeof drive.distance !== "number" || !Number.isFinite(drive.distance) || drive.distance < 0 ||
      !Number.isInteger(drive.durationSeconds) || Number(drive.durationSeconds) < 0 ||
      typeof drive.averageSpeed !== "number" || !Number.isFinite(drive.averageSpeed) || drive.averageSpeed < 0 ||
      typeof drive.maxSpeed !== "number" || !Number.isFinite(drive.maxSpeed) || drive.maxSpeed < 0 ||
      !provenance || provenance.status !== "proven" || provenance.sourceIdentity !== expected.sourceIdentity ||
      provenance.identityVersion !== 1 || provenance.sourceNamespace !== "drive_source_v1" ||
      provenance.ownerScope !== scope || !metadata ||
      metadata.provenanceStatus !== "proven" || metadata.sourceIdentity !== expected.sourceIdentity ||
      metadata.sourceIdentityVersion !== 1 || metadata.sourceNamespace !== "drive_source_v1") {
    throw new Error("provenance_or_bundle_invalid");
  }
  const coordinate = (lat: unknown, lon: unknown) => typeof lat === "number" && Number.isFinite(lat) &&
    Math.abs(lat) <= 90 && typeof lon === "number" && Number.isFinite(lon) && Math.abs(lon) <= 180;
  const finite = (v: unknown) => typeof v === "number" && Number.isFinite(v);
  const count = (v: unknown) => Number.isSafeInteger(v) && Number(v) >= 0;
  const validDate = (v: unknown) => typeof v === "string" && Number.isFinite(Date.parse(v));
  // Reject envelopes that hash correctly but cannot be restored by the Dart
  // LocalSourceBundle/driveTransferManifest readers. Never fill missing data.
  if (!Number.isSafeInteger(drive.dateMicros) || typeof drive.dateIsUtc !== "boolean" ||
      drive.mapImagePath !== "" || provenance.version !== 1 ||
      !Array.isArray(bundle.roads) || bundle.roads.length !== 0 ||
      !("score" in bundle) || telemetry.version !== 1 || !validDate(telemetry.createdAt) ||
      ["stopCount", "stoppedSeconds", "hardBrakeCount", "hardAccelerationCount",
        "sharpTurnCount", "cornerCount"].some((k) => !count(drive[k])) ||
      ["maxAccelerationG", "maxBrakingG", "maxCorneringSpeed", "maxAltitude",
        "altitudeGain"].some((k) => !finite(drive[k])) ||
      ["altitudeLoss", "bestZeroToHundredSeconds", "bestSixtyToHundredSeconds"]
        .some((k) => drive[k] !== null && !finite(drive[k]))) {
    throw new Error("drive_restore_schema_invalid");
  }
  if (bundle.score !== null) {
    const score = bundle.score as Record<string, unknown>;
    if (!score || typeof score !== "object" || Array.isArray(score) ||
        score.driveId !== drive.id || score.algorithm !== 1 ||
        score.telemetryVersion !== telemetry.version || !validDate(score.calculatedAt) ||
        !finite(score.total) || Number(score.total) < 0 || Number(score.total) > 100 ||
        !finite(score.confidence) || Number(score.confidence) < 0 ||
        Number(score.confidence) > 1 || !Array.isArray(score.categories)) {
      throw new Error("score_restore_schema_invalid");
    }
  }
  if (route.some((p) => !p || typeof p !== "object" || !coordinate(
      (p as Record<string, unknown>).latitude, (p as Record<string, unknown>).longitude) ||
      typeof (p as Record<string, unknown>).breakBefore !== "boolean")) {
    throw new Error("drive_geometry_invalid");
  }
  for (const point of points) {
    if (!point || typeof point !== "object") throw new Error("telemetry_invalid");
    const p = point as Record<string, unknown>;
    if (!coordinate(p.lat, p.lng) || !Number.isSafeInteger(p.timeMicros) ||
        !Number.isSafeInteger(p.time) || Math.floor(Number(p.timeMicros) / 1000) !== p.time ||
        typeof p.timeIsUtc !== "boolean" || p.telemetryVersion !== 1 ||
        !finite(p.heading) || !finite(p.altitude) || !finite(p.distance) ||
        Number(p.distance) < 0 || !finite(p.acceleration) ||
        typeof p.speed !== "number" || !Number.isFinite(p.speed) || p.speed < 0 ||
        typeof p.accuracy !== "number" || !Number.isFinite(p.accuracy) || p.accuracy < 0) {
      throw new Error("telemetry_invalid");
    }
  }
  return { driveId: drive.id, mutation };
}

export function bearerError(): Response {
  return failure("unauthorized", 401);
}
