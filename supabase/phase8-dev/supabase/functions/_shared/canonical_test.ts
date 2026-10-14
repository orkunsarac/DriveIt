import { canonicalJson, canonicalSha256 } from "./common.ts";

function equal(actual: unknown, expected: unknown): void {
  if (actual !== expected) throw new Error(`assertion_failed:${String(actual)}`);
}
function throws(action: () => unknown): void {
  try { action(); } catch { return; }
  throw new Error("expected_throw");
}

Deno.test("phase8 sync v2 canonical JSON sorts keys and uses JCS number form", async () => {
  equal(canonicalJson({ b: 2, a: 1 }), '{"a":1,"b":2}');
  const sharedVector = { z: 1, nested: { b: true, a: [2, 3] }, float: [1.0, -0, 1e-6, 1e-7] };
  const sharedCanonical = '{"float":[1,0,0.000001,1e-7],"nested":{"a":[2,3],"b":true},"z":1}';
  equal(canonicalJson(sharedVector), sharedCanonical);
  equal(await canonicalSha256(sharedVector), "bcc86a6ee01fa4497af3c8fc910d12bdfd6d88bfc70604c75398453d609c1633");
  equal(canonicalJson([1.0, -0, 1e-6, 1e-7]), '[1,0,0.000001,1e-7]');
});

Deno.test("phase8 sync v2 rejects unsafe/non-finite numbers", () => {
  throws(() => canonicalJson({ n: Number.POSITIVE_INFINITY }));
  throws(() => canonicalJson({ n: 9007199254740992 }));
  throws(() => canonicalJson({ n: 1e20 }));
  throws(() => canonicalJson({ n: 1e21 }));
});
