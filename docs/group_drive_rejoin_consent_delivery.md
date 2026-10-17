# Group Drive V2: rejoin, membership consent and compact controls

## Confirmed cause and forward repair

The existing `phase8_group_command` keeps a LEFT membership row, but JOIN
inserts another row with the same `(group_id, account_id)`. The regression
reproduced PostgreSQL 23505 against the real local database before the fix.

New migration `202610170002_phase8_m4_group_rejoin.sql` replaces only this
RPC. A LEFT membership is reactivated with a fresh membership UUID, member
role, join time/order, free color slot, sharing OFF and cleared publication,
publisher expiry, sequence and sample time. BANNED membership is rejected
explicitly. Rejoin rotates the group generation and preserves the group-row
lock, capacity, actor advisory lock, Auth UID, administrator transfer,
SECURITY DEFINER, empty search path and existing EXECUTE grants.

No deployed migration source was edited. The predecessor migration 001
remains SHA-256 `D5B3C19E5F1FA357FAFF8C415885D502296928BFE1EEB686B9DD3E7CDAF583A3`.
The new migration SHA-256 is
`AC9A6EA99D906BDC105FA4EAE7BA033BDFE2FD1AC0859B06C4831564C936F56F`.

The fake service also retains ban decisions. Client messages now distinguish
membership conflict/ban, command transport failure and Realtime channel failure.
The existing SDK channel teardown/recreation passed leave/rejoin regression.

## Explicit sharing approval

Create and join ask separately for sharing with the group and Android location
permission. Users can continue without sharing. Optional background permission
remains a separate unchecked choice using the existing foreground GPS source.

Approval lives only in the navigator-owned GPS consumer's memory, scoped to
owner lease, group and membership UUID. LOBBY creates no GPS subscription.
On a RUNNING snapshot, an approved visible client starts once. The same approval
is used by explicit Pause/Resume. No service is started automatically while the
application is hidden. Leave, membership replacement, owner change, session
close or missing authorization clears approval. A pending Android permission
reply cannot authorize a replacement membership. Restart never restores it.

No GPS age/accuracy/mock filters, journal format or publication wire payload
were changed. Normal recording and group GPS remain independent consumers.

## Presentation

Five equally sized SafeArea controls show Geri, Duraklat/Devam, Sürüş, Çık and
Ayarlar, with tooltips and existing callbacks. The 320px ten-member test checks
their alignment, widths and lack of overflow. The bottom participant panel,
self-pinned avatar, colors and camera behavior remain in place.

Arrow/dot artwork is scaled to 22/36 of its prior size (39% smaller). The original
36px bitmap canvas is preserved with transparent padding for marker selection.
PNG raster/cache, motion estimation, animation, color and freshness stay intact.

## Local backend verification and deployment boundary

Only the existing isolated local stack `driveit-phase8-dev` was used. The new
migration was applied with the official CLI `migration up --local`, without
reset, ledger repair or data cleanup. PostgreSQL pgTAP results:

| Suite | Passed |
| --- | ---: |
| M4 group security | 31 |
| V2 lobby | 16 |
| Rejoin | 22 |
| M1 security | 45 |
| M2 security | 34 |
| Staging cancellation | 22 |
| Total | 170 |

The existing Deno local Edge/Realtime test passed with real synthetic Auth
sessions. It now covers BANNED rejoin rejection, LEFT rejoin with a new
membership, delivery on its new private channel, and no new delivery to its
still-open old channel. It also retains JWT, broadcast denial, pause/ban/leave/
end, concurrent capacity, color uniqueness and 15s/75m checks. Cleanup targeted
only exact synthetic group/account IDs created by that test.

This is local backend acceptance, not remote or physical-device acceptance.
Final full Flutter regression: 1059 passed, 2 conditional skips. The final
focused GPS/service/UI suite passed 50/50; SDK adapter and recorder navigation
regressions also passed. Analysis retains the pre-existing three archive-test
warnings and four infos, with no new findings. `git diff --check` passed.

Planet DEV deployment requires explicit user approval for migration 002 only,
target `viqngnjfgknpxtoapzcg`. No Edge redeploy, global Realtime setting,
Auth/Storage policy change or M1/M2 migration is required.

No remote mutation, APK installation, Git commit/push, or OneDrive copy was
performed. A new normal release APK and two-device manual acceptance follow
the approved backend update; the existing APK must not be treated as containing
these changes.
