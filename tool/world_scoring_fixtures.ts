// Synthetic route only. No production source is copied into fixtures.
const point = (meters: number, lateral = 0) => ({ latitude: lateral / 111320,
  longitude: meters / (6371008.8 * Math.PI / 180) });
function make(name: string, firstKind = "poor", secondKind = "good", length = 4000,
  start = 0, end = length) {
  const road = (id: string) => ({ id, driveId: `${id}-drive`, sections: [
    { id: `${id}-section`, distanceMeters: length, geometry: [point(0), point(length)] }] });
  function telemetry(kind: string) {
    return Array.from({ length: Math.floor(length / 10) + 1 }, (_, i) => ({ ...point(i * 10),
      timestamp: new Date(Date.UTC(2026, 9, 6) + i * 10000).toISOString().replace('.000Z', '.000001Z'),
      speed_mps: kind === "poor" ? (i % 2 ? 5 : 25) : 15,
      heading_degrees: 90, altitude_meters: 50, accuracy_meters: 5,
      distance_from_previous_meters: i === 0 ? 0 : 10,
      acceleration_mps2: kind === "poor" ? (i % 2 ? -20 : 20) : 0,
    }));
  }
  return { name, algorithmVersion: 1, match: { firstDriveId: "first-drive", secondDriveId: "second-drive",
    firstSectionId: "first-section", secondSectionId: "second-section",
    firstStartOffsetMeters: start, firstEndOffsetMeters: end,
    secondStartOffsetMeters: start, secondEndOffsetMeters: end,
    commonStart: point(start), commonEnd: point(end), referenceGeometry: [point(start), point(end)],
    commonDistanceMeters: end - start, directionCompatible: true, geometryConfidence: 1,
    comparisonEligible: end - start >= 3000, ownershipCovered: true },
    firstRoad: road("first"), secondRoad: road("second"), firstTelemetry: telemetry(firstKind), secondTelemetry: telemetry(secondKind) };
}
const a = make("A-challenger-better"), b = make("B-incumbent-better", "good", "poor");
const c = make("C-equal", "good", "good"), partial = make("J-partial", "poor", "good", 6000, 1000, 4500);
const short = make("I-under-3km", "poor", "good", 2999);
const version = make("P-version"); version.algorithmVersion = 2;
const reverse = make("N-nonchronological"); reverse.firstTelemetry[10].timestamp = reverse.firstTelemetry[9].timestamp;
const heading60 = make("M-heading-60"); heading60.firstTelemetry.forEach((p) => p.heading_degrees = 150);
const headingOver = make("M-heading-over-60"); headingOver.firstTelemetry.forEach((p) => p.heading_degrees = 150.001);
const lateral35 = make("L-projection-35"); lateral35.firstTelemetry.forEach((p) => p.latitude = 35 / 111320);
const lateralOver = make("L-projection-over-35"); lateralOver.firstTelemetry.forEach((p) => p.latitude = 35.01 / 111320);
const micro = make("N-microseconds", "good", "good");
micro.firstTelemetry[1].timestamp = "2026-10-06T00:00:00.000002Z";
const multi = make("K-multi-section", "poor", "good", 7000, 3000, 7000);
for (const [road, id] of [[multi.firstRoad, "first"], [multi.secondRoad, "second"]] as const) {
  road.sections = [{ id: `${id}-prefix`, distanceMeters: 3000, geometry: [point(0), point(3000)] },
    { id: `${id}-section`, distanceMeters: 4000, geometry: [point(3000), point(7000)] }];
}
const missing = make("R-insufficient"); missing.firstTelemetry = missing.firstTelemetry.slice(0, 1);
function boundary(name: string, kinds: string[]) {
  const c = make(name, "good", "good", kinds.length * 100);
  // First pair scores the whole span; following pairs score exact windows.
  const scores: (number | null)[] = [800,808];
  for (const kind of kinds) scores.push(...(kind === 'win' ? [800,808] :
    kind === 'near' ? [800,807.999] : kind === 'invalid' ? [null,808] : [800,800]));
  return { ...c, scores };
}
const win = (n: number) => Array(n).fill('win'), gap = (n: number) => Array(n).fill('invalid');
const boundaries = [boundary('D-exact-1pct',win(30)), boundary('C-under-1pct',Array(30).fill('near')),
  boundary('E-gap-200',[...win(20),...gap(2),...win(20)]),
  boundary('F-gap-300',[...win(20),...gap(3),...win(20)]),
  boundary('G-region-1900',[...win(19),...Array(11).fill('equal')]),
  boundary('H-region-2000',[...win(20),...Array(10).fill('equal')])];
const canonical = make('SEM-A-geometry4000-canonical5000','good','good',4000,2400,2600);
canonical.firstRoad.sections[0].distanceMeters=5000;
canonical.secondRoad.sections[0].distanceMeters=5000;
const canonicalMulti=structuredClone(multi);canonicalMulti.name='SEM-multi-cumulative';
for(const r of [canonicalMulti.firstRoad,canonicalMulti.secondRoad]) {
  r.sections[0].distanceMeters=5000;r.sections[1].distanceMeters=6000;
}
Object.assign(canonicalMulti.match,{firstStartOffsetMeters:6200,firstEndOffsetMeters:6500,
  secondStartOffsetMeters:6200,secondEndOffsetMeters:6500,commonDistanceMeters:300,comparisonEligible:false});
const canonicalFallback=structuredClone(canonicalMulti);canonicalFallback.name='SEM-prefix-fallback';
for(const r of [canonicalFallback.firstRoad,canonicalFallback.secondRoad])r.sections[0].distanceMeters=0;
Object.assign(canonicalFallback.match,{firstStartOffsetMeters:4200,firstEndOffsetMeters:4500,
  secondStartOffsetMeters:4200,secondEndOffsetMeters:4500});
const cases = [a,b,c,short,partial,version,reverse,heading60,headingOver,lateral35,lateralOver,micro,multi,missing,...boundaries,
  {...canonical,operation:'extract'},{...canonicalMulti,operation:'extract'},{...canonicalFallback,operation:'extract'}];
await Deno.writeTextFile("test/fixtures/active_world_scoring.json", JSON.stringify(cases));
