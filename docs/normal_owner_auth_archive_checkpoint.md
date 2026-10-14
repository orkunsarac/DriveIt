# Normal owner runtime, Auth and device archive checkpoint

Date: 2026-10-15. Branch: `feature/gps-refactor`.

The user has manually verified the normal A55 application: Planet DEV Auth
login/logout, persistent device Guest, separate Guest/account drives,
save/delete/restart persistence, History/Score/World/Career/Profile, and legacy
device archive list/detail/route with real device authentication. The user also
reports successful archive access revocation on screen lock. These are user
acceptance results; they are not newly executed instrumentation tests.

The normal owner runtime is explicitly selected by
`DRIVEIT_LOCAL_OWNER_ACTIVATION=true` and a matching native manifest marker.
The default without that define remains legacy. Normal builds use real GPS
and real Planet DEV Auth (`viqngnjfgknpxtoapzcg`), never fake Auth. Guest identity
is device-persistent. No automatic Guest merge, legacy import, drive cloud
worker, or group backend is activated.

Home now uses the owner navigator's registered `/profile` route, so the actual
Profile menu receives the device archive loader. Archive authorization remains
device-local and epoch-bound. The normal release build helper accepts only an
ignored Planet DEV public client configuration. It rejects secret keys.

Checkpoint validation: `flutter test --timeout=2m` passes 970 tests, with two
conditional skips. Existing archive/owner widget tests cover the actual Home
Profile entry, empty archive, account isolation and revoked contexts. The last
normal A55 APK hash is
`7B1DBED6A0CC6C4366BFAF3C9D734C028D0CFB51F269406E50A9E35F52932303`.

Phase 7 Android diagnostic files and Phase 8 backend candidates remain separate
from this checkpoint. Local credentials, APKs, recovery artifacts, `tatus`,
Android build outputs and Supabase CLI state are excluded.

Deployment risk: local migration version `202610120001` was recorded before
later SQL body corrections. An applied migration is not replayed when its file
changes. A new numbered forward correction must reconcile stored functions;
never reset a database or assume version history proves matching SQL bodies.
No remote schema acceptance is implied by this mobile checkpoint.
