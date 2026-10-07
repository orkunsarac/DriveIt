import { DetailFailure } from "./detail.ts";
Deno.test("entrypoint rejects missing JWT and never exposes private error payload", async () => {
  const serve = Deno.serve;
  let handler: ((r: Request) => Promise<Response>) | undefined;
  Deno.serve = ((h: typeof handler) => {
    handler = h;
    return {} as ReturnType<typeof Deno.serve>;
  }) as typeof Deno.serve;
  try {
    await import("./index.ts");
    const response = await handler!(
      new Request("http://localhost", {
        method: "POST",
        body: JSON.stringify({ trace_id: "a".repeat(32) }),
      }),
    );
    if (
      response.status !== 401 ||
      (await response.text()) !==
        JSON.stringify({ ok: false, error_code: "unauthorized" })
    ) throw new DetailFailure("auth_test_failed");
  } finally {
    Deno.serve = serve;
  }
});
