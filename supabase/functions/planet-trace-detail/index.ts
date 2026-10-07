import { createClient } from "npm:@supabase/supabase-js@2";
import { resolveAdminKey } from "../process-world-publish/admin_client.ts";
import {
  type Context,
  DetailFailure,
  readDetail,
  SummaryCache,
} from "./detail.ts";
const cache = new SummaryCache();
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json",
      "cache-control": "no-store",
    },
  });
Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ ok: false, error_code: "method_not_allowed" }, 405);
  }
  const token = request.headers.get("Authorization")?.match(/^Bearer (.+)$/i)
    ?.[1];
  if (!token) return json({ ok: false, error_code: "unauthorized" }, 401);
  const url = Deno.env.get("SUPABASE_URL");
  const key = resolveAdminKey(
    Deno.env.get("SUPABASE_SECRET_KEYS"),
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
  );
  if (!url || !key) {
    return json({ ok: false, error_code: "server_not_configured" }, 503);
  }
  const admin = createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  try {
    const auth = await admin.auth.getUser(token);
    if (auth.error || !auth.data.user) {
      return json({ ok: false, error_code: "unauthorized" }, 401);
    }
    let body;
    try {
      body = await request.json();
    } catch {
      throw new DetailFailure("invalid_request", 400);
    }
    if (
      typeof body?.trace_id !== "string" ||
      !/^[0-9a-f]{32}$/.test(body.trace_id)
    ) {
      throw new DetailFailure("invalid_request", 400);
    }
    return json(
      await readDetail(body.trace_id, {
        async context(id) {
          const { data, error } = await admin.rpc(
            "read_planet_trace_detail_context",
            { p_trace_id: id },
          );
          if (error) throw new DetailFailure("detail_lookup_failed");
          return data as Context | null;
        },
        async download(path) {
          const { data, error } = await admin.storage.from(
            "world-drive-sources",
          ).download(path);
          if (error || !data) throw new DetailFailure("source_unavailable");
          if (data.size > 20 * 1024 * 1024) {
            throw new DetailFailure("source_too_large", 422);
          }
          try {
            return JSON.parse(await data.text());
          } catch {
            throw new DetailFailure("source_invalid", 422);
          }
        },
      }, cache),
    );
  } catch (e) {
    const failure = e instanceof DetailFailure
      ? e
      : new DetailFailure("detail_unavailable");
    // Never return/log raw exceptions, identity, headers, source or telemetry.
    return json({ ok: false, error_code: failure.code }, failure.status);
  }
});
