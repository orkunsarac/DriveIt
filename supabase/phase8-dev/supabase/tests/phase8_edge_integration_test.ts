import { createClient } from "npm:@supabase/supabase-js@2.117.2";
import {
  bucket,
  canonicalJson,
  canonicalSha256,
  expectedDriveUpsertKey,
  ownerScope,
  sha256Hex,
} from "../functions/_shared/common.ts";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(`assertion_failed:${message}`);
}

function localClient(url: string, apiKey: string, bearerJwt: string) {
  // Local Supabase 2.120 exposes opaque API keys. They belong in `apikey`,
  // while GoTrue/PostgREST still require a JWT in `Authorization`.
  const fetchWithLocalHeaders: typeof fetch = (input, init) => {
    const headers = new Headers(init?.headers);
    headers.set("apikey", apiKey);
    if (!headers.has("authorization")) headers.set("authorization", `Bearer ${bearerJwt}`);
    return fetch(input, { ...init, headers, signal: init?.signal ?? AbortSignal.timeout(30000) });
  };
  return createClient(url, bearerJwt, {
    global: { fetch: fetchWithLocalHeaders },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

async function responseJson(response: Response): Promise<Record<string, unknown>> {
  return await response.json() as Record<string, unknown>;
}

Deno.test("Phase 8 Edge staging/finalization/download is owner isolated and replay safe", async () => {
  // Remote execution is opt-in and restricted to the explicitly approved
  // Planet DEV project. Defaults remain the existing localhost acceptance.
  const remoteRef = Deno.env.get("PHASE8_REMOTE_PROJECT_REF");
  const remote = remoteRef !== undefined;
  assert(!remote || remoteRef === "viqngnjfgknpxtoapzcg", "remote target must be the approved Planet DEV project");
  const remoteM2 = Deno.env.get("PHASE8_REMOTE_M2_ACCEPTANCE") === "APPROVED_SYNTHETIC_ONLY";
  assert(!remoteM2 || remote, "remote M2 switch requires the exact explicit remote target");
  const url = Deno.env.get("PHASE8_LOCAL_URL");
  const anonKey = Deno.env.get("PHASE8_LOCAL_ANON_KEY");
  const serviceKey = Deno.env.get("PHASE8_LOCAL_SERVICE_ROLE_KEY");
  const anonBearer = Deno.env.get("PHASE8_LOCAL_ANON_BEARER");
  const serviceBearer = Deno.env.get("PHASE8_LOCAL_SERVICE_ROLE_BEARER");
  const cleanupToken = Deno.env.get("PHASE8_LOCAL_CLEANUP_TOKEN");
  assert(url === (remote ? "https://viqngnjfgknpxtoapzcg.supabase.co" : "http://127.0.0.1:54321"),
    "test URL must match the explicitly selected acceptance target");
  assert(anonKey && serviceKey && anonBearer && serviceBearer && (remote || cleanupToken),
    "server-side test credentials are required");

  const admin = localClient(url, serviceKey, serviceBearer);
  const anon = localClient(url, anonKey, anonBearer);
  const runId = crypto.randomUUID();
  if (remote) console.info(`phase8_synthetic_run=${runId}`);
  const password = `P8-${crypto.randomUUID()}-OnlyLocal!`;
  const userAResult = await admin.auth.admin.createUser({
    email: `phase8-a-${runId}@example.invalid`, password, email_confirm: true,
  });
  assert(!userAResult.error && userAResult.data.user, "create synthetic A user");
  const userBResult = await admin.auth.admin.createUser({
    email: `phase8-b-${runId}@example.invalid`, password, email_confirm: true,
  });
  assert(!userBResult.error && userBResult.data.user, "create synthetic B user");
  const userA = userAResult.data.user;
  const userB = userBResult.data.user;
  const clientA = localClient(url, anonKey, anonBearer);
  const clientB = localClient(url, anonKey, anonBearer);
  const signInA = await clientA.auth.signInWithPassword({ email: userA.email!, password });
  const signInB = await clientB.auth.signInWithPassword({ email: userB.email!, password });
  assert(!signInA.error && signInA.data.session, "sign in synthetic A");
  assert(!signInB.error && signInB.data.session, "sign in synthetic B");
  const tokenA = signInA.data.session.access_token;
  const tokenB = signInB.data.session.access_token;

  const existingBucket = await admin.storage.getBucket(bucket);
  if (existingBucket.error) {
    assert(!remote, "remote acceptance must not create or reconfigure a bucket");
    const created = await admin.storage.createBucket(bucket, {
      public: false,
      fileSizeLimit: 10 * 1024 * 1024,
      allowedMimeTypes: ["application/json"],
    });
    assert(!created.error, "create private local staging bucket");
  } else {
    assert(existingBucket.data.public === false, "existing staging bucket must be private");
    assert(existingBucket.data.file_size_limit === 10 * 1024 * 1024,
      "existing staging bucket must enforce the 10 MiB envelope limit");
    assert(JSON.stringify(existingBucket.data.allowed_mime_types) === JSON.stringify(["application/json"]),
      "existing staging bucket must accept only JSON envelopes");
  }
  const bucketReadBack = await admin.storage.getBucket(bucket);
  assert(!bucketReadBack.error && bucketReadBack.data.public === false &&
    bucketReadBack.data.file_size_limit === 10 * 1024 * 1024 &&
    JSON.stringify(bucketReadBack.data.allowed_mime_types) === JSON.stringify(["application/json"]),
    "staging bucket read-back confirms private access, byte limit, and JSON MIME restriction");

  const invoke = (name: string, token: string | null, body: unknown) => fetch(`${url}/functions/v1/${name}`, {
    signal: AbortSignal.timeout(30000),
    method: "POST",
    headers: {
      apikey: anonKey,
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });

  const forbiddenManifestRead = await clientB.from("phase8_drive_manifests").select("source_identity");
  assert(Boolean(forbiddenManifestRead.error), "B cannot bypass Edge through direct manifest access");
  const forbiddenAnonymousRead = await anon.from("phase8_drive_manifests").select("source_identity");
  assert(Boolean(forbiddenAnonymousRead.error), "anonymous direct manifest access is denied");
  const forbiddenOwnerRpc = await clientB.rpc("phase8_drive_sync_capabilities", { p_owner_id: userA.id });
  assert(Boolean(forbiddenOwnerRpc.error), "authenticated client cannot call a service-only RPC with a forged owner");

  const sourceIdentity = crypto.randomUUID();
  const scopeA = ownerScope(userA.id);
  const driveId = `phase8-${runId}`;
  const payload = {
    version: 2,
    ownerScope: scopeA,
    drive: {
      id: driveId,
      dateMicros: 1_700_000_000_000_000, dateIsUtc: true, mapImagePath: "",
      stopCount: 0, stoppedSeconds: 0, hardBrakeCount: 0,
      hardAccelerationCount: 0, sharpTurnCount: 0, cornerCount: 0,
      maxAccelerationG: 0, maxBrakingG: 0, maxCorneringSpeed: 0,
      maxAltitude: 0, altitudeGain: 0, altitudeLoss: null,
      bestZeroToHundredSeconds: null, bestSixtyToHundredSeconds: null,
      route: [{ latitude: 41.01, longitude: 29.01, breakBefore: false },
        { latitude: 41.02, longitude: 29.02, breakBefore: false }],
      distance: 6000,
      durationSeconds: 600,
      averageSpeed: 36,
      maxSpeed: 72,
    },
    telemetry: {
      driveId,
      version: 1, createdAt: "2023-11-14T22:13:20.000Z",
      points: [{ lat: 41.01, lng: 29.01, timeMicros: 1_700_000_000_000_000,
        time: 1_700_000_000_000, timeIsUtc: true, telemetryVersion: 1,
        speed: 10, accuracy: 5, heading: 0, altitude: 0, distance: 0, acceleration: 0 }],
      metadata: {
        provenanceStatus: "proven",
        sourceIdentity,
        sourceIdentityVersion: 1,
        sourceNamespace: "drive_source_v1",
      },
    },
    sourceProvenance: {
      version: 1,
      status: "proven",
      sourceIdentity,
      identityVersion: 1,
      sourceNamespace: "drive_source_v1",
      ownerScope: scopeA,
    },
    score: null,
    roads: [],
  };
  const mutation = {
    version: 2,
    kind: "driveUpsert",
    ownerId: userA.id,
    ownerScope: scopeA,
    sourceIdentity,
    idempotencyKey: await expectedDriveUpsertKey(userA.id, sourceIdentity),
    payloadFingerprint: await canonicalSha256(payload),
    payload,
  };
  const envelope = new TextEncoder().encode(canonicalJson(mutation));
  const objectSha256 = await sha256Hex(envelope);
  const beginBody = {
    ownerId: userA.id,
    ownerScope: scopeA,
    sourceIdentity,
    idempotencyKey: mutation.idempotencyKey,
    contractVersion: 2,
    payloadFingerprint: mutation.payloadFingerprint,
    objectSha256,
    objectBytes: envelope.byteLength,
  };

  const anonymousBegin = await invoke("phase8-drive-begin", null, beginBody);
  assert(anonymousBegin.status === 401, "anonymous begin is denied");
  await anonymousBegin.body?.cancel();
  const spoofedBegin = await invoke("phase8-drive-begin", tokenA, {
    ...beginBody,
    ownerId: userB.id,
    ownerScope: ownerScope(userB.id),
  });
  assert(spoofedBegin.status === 422, "client-supplied other owner is rejected");
  await spoofedBegin.body?.cancel();

  const capabilityResponse = await invoke("phase8-drive-begin", tokenA, { action: "capabilities" });
  assert(capabilityResponse.ok, "authenticated M1 schema capability check");
  const capabilities = await responseJson(capabilityResponse);
  assert(capabilities.contractVersion === 2 && capabilities.schemaRevision === "202610150001" &&
    capabilities.ownerScope === scopeA && capabilities.deleteSync === false,
    "installed M1 clients retain their exact capability contract after M2 upgrade");

  const beginResponse = await invoke("phase8-drive-begin", tokenA, beginBody);
  assert(beginResponse.ok, `authenticated begin accepted (${beginResponse.status})`);
  const beginResult = await responseJson(beginResponse);
  const intentId = String(beginResult.intentId);
  assert(beginResult.state === "staging" && intentId.length > 0, "begin returns staging intent");

  const preFinalizeA = await responseJson(await invoke("phase8-drive-download", tokenA, { action: "begin" }));
  const preFinalizeB = await responseJson(await invoke("phase8-drive-download", tokenB, { action: "begin" }));
  assert(Array.isArray(preFinalizeA.changes) && preFinalizeA.changes.length === 0, "staging object is not visible in A download feed");
  assert(Array.isArray(preFinalizeB.changes) && preFinalizeB.changes.length === 0, "staging object is not visible to B");

  const objectPath = `${userA.id}/${intentId}/envelope.json`;
  const forbiddenRead = await clientB.storage.from(bucket).download(objectPath);
  assert(Boolean(forbiddenRead.error), "B cannot read A's private staged object");
  const anonymousObjectRead = await anon.storage.from(bucket).download(objectPath);
  assert(Boolean(anonymousObjectRead.error), "anonymous client cannot read a staged object");
  const forbiddenWrite = await clientB.storage.from(bucket).upload(objectPath, envelope, {
    contentType: "application/json", upsert: false,
  });
  assert(Boolean(forbiddenWrite.error), "B cannot write A's staging path");

  const upload = await clientA.storage.from(bucket).upload(objectPath, envelope, {
    contentType: "application/json", upsert: false,
  });
  assert(!upload.error, `A can upload its reserved object (${upload.error?.message ?? ""})`);
  // Negative reads must also run AFTER the object exists; a missing object
  // alone is not evidence that private Storage is enforcing owner isolation.
  const existingObjectForB = await clientB.storage.from(bucket).download(objectPath);
  assert(Boolean(existingObjectForB.error), "B cannot read A's existing private staged object");
  const existingObjectForAnon = await anon.storage.from(bucket).download(objectPath);
  assert(Boolean(existingObjectForAnon.error), "anonymous client cannot read an existing private object");

  const finalizeResponse = await invoke("phase8-drive-finalize", tokenA, { intentId });
  assert(finalizeResponse.ok, `finalize succeeds (${finalizeResponse.status})`);
  const finalizeResult = await responseJson(finalizeResponse);
  const receipt = finalizeResult.receipt as Record<string, unknown>;
  assert(receipt.ownerScope === scopeA && receipt.idempotencyKey === mutation.idempotencyKey &&
    receipt.payloadFingerprint === mutation.payloadFingerprint, "ACK is bound to owner/key/fingerprint");

  const replayBegin = await responseJson(await invoke("phase8-drive-begin", tokenA, beginBody));
  assert(replayBegin.state === "finalized" && JSON.stringify(replayBegin.receipt) === JSON.stringify(receipt), "replayed begin returns durable ACK");
  const replayFinalize = await responseJson(await invoke("phase8-drive-finalize", tokenA, { intentId }));
  assert(JSON.stringify(replayFinalize.receipt) === JSON.stringify(receipt), "replayed finalize returns exact ACK");

  const secondSourceIdentity = crypto.randomUUID();
  const secondDriveId = `${driveId}-second`;
  const secondPayload = structuredClone(payload);
  secondPayload.drive.id = secondDriveId;
  secondPayload.telemetry.driveId = secondDriveId;
  secondPayload.telemetry.metadata.sourceIdentity = secondSourceIdentity;
  secondPayload.sourceProvenance.sourceIdentity = secondSourceIdentity;
  const secondMutation = {
    ...mutation,
    sourceIdentity: secondSourceIdentity,
    idempotencyKey: await expectedDriveUpsertKey(userA.id, secondSourceIdentity),
    payloadFingerprint: await canonicalSha256(secondPayload),
    payload: secondPayload,
  };
  const secondEnvelope = new TextEncoder().encode(canonicalJson(secondMutation));
  const secondBegin = await responseJson(await invoke("phase8-drive-begin", tokenA, {
    ...beginBody,
    sourceIdentity: secondSourceIdentity,
    idempotencyKey: secondMutation.idempotencyKey,
    payloadFingerprint: secondMutation.payloadFingerprint,
    objectSha256: await sha256Hex(secondEnvelope),
    objectBytes: secondEnvelope.byteLength,
  }));
  const secondPath = `${userA.id}/${secondBegin.intentId}/envelope.json`;
  const secondUpload = await clientA.storage.from(bucket).upload(secondPath, secondEnvelope, {
    contentType: "application/json", upsert: false,
  });
  assert(!secondUpload.error, "A uploads second page fixture");
  const secondFinalize = await invoke("phase8-drive-finalize", tokenA, { intentId: secondBegin.intentId });
  assert(secondFinalize.ok, "second finalized drive appends next owner sequence");
  await secondFinalize.body?.cancel();

  const conflictResponse = await invoke("phase8-drive-begin", tokenA, {
    ...beginBody,
    objectSha256: "f".repeat(64),
  });
  assert(conflictResponse.status === 409, "same idempotency key with changed hash conflicts");
  await conflictResponse.body?.cancel();

  const secondClientA = localClient(url, anonKey, anonBearer);
  const secondSignInA = await secondClientA.auth.signInWithPassword({ email: userA.email!, password });
  assert(!secondSignInA.error && secondSignInA.data.session, "same owner signs in through an independent second client");
  const downloadA = await responseJson(await invoke("phase8-drive-download", secondSignInA.data.session.access_token, { action: "begin", limit: 1 }));
  assert(downloadA.changes instanceof Array && downloadA.changes.length === 1,
    `A receives one first page response: ${JSON.stringify(downloadA)}`);
  assert(downloadA.next === 1 && downloadA.highWater === 2 && downloadA.hasMore === true, "first page stays bounded below snapshot high-water");
  assert(JSON.stringify(downloadA.changes[0].mutation) === canonicalJson(mutation), "download bytes decode to the exact Dart-compatible canonical mutation");
  const downloadPage2 = await responseJson(await invoke("phase8-drive-download", tokenA, {
    action: "page", cursor: downloadA.nextCursor, limit: 1,
  }));
  assert(downloadPage2.changes instanceof Array && downloadPage2.changes.length === 1 &&
    downloadPage2.next === 2 && downloadPage2.highWater === 2 && downloadPage2.hasMore === false,
    "second page advances exactly to the captured high-water");
  const downloadB = await responseJson(await invoke("phase8-drive-download", tokenB, { action: "begin", limit: 1 }));
  const completedCursor = String(downloadPage2.nextCursor);
  const renewedEmpty = await responseJson(await invoke("phase8-drive-download", tokenA, {
    action: "page", cursor: completedCursor, limit: 1,
  }));
  assert(renewedEmpty.from === 2 && renewedEmpty.next === 2 &&
    renewedEmpty.resumedFromCursor === completedCursor &&
    renewedEmpty.snapshotId !== downloadPage2.snapshotId,
    "completed snapshot renews without resetting committed sequence");

  const thirdSource = crypto.randomUUID();
  const thirdPayload = structuredClone(payload);
  thirdPayload.drive.id = driveId + "-third";
  thirdPayload.telemetry.driveId = thirdPayload.drive.id;
  thirdPayload.telemetry.metadata.sourceIdentity = thirdSource;
  thirdPayload.sourceProvenance.sourceIdentity = thirdSource;
  const thirdMutation = {
    ...mutation, sourceIdentity: thirdSource, payload: thirdPayload,
    idempotencyKey: await expectedDriveUpsertKey(userA.id, thirdSource),
    payloadFingerprint: await canonicalSha256(thirdPayload),
  };
  const thirdBytes = new TextEncoder().encode(canonicalJson(thirdMutation));
  const thirdBegin = await responseJson(await invoke("phase8-drive-begin", tokenA, {
    ...beginBody, sourceIdentity: thirdSource, idempotencyKey: thirdMutation.idempotencyKey,
    payloadFingerprint: thirdMutation.payloadFingerprint,
    objectSha256: await sha256Hex(thirdBytes), objectBytes: thirdBytes.byteLength,
  }));
  const thirdUpload = await clientA.storage.from(bucket).upload(
    userA.id + "/" + thirdBegin.intentId + "/envelope.json", thirdBytes,
    { contentType: "application/json", upsert: false },
  );
  assert(!thirdUpload.error, "stage a drive after the earlier snapshot completed");
  const thirdFinalize = await invoke("phase8-drive-finalize", tokenA, { intentId: thirdBegin.intentId });
  assert(thirdFinalize.ok, "finalize a later committed drive");
  await thirdFinalize.body?.cancel();
  const laterPage = await responseJson(await invoke("phase8-drive-download", tokenA, {
    action: "page", cursor: renewedEmpty.nextCursor, limit: 1,
  }));
  assert(laterPage.from === 2 && laterPage.next === 3 && laterPage.highWater === 3 &&
    Array.isArray(laterPage.changes) && laterPage.changes.length === 1,
    "later sync discovers the new drive instead of remaining pinned to an old snapshot");
  const expired = await admin.from("phase8_drive_snapshots")
    // This is only our synthetic snapshot. Do not assume Windows and the
    // remote Edge/DB clocks agree within one second when expiring a fixture.
    .update({ expires_at: new Date(0).toISOString() })
    .eq("id", downloadA.snapshotId).eq("owner_id", userA.id);
  assert(!expired.error, "expire only the synthetic owner's previous snapshot");
  const recoveredPage = await responseJson(await invoke("phase8-drive-download", tokenA, {
    action: "page", cursor: downloadA.nextCursor, limit: 1,
  }));
  assert(recoveredPage.from === 1 && recoveredPage.next === 2 &&
    recoveredPage.resumedFromCursor === downloadA.nextCursor,
    "expired partial snapshot resumes from the exact committed sequence");
  assert(downloadB.changes instanceof Array && downloadB.changes.length === 0, "B snapshot contains no A mutation");
  const foreignCursor = await invoke("phase8-drive-download", tokenB, {
    action: "page", cursor: downloadA.nextCursor, limit: 1,
  });
  assert(!foreignCursor.ok, "B cannot use A's snapshot cursor");
  await foreignCursor.body?.cancel();

  const missingSource = crypto.randomUUID();
  const missingMutation = { ...mutation, sourceIdentity: missingSource, idempotencyKey: await expectedDriveUpsertKey(userA.id, missingSource) };
  const missingBytes = new TextEncoder().encode(canonicalJson(missingMutation));
  const missingBegin = await responseJson(await invoke("phase8-drive-begin", tokenA, {
    ...beginBody,
    sourceIdentity: missingSource,
    idempotencyKey: missingMutation.idempotencyKey,
    payloadFingerprint: mutation.payloadFingerprint,
    objectSha256: await sha256Hex(missingBytes),
    objectBytes: missingBytes.byteLength,
  }));
  const missingFinalize = await invoke("phase8-drive-finalize", tokenA, { intentId: missingBegin.intentId });
  assert(missingFinalize.status === 409, "missing staged object is not finalized");
  await missingFinalize.body?.cancel();

  const invalidBytes = new TextEncoder().encode('{"not":"a drive envelope"}');
  const invalidSource = crypto.randomUUID();
  const invalidBegin = await responseJson(await invoke("phase8-drive-begin", tokenA, {
    ...beginBody,
    sourceIdentity: invalidSource,
    idempotencyKey: await expectedDriveUpsertKey(userA.id, invalidSource),
    objectSha256: await sha256Hex(invalidBytes),
    objectBytes: invalidBytes.byteLength,
  }));
  const invalidPath = `${userA.id}/${invalidBegin.intentId}/envelope.json`;
  const invalidUpload = await clientA.storage.from(bucket).upload(invalidPath, invalidBytes, {
    contentType: "application/json", upsert: false,
  });
  assert(!invalidUpload.error, "A uploads synthetic invalid envelope to its own reserved staging intent");
  const invalidFinalize = await invoke("phase8-drive-finalize", tokenA, { intentId: invalidBegin.intentId });
  assert(invalidFinalize.status === 422, "malformed envelope is rejected without manifest publication");
  await invalidFinalize.body?.cancel();

  const changedBytes = new TextEncoder().encode("not-the-claimed-content");
  const hashSource = crypto.randomUUID();
  const hashBegin = await responseJson(await invoke("phase8-drive-begin", tokenA, {
    ...beginBody,
    sourceIdentity: hashSource,
    idempotencyKey: await expectedDriveUpsertKey(userA.id, hashSource),
    objectSha256,
    objectBytes: changedBytes.byteLength,
  }));
  const changedPath = `${userA.id}/${hashBegin.intentId}/envelope.json`;
  const changedUpload = await clientA.storage.from(bucket).upload(changedPath, changedBytes, {
    contentType: "application/json", upsert: false,
  });
  assert(!changedUpload.error, "A stages test bytes for hash mismatch case");
  const hashFinalize = await invoke("phase8-drive-finalize", tokenA, { intentId: hashBegin.intentId });
  assert(hashFinalize.status === 422, "object hash mismatch is rejected");
  await hashFinalize.body?.cancel();

  const cleanupAuthFailure = await fetch(`${url}/functions/v1/phase8-drive-cleanup`, {
    method: "POST", headers: { apikey: anonKey, authorization: "Bearer wrong-local-token" },
  });
  assert(cleanupAuthFailure.status === 401, "cleanup rejects a wrong scheduler token");
  await cleanupAuthFailure.body?.cancel();

  if (remote && !remoteM2) {
    // Do not age fixtures or run the global orphan sweep on a shared project.
    // The caller removes ONLY this run's UUID-bound fixtures afterwards.
    const finalObject = await admin.storage.from(bucket).download(objectPath);
    assert(!finalObject.error, "finalized object remains available to server download");
    console.info("phase8_remote_m1_core_acceptance=passed; cleanup_wrong_token=denied; global_orphan_sweep=not_run");
    return;
  }

  const orphanSource = crypto.randomUUID();
  // M2 remote writes require a SECOND explicit synthetic-only switch. The
  // legacy M1 remote command still returns above, without deleting anything.
  const m2Capabilities = await responseJson(await invoke("phase8-drive-begin", tokenA, { action: "capabilities", milestone: 2 }));
  assert(m2Capabilities.deleteSync === true && m2Capabilities.leaseFencing === true, "local M2 explicitly negotiated");
  const observation = await responseJson(await invoke("phase8-drive-delete", tokenA, { action: "observe", sourceIdentity }));
  assert(observation.payload_fingerprint === mutation.payloadFingerprint && observation.change_sequence === 1,
    "M1 source revision is observed, never fabricated");
  const deletionPayload = { deletionId: crypto.randomUUID(), deletedAt: new Date().toISOString(),
    observedRemoteSequence: observation.change_sequence, observedPayloadFingerprint: observation.payload_fingerprint, causalVersion: 1 };
  const deletionMutation = { version: 2, kind: "driveTombstone", ownerId: userA.id, ownerScope: scopeA, sourceIdentity,
    idempotencyKey: `owner-sync-v2:${await sha256Hex(new TextEncoder().encode(`${scopeA}|${userA.id}|driveTombstone|${deletionPayload.deletionId}`))}`,
    payloadFingerprint: await canonicalSha256(deletionPayload), payload: deletionPayload };
  const deniedDeletion = await invoke("phase8-drive-delete", tokenB, { mutation: deletionMutation });
  assert(deniedDeletion.status === 422, "B cannot delete A through verified Auth endpoint");
  await deniedDeletion.body?.cancel();
  const deniedAnonDeletion = await invoke("phase8-drive-delete", null, { mutation: deletionMutation });
  assert(deniedAnonDeletion.status === 401, "anonymous deletion rejected");
  await deniedAnonDeletion.body?.cancel();
  const deleteResult = await responseJson(await invoke("phase8-drive-delete", tokenA, { mutation: deletionMutation }));
  assert(deleteResult.ok === true && canonicalJson(deleteResult.mutation) === canonicalJson(deletionMutation), "atomic deletion receipt");
  const deleteRetry = await responseJson(await invoke("phase8-drive-delete", tokenA, { mutation: deletionMutation }));
  assert(canonicalJson(deleteRetry) === canonicalJson(deleteResult), "lost delete ACK replay is idempotent");
  const oldBegin = await invoke("phase8-drive-begin", tokenA, beginBody);
  assert(oldBegin.status === 409, "offline old upload cannot resurrect source");
  await oldBegin.body?.cancel();
  const oldFinalize = await invoke("phase8-drive-finalize", tokenA, { intentId });
  assert(oldFinalize.status === 409, "finalized ACK shortcut cannot bypass tombstone");
  await oldFinalize.body?.cancel();
  const deletedPage = await responseJson(await invoke("phase8-drive-download", tokenA, { action: "begin", limit: 100 }));
  const deletedChanges = deletedPage.changes as { mutation: { sourceIdentity: string; kind: string } }[];
  const deletedSourceChanges = deletedChanges.filter(c => c.mutation.sourceIdentity === sourceIdentity);
  assert(deletedSourceChanges.length === 2 && deletedSourceChanges.every(c => c.mutation.kind === "driveTombstone"),
    "download never hands out deleted source as live upsert");
  const secondADeletionPage = await responseJson(await invoke("phase8-drive-download", secondSignInA.data.session.access_token, {
    action: "page", cursor: laterPage.nextCursor, limit: 100,
  }));
  assert(secondADeletionPage.from === 3 && secondADeletionPage.next === 4 &&
    Array.isArray(secondADeletionPage.changes) && secondADeletionPage.changes.length === 1 &&
    (secondADeletionPage.changes[0] as { mutation: { kind: string } }).mutation.kind === "driveTombstone",
    "independent A session receives the ordered deletion through its cursor");
  const changedDeletionPayload = { ...deletionPayload, causalVersion: 2 };
  const changedDeletion = await invoke("phase8-drive-delete", tokenA, { mutation: {
    ...deletionMutation, payload: changedDeletionPayload, payloadFingerprint: await canonicalSha256(changedDeletionPayload),
  } });
  assert(changedDeletion.status === 422, "changed causal evidence is rejected, not silently acknowledged");
  await changedDeletion.body?.cancel();
  const tombstoneCount = await admin.from("phase8_drive_tombstones").select("source_identity", { count: "exact" })
    .eq("owner_id", userA.id).eq("source_identity", sourceIdentity);
  assert(!tombstoneCount.error && tombstoneCount.count === 1, "one permanent synthetic tombstone");
  const leaseSource = thirdSource;
  const leaseDevice = crypto.randomUUID();
  const leaseBody = { sourceIdentity: leaseSource, deviceId: leaseDevice, sessionId: "synthetic-local-session", action: "acquire" };
  const acquired = await responseJson(await invoke("phase8-drive-lease", tokenA, leaseBody));
  const lease = acquired.lease as Record<string, unknown>;
  assert(acquired.ok === true && lease.fencing_token === 1, "real lease acquisition");
  if (remoteM2) console.info("phase8_m2_checkpoint=lease_acquired");
  const renewed = await responseJson(await invoke("phase8-drive-lease", tokenA, { ...leaseBody, action: "heartbeat", fencingToken: 1 }));
  const renewal = renewed.lease as Record<string, unknown>;
  assert(renewed.ok === true && renewal.fencing_token === 1 &&
    Date.parse(String(renewal.expires_at)) - Date.parse(String(renewal.heartbeat_at)) === 180000, "heartbeat three minute server expiry");
  if (remoteM2) console.info("phase8_m2_checkpoint=heartbeat_renewed");
  const fenceStarted = performance.now();
  const fenced = await invoke("phase8-drive-lease", tokenA, { ...leaseBody, action: "heartbeat", fencingToken: 2 });
  assert(fenced.status === 409, "wrong fencing token rejected by real Edge/DB");
  const fenceBody = await responseJson(fenced);
  const fenceElapsedMs = Math.round(performance.now() - fenceStarted);
  assert(fenceBody.error_code === "lease_fenced", "Edge preserves the public fencing error contract");
  assert(fenceElapsedMs < 10000, "business fencing conflict returns promptly, without retry timeout");
  console.info(`phase8_fencing_http=${fenced.status}; error_code=${fenceBody.error_code}; elapsed_ms=${fenceElapsedMs}`);
  const rpcStarted = performance.now();
  const rpcFenced = await admin.rpc("phase8_drive_lease", {
    p_owner_id: userA.id, p_source_identity: leaseSource, p_device_id: leaseDevice,
    p_session_id: leaseBody.sessionId, p_action: "heartbeat", p_fencing_token: 2,
  });
  const rpcElapsedMs = Math.round(performance.now() - rpcStarted);
  assert(rpcFenced.status === 409 && rpcFenced.error?.code === "PT409" &&
    rpcFenced.error.message === "lease_fenced" && rpcElapsedMs < 10000,
    "PostgREST application SQLSTATE returns HTTP 409 without transaction retry");
  console.info(`phase8_fencing_rpc_http=${rpcFenced.status}; sqlstate=${rpcFenced.error.code}; elapsed_ms=${rpcElapsedMs}`);
  if (remoteM2) console.info("phase8_m2_checkpoint=wrong_fence_rejected");
  const expireLease = await admin.from("phase8_drive_leases").update({
    heartbeat_at: new Date(0).toISOString(), expires_at: new Date(180000).toISOString(),
  }).eq("owner_id", userA.id).eq("source_identity", leaseSource).eq("device_id", leaseDevice)
    .eq("fencing_token", 1).select("source_identity");
  assert(!expireLease.error && expireLease.data?.length === 1, "expire only this run's synthetic lease, without waiting or clock assumptions");
  if (remoteM2) console.info("phase8_m2_checkpoint=synthetic_lease_expired");
  const expiredHeartbeat = await invoke("phase8-drive-lease", tokenA, { ...leaseBody, action: "heartbeat", fencingToken: 1 });
  assert(expiredHeartbeat.status === 409, "expired lease heartbeat is rejected");
  await expiredHeartbeat.body?.cancel();
  const nextDevice = crypto.randomUUID();
  const takeover = await responseJson(await invoke("phase8-drive-lease", tokenA, {
    ...leaseBody, deviceId: nextDevice, sessionId: "synthetic-successor", action: "acquire",
  }));
  assert(takeover.ok === true && (takeover.lease as Record<string, unknown>).fencing_token === 2, "takeover increments server fencing token");
  const staleFinalize = await invoke("phase8-drive-finalize", tokenA, {
    intentId: thirdBegin.intentId, deviceId: leaseDevice, sessionId: leaseBody.sessionId, fencingToken: 1,
  });
  assert(staleFinalize.status === 409, "stale device epoch cannot replay finalized ACK");
  await staleFinalize.body?.cancel();
  const currentFinalize = await invoke("phase8-drive-finalize", tokenA, {
    intentId: thirdBegin.intentId, deviceId: nextDevice, sessionId: "synthetic-successor", fencingToken: 2,
  });
  assert(currentFinalize.ok, "current fenced session replays one durable ACK");
  await currentFinalize.body?.cancel();
  if (remoteM2) {
    // Keep immutable deletion/fencing evidence. Operational cleanup disables
    // only this run's A account and removes B/unfinalized temporary objects.
    console.info(`phase8_remote_m2_acceptance=passed; retained_evidence_run=${runId}; global_cleanup=not_run`);
    return;
  }

  const orphanBytes = new TextEncoder().encode("synthetic-stale-staging-object");
  const orphanBeginResponse = await invoke("phase8-drive-begin", tokenA, {
    ...beginBody,
    sourceIdentity: orphanSource,
    idempotencyKey: await expectedDriveUpsertKey(userA.id, orphanSource),
    objectSha256: await sha256Hex(orphanBytes),
    objectBytes: orphanBytes.byteLength,
  });
  assert(orphanBeginResponse.ok, "A reserves a synthetic cleanup fixture");
  const orphanBegin = await responseJson(orphanBeginResponse);
  const orphanIntentId = String(orphanBegin.intentId);
  const orphanPath = `${userA.id}/${orphanIntentId}/envelope.json`;
  const orphanUpload = await clientA.storage.from(bucket).upload(orphanPath, orphanBytes, {
    contentType: "application/json", upsert: false,
  });
  assert(!orphanUpload.error, "A uploads the synthetic orphan object");
  const staleTimestamp = new Date(Date.now() - 8 * 24 * 60 * 60 * 1000).toISOString();
  const ageOrphan = await admin.from("phase8_drive_upload_intents")
    .update({ last_activity_at: staleTimestamp })
    .eq("id", orphanIntentId);
  assert(!ageOrphan.error, "local service role ages only the synthetic orphan fixture");

  const cleanup = await fetch(`${url}/functions/v1/phase8-drive-cleanup`, {
    method: "POST", headers: { apikey: anonKey, authorization: `Bearer ${cleanupToken}` },
  });
  assert(cleanup.ok, "cleanup endpoint accepts only the local scheduler token");
  const cleanupResult = await responseJson(cleanup);
  assert(cleanupResult.expired === 1 && cleanupResult.retryable === 0,
    "cleanup removes and expires the stale staging intent");
  const removedOrphan = await admin.storage.from(bucket).download(orphanPath);
  assert(Boolean(removedOrphan.error), "cleanup removes the stale private object");
  const orphanState = await admin.from("phase8_drive_upload_intents")
    .select("state").eq("id", orphanIntentId).single();
  assert(!orphanState.error && orphanState.data.state === "expired", "cleanup durably marks stale intent expired");
  const finalObject = await admin.storage.from(bucket).download(objectPath);
  assert(!finalObject.error, "cleanup leaves finalized staging content available to server download");
});
