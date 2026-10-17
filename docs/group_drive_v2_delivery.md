# Group Drive V2 — lobby and live map

Local candidate on top of M4 checkpoint `741cc7ca23588a720d91432f3fe19c70a3a2d4b7`.
No Planet DEV migration/deploy, APK build, device installation or Git checkpoint
is part of this delivery. The existing working APK remains unchanged.

## Screens and lifetime

`GroupDriveScreen` retains the existing command, consent and error handling.
`GroupDriveEntryView`, `GroupDriveLobbyView` and `GroupDriveLiveView` render the
three stages. Server snapshots determine which view is visible. Open clients
observe start through the existing five-second authenticated snapshot refresh;
no background Activity is opened and no GPS grant is created by starting a ride.

The owner navigator still owns `GroupDriveSession`, its client and GPS consumer.
Home navigation retains an active recorder route below Home rather than popping
and disposing it. Returning to the recorder uses the same route/session, and
GPS consent is not renewed or inferred from navigation. Pause, leave, end,
owner-epoch revocation and explicit background consent retain their M4 behavior.

The live map fills its page, with a SafeArea toolbar and a draggable participant
sheet (compact / 46% / 82%). Self is outside the horizontal list of other members.
Settings expose invite, extension, removal and end only as appropriate to role;
the RPC always performs the authoritative authorization. Android invitation
sharing uses a narrow text-share channel accepting only a DriveIt invite link.

## Server contract and deployment scope

Only new migration `202610170001_phase8_m4_group_lobby.sql` is required.
SHA-256: `D5B3C19E5F1FA357FAFF8C415885D502296928BFE1EEB686B9DD3E7CDAF583A3`.
Existing M1/M2/M4 migration sources are unchanged. No Edge redeploy or global
Realtime policy/configuration change is required: the existing publish Edge
continues to authorize each sample through `phase8_group_accept_location`.

* `ride_phase`: lobby → running → ended, independent of active/ended/expired
  validity. Adding the column first defaults existing groups to running;
  inactive groups become ended, then the default for future creates is lobby.
* Authenticated `start` is administrator-only and idempotent. It changes no
  membership, publication grant or GPS consent. Sharing and location acceptance
  are denied while in a lobby. An active running group still accepts invites.
* `color_index` is a server slot 0–9, unique among active members of a group.
  Existing modulo colors are retained when unique; pre-existing collisions are
  resolved in stable join order. Join takes the group-row lock, selects the
  lowest available slot and relies on a partial unique index as a second fence.
* Existing owner derivation, SECURITY DEFINER search paths, grants, RLS,
  membership, expiry, capacity, generation, sequence and publisher lease checks
  remain in place. No coordinates are added to database tables.

Rollout needs explicit Planet DEV approval followed by remote acceptance and a
coordinated app update. Existing running groups remain usable by the older APK.
New groups created after this migration are lobbies; the older APK has no start
control. Avoid a prolonged interval between server deployment and distributing
the V2 APK. The new adapter rejects a server missing `phase` instead of silently
pretending the old backend supports lobbies. Do not build/distribute V2 against
the unchanged live backend.

## Map rendering

Self is always blue on each device; peers use their server slot in a fixed
ten-color palette, shared by markers and avatars. Initials come exclusively
from that member's display name. There is no substituted profile/photo.

Markers are cached code-drawn PNGs, not default Google pins. Two accepted real
fixes establish movement only when displacement exceeds their combined GPS
uncertainty and at least four metres within the existing fifteen-second window.
Heading comes from these coordinates; no speed/heading field, manufactured GPS
or new server publication protocol is introduced. Uncertain movement remains a
dot. Short 450 ms interpolation smooths established motion; simultaneous member
updates preserve current rendered positions. Expired or revoked fixes disappear
and their map caches are cleared. Nothing is persisted as route history.

Selecting a fresh member enables camera follow. Pointer interaction cancels it.
Fit-all includes only fresh sharing members. Google Maps padding follows the
participant sheet height so focused markers remain above it. Existing 15-second
freshness, three-second future skew and 75-metre accuracy limits are unchanged.

## Verification

Use existing Flutter unit/widget suites, the Phase 8 local pgTAP runner and the
new Deno test in the existing tests directory. The Deno test refuses any URL
other than `http://127.0.0.1:54321`, uses local process-only credentials, creates
its own synthetic Auth accounts, and cleans only their exact group/account IDs.
It exercises real Edge JWT authentication, private Realtime delivery, old open
channel revocation, direct broadcast rejection, concurrent capacity/color slots,
late joining and 15s/75m rejection. No actual user coordinates/accounts are used.

Physical V2 navigation, Android share sheet, Google Maps gestures/appearance
and two-device behavior still require acceptance after approved server rollout.
Prior physical acceptance belongs to the M4 checkpoint, not this new interface.

Local PostgreSQL acceptance: 148/148 pgTAP assertions across five files passed.
Final full Flutter regression: 1046 passed, 2 conditional skips. The active
recorder test includes drive → group → Home → group → same drive/session;
shared foreground GPS, SQLite journal and SDK Realtime decoder tests passed.
The Deno integration test passed on the actual local Edge and Realtime stack,
including authenticated-member direct-broadcast denial, invalid JWT denial,
concurrent ten-person capacity, unique colour slots and open-channel revocation
after pause/ban/leave/end. Test accounts/groups were removed by their exact IDs.
Analyzer has only the existing three archive-test warnings and four infos;
there are no new V2 analyzer findings. No remote acceptance is claimed.
