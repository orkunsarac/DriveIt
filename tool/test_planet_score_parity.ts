// Compares real compiled Dart JS with native Dart, including every category,
// confidence and contribution; receives synthetic fixtures on stdin only.
const fixtures = JSON.parse(await new Response(Deno.stdin.readable).text());
const bundle = Deno.args[0] ??
  "../supabase/functions/planet-trace-detail/score.generated.js";
await import(new URL(bundle, import.meta.url).href);
const calculate = (globalThis as unknown as {
  driveItPlanetDetailScore: (input: string) => string;
}).driveItPlanetDetailScore;
function compare(actual: unknown, expected: unknown, path: string): void {
  if (typeof actual === "number" && typeof expected === "number") {
    if (!Number.isFinite(actual) || Math.abs(actual - expected) > 1e-9) {
      throw new Error(`numeric parity: ${path}`);
    }
    return;
  }
  if (
    actual !== null && expected !== null && typeof actual === "object" &&
    typeof expected === "object"
  ) {
    const a = actual as Record<string, unknown>,
      e = expected as Record<string, unknown>;
    if (
      JSON.stringify(Object.keys(a).sort()) !==
        JSON.stringify(Object.keys(e).sort())
    ) throw new Error(`keys: ${path}`);
    for (const key of Object.keys(e)) compare(a[key], e[key], `${path}.${key}`);
    return;
  }
  if (actual !== expected) throw new Error(`value parity: ${path}`);
}
for (const fixture of fixtures) {
  compare(
    JSON.parse(calculate(JSON.stringify(fixture.input))),
    fixture.expected,
    fixture.name,
  );
  console.log(`PASS ${fixture.name}`);
}
console.log(`Parity: ${fixtures.length}/${fixtures.length} PASS`);
const reliableDifferences = fixtures.filter((
  f: { localReliableDiffers: boolean },
) => f.localReliableDiffers)
  .map((f: { name: string }) => f.name);
console.log(
  `Native reliable-mode differences (not the server v1 contract): ${
    reliableDifferences.join(", ") || "none"
  }`,
);
if (
  Deno.args.includes("--require-legacy-equals-reliable") &&
  reliableDifferences.length > 0
) {
  throw new Error(
    "Local reliable score and Planet legacy v1 are different contracts; version/policy decision required",
  );
}
if (
  Deno.args.includes("--require-local-reliable") &&
  !fixtures.some((f: { input: { schema_version?: number } }) =>
    f.input.schema_version === 2
  )
) {
  throw new Error("Versioned reliable parity fixtures are required");
}
