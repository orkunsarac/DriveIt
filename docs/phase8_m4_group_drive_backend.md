# Phase 8 M4 — Group Drive backend candidate

Status: local implementation candidate only. It has **not** been applied to
Planet DEV and is not enabled in normal DriveIt builds. Do not define
`DRIVEIT_GROUP_DRIVE_ENABLED` until the migration, Edge publish function,
private Realtime policies and two-account acceptance have passed.

## Reused client boundary

`GroupDriveService` / `GroupDriveClient`, `GroupDriveScreen`,
`GroupGpsSharing`, `AndroidGroupGpsSource`, and `GroupDriveMap` remain the
client boundary. `SupabaseGroupDriveService` is the production adapter and
uses the authenticated Planet DEV Supabase client; it is only constructed by
the production factory behind the separate disabled-by-default M4 build flag.
Guest owners are rejected. The factory checks the exact Planet DEV URL. The
existing normal-drive GPS producer, journal, scoring and recovery are not used
for sharing. The Android integration remains visible-app-only.

## Database/Realtime boundary

Migration `202610160004_phase8_m4_group_drive.sql` is additive to the isolated
Phase 8 project tree. It creates private group/membership state, a single
authenticated command RPC, and a service-role-only location authorization RPC.
Auth UID comes from `auth.uid()` in the command RPC; no client-supplied owner
ID is accepted. Capacity and the partial unique active-membership index are
enforced in PostgreSQL. Mutations rotate a generation fence. Coordinates are
validated and returned by the location RPC but are not written to a table;
the Edge function publishes only to the generation-specific private topic.

The `realtime.messages` select policy checks *current* active membership and
the current generation, while there is no client insert policy that permits
broadcast. The publish Edge function authenticates every request, checks the
current membership/publication/generation/sequence/15-second freshness and a
30-second publisher lease in the database, and only then sends transient
Broadcast. The visible group client renews that lease every 10 seconds only
while it still owns the same local lease and local sharing grant. If the app or
owner context disappears, renewal stops and the server rejects the publisher
at lease expiry. Pause, leave, ban, end and
expiry revoke the server publication and rotate the topic generation. Existing
channel authorization may be cached by Realtime, so the server never sends new
locations to the old topic; the client also clears ephemeral points on a
generation change or failed refresh. A five-second refresh is used only while
the group screen is open. No database location history, route, or Presence
payload is created.

## Deployment blockers / risks to resolve before approval

1. Docker Engine was unavailable from this workstation during this task, so
   the migration and pgTAP test were not executed on PostgreSQL. Edge/Deno tests
   and live private-channel revocation have not run.
2. The Planet DEV project must be inspected read-only for existing
   `realtime.messages` policies and the Realtime “Allow public access” setting.
   A broad existing INSERT policy or public-channel access can defeat a
   private-topic-only design. Do not remove/change project-wide settings
   without reviewing impact on existing Planet Realtime features and obtaining
   separate approval if needed.
3. The cleanup/service key remains server-side only. No credential or new
   secret is required in Flutter.
4. Existing M1/M2 migrations and functions are untouched. This migration is
   separate and additive, but it must be checked against the live schema before
   any deployment.

## Host acceptance to run locally

Run existing Phase 8 migrations and `phase8_m4_group_drive.sql` in the isolated
local Supabase project, then execute `phase8_m4_group_drive.sql` from the
isolated tests folder. Also add an Edge test for authenticated transient
publish/revoked generation and a two-client private Realtime acceptance before
Planet DEV approval. The SQL test covers command authorization, capacity
defaults, consent, role, pause generation, no persisted location, and anonymous
denial; it does not by itself prove Realtime delivery or revocation.

No physical-device acceptance, real-user group, or background sharing has been
performed. Group sharing stops when the app is backgrounded; no independent
group-only Android foreground service is included here.
