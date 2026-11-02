import {ownerScope} from '../../phase8-dev/supabase/functions/_shared/common.ts';
export function cloudFixture(owner:string,sourceIdentity:string,driveId:string){
const scopeA=ownerScope(owner);
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
return payload;
}
