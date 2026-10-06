import assert from "node:assert/strict";
import test from "node:test";
test("real entrypoint boots with the compiled Dart module without any authenticated invocation",async()=> {
  const original = Deno.serve;
  let handler: ((request:Request)=>Promise<Response>) | undefined;
  // Capture registration only. No listener, authenticated request, DB or Mapbox.
  const runtime=Deno as unknown as {serve:(handler:unknown)=>unknown};
  runtime.serve=(value)=>{handler=value as typeof handler;return {};};
  try { await import('./index.ts'); }
  finally { Deno.serve=original; }
  assert.ok(handler);
  const response=await handler(new Request('http://localhost/',{method:'POST'}));
  assert.equal(response.status,401);
  assert.deepEqual(await response.json(),{ok:false,error_code:'unauthorized'});
});
