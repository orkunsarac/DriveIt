import {
  canonicalSha256,
  expectedDriveUpsertKey,
  ownerScope,
  validateV2DriveEnvelope,
} from "../functions/_shared/common.ts";

const userId = "11111111-1111-4111-8111-111111111111";
const sourceIdentity = "22222222-2222-4222-8222-222222222222";
const driveId = "r6-contract-drive";
const timestamp = "2026-01-01T00:00:00.000Z";
const timeMs = Date.parse(timestamp);
const timeMicros = timeMs * 1000;

function makePayload(scoreTotal: number): Record<string, unknown> {
  const scope = ownerScope(userId);
  return {
    version: 2,
    ownerScope: scope,
    drive: {
      id: driveId,
      dateMicros: timeMicros,
      dateIsUtc: true,
      distance: 10,
      durationSeconds: 1,
      averageSpeed: 10,
      maxSpeed: 10,
      mapImagePath: "",
      route: [{ latitude: 40, longitude: 30, breakBefore: false }],
      stopCount: 0,
      stoppedSeconds: 0,
      hardBrakeCount: 0,
      hardAccelerationCount: 0,
      sharpTurnCount: 0,
      maxAccelerationG: 0,
      maxBrakingG: 0,
      maxCorneringSpeed: 0,
      cornerCount: 0,
      maxAltitude: 10,
      altitudeGain: 0,
      altitudeLoss: null,
      bestZeroToHundredSeconds: null,
      bestSixtyToHundredSeconds: null,
    },
    telemetry: {
      driveId,
      version: 1,
      createdAt: timestamp,
      metadata: {
        provenanceStatus: "proven",
        sourceIdentity,
        sourceIdentityVersion: 1,
        sourceNamespace: "drive_source_v1",
      },
      points: [{
        lat: 40,
        lng: 30,
        time: timeMs,
        timeMicros,
        timeIsUtc: true,
        telemetryVersion: 1,
        heading: 0,
        altitude: 10,
        distance: 0,
        acceleration: 0,
        speed: 10,
        accuracy: 5,
      }],
    },
    score: {
      driveId,
      algorithm: 1,
      telemetryVersion: 1,
      calculatedAt: timestamp,
      total: scoreTotal,
      confidence: 1,
      categories: [],
    },
    roads: [],
    sourceProvenance: {
      version: 1,
      status: "proven",
      sourceIdentity,
      identityVersion: 1,
      ownerScope: scope,
      sourceNamespace: "drive_source_v1",
      archiveNamespace: null,
      archiveFingerprint: null,
      conflictCode: null,
    },
  };
}

async function makeMutation(scoreTotal: number): Promise<Record<string, unknown>> {
  const payload = makePayload(scoreTotal);
  const scope = ownerScope(userId);
  return {
    version: 2,
    kind: "driveUpsert",
    ownerScope: scope,
    ownerId: userId,
    idempotencyKey: await expectedDriveUpsertKey(userId, sourceIdentity),
    payloadFingerprint: await canonicalSha256(payload),
    sourceIdentity,
    payload,
  };
}

async function validate(mutation: Record<string, unknown>) {
  return await validateV2DriveEnvelope(mutation, {
    userId,
    sourceIdentity,
    idempotencyKey: mutation.idempotencyKey as string,
    payloadFingerprint: mutation.payloadFingerprint as string,
  });
}

async function expectRejected(mutation: Record<string, unknown>): Promise<void> {
  let rejected = false;
  try {
    await validate(mutation);
  } catch {
    rejected = true;
  }
  if (!rejected) throw new Error("expected_mutation_rejection");
}

Deno.test("schema2 Drive Score accepts the canonical 0–1000 range", async () => {
  const mutation = await makeMutation(1000);
  const result = await validate(mutation);
  if (result.driveId !== driveId) throw new Error("drive_id_mismatch");

  const overLimit = await makeMutation(1000.01);
  await expectRejected(overLimit);
  const negative = await makeMutation(-0.01);
  await expectRejected(negative);
});

Deno.test("schema2 score, provenance, telemetry, and fingerprint remain strict", async () => {
  const wrongScore = await makeMutation(250);
  ((wrongScore.payload as Record<string, any>).score).algorithm = 2;
  wrongScore.payloadFingerprint = await canonicalSha256(wrongScore.payload);
  await expectRejected(wrongScore);

  const wrongProvenance = await makeMutation(250);
  ((wrongProvenance.payload as Record<string, any>).sourceProvenance)
    .sourceIdentity = "33333333-3333-4333-8333-333333333333";
  wrongProvenance.payloadFingerprint = await canonicalSha256(wrongProvenance.payload);
  await expectRejected(wrongProvenance);

  const wrongTimestamp = await makeMutation(250);
  ((wrongTimestamp.payload as Record<string, any>).telemetry.points[0])
    .timeMicros += 1000;
  wrongTimestamp.payloadFingerprint = await canonicalSha256(wrongTimestamp.payload);
  await expectRejected(wrongTimestamp);

  const wrongSchema = await makeMutation(250);
  (wrongSchema.payload as Record<string, any>).version = 1;
  wrongSchema.payloadFingerprint = await canonicalSha256(wrongSchema.payload);
  await expectRejected(wrongSchema);

  const wrongFingerprint = await makeMutation(250);
  wrongFingerprint.payloadFingerprint = "0".repeat(64);
  await expectRejected(wrongFingerprint);
});
