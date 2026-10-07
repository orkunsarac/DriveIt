// Private inputs only on stdin, never argv/disk/stdout. Read-only diagnostic.
import {
  type Context,
  readDetail,
  SummaryCache,
} from "../supabase/functions/planet-trace-detail/detail.ts";
const input = JSON.parse(await new Response(Deno.stdin.readable).text());
const start = performance.now();
try {
  const context = input.context as Context;
  const cache = new SummaryCache();
  let downloads = 0;
  const gateway = {
    context: async () => context,
    download: async () => {
      downloads++;
      return input.source;
    },
  };
  const summary = await readDetail(context.trace_id, gateway, cache);
  const scoreMs = performance.now() - start;
  const second = performance.now();
  await readDetail(context.trace_id, gateway, cache);
  console.log(
    JSON.stringify({
      score_ms: scoreMs,
      warm_summary_ms: performance.now() - second,
      source_loads: downloads,
      ...summary,
    }),
  );
} catch {
  console.log(JSON.stringify({ error_code: "acceptance_failed" }));
  Deno.exit(1);
}
