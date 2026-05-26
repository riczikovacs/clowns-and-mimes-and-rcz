# Changelog

This project follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and uses [Semantic Versioning](https://semver.org/).

When cutting a release: rename the `[Unreleased]` heading below to the version being tagged (for example `[0.1.0]`) and open a fresh `[Unreleased]` block above it. Bump `application/config/version` in `game/project.godot` to match the tag so the client's update-check popup compares against the right local version. The release workflow extracts the section under the heading that matches the tag (e.g. tag `v0.1.0` -> heading `[0.1.0]`) and uses it as the GitHub Release body.

## [Unreleased]

## [0.3.4] - 2026-05-26

Movement fix: the body can no longer get permanently pinned at the edge of a wall.

### Fixed

- `pathCrossesWall` (and its `path_crosses_wall` GDScript mirror) no longer rejects every move when the body has ended up just inside the WALL*CLEARANCE band (~5 cm short of clearance). The old logic checked both the start and end positions against clearance, so a single fast tick whose end landed at distance 0.55 m from a wall left the body unable to slide along the wall or even move away from it. The new logic still blocks segment intersections and any move whose end is \_deeper* than the start, but accepts parallel slides and escape moves so a pinned body can recover. Regression test exercises the four cases (parallel, away, deeper, tunnel-through).

## [0.3.3] - 2026-05-25

Reliability + polish: mid-game disconnects are no longer instant boots to the menu, and the update-available popup has a fixed footprint.

### Added

- Periodic 5 s WebSocket keepalive ping from the arena. `room_client.send_ping()` has been a no-op exported method for a while; nothing called it, so idle players had no traffic on the socket and were the first to get retired by Cloudflare's Durable Object lifecycle. The arena now pings on a 5 s accumulator while online so the connection stays warm.
- Reconnect ladder on transient WebSocket drops. When the server-side socket dies (TLS fatal alert, DO migration, brief ISP blip) the arena now shows a centered "Reconnecting..." banner and tries to re-open the WS at 0.5 s, 1.5 s, and 3.0 s offsets before giving up. Most transient drops resolve in that window and the player never sees a menu bounce. If all three attempts fail, a small popup offers "Reconnect" or "Back to menu" instead of force-routing the player out.

### Changed

- Update-available popup (both the soft main-menu variant and the hard `version_mismatch` variant in the arena) is now non-resizable. Previously the modal had a draggable corner that left an empty stretched region below the buttons.
- `room_client.connect_to` and `disconnect_from` clear the internal send queue. Without this, a reconnect would flush stale enqueued inputs from the previous session as soon as the new socket opened.

## [0.3.2] - 2026-05-25

Network smoothness: the local player no longer micro-stutters relative to walls while moving, remote players glide instead of hitching when packets arrive late, and the menu now warns the player when a newer build is out.

### Added

- Update-available popup. On main-menu launch, the client checks the GitHub releases API and pops a small modal with a "Get latest" button that opens the website when the local build is older than the latest published release. Network failures are swallowed silently so offline players are not nagged. Same modal in a hard "Update required" variant fires in the arena if the server closes the connection with `version_mismatch` (PROTOCOL_VERSION bump).
- `application/config/version` now travels with the build (`game/project.godot`). `VersionCheck.local_version()` reads it via `ProjectSettings`. The release recipe at the top of this file reminds the next release cut to bump this in lockstep with the tag.

### Changed

- Local player prediction is now bound to the 60 Hz physics tick (matches what the server applies) and `_process` interpolates the rendered body transform between consecutive ticks for high-refresh-rate smoothness. Previously the prediction advanced every render frame (often 144 Hz) but inputs were queued only at the 60 Hz physics tick, which meant any server delta arriving mid-tick replayed one input short of the prediction and popped the body backward by ~5 cm.
- Remote players now render from a fixed-delay snapshot buffer (the Quake / Source "entity interpolation" pattern). Each body is rendered at `now - 100 ms` and interpolated within the buffered history between the two snapshots that bracket that virtual time. Network jitter inside the 100 ms window is invisible. Topology seam crossings (and large server teleports) are detected by step length and snap rather than lerping through the playfield.
- Reconciliation no longer hard-snaps: when the server's authoritative position diverges from the local prediction by a few cm, the next render frames lerp from the current visual position to the corrected target across one tick window, turning a visible pop into a smooth slide.

### Removed

- Playtest-era diagnostics that had outlived their purpose: `[contact-no-fire]`, `[tag-rejected]`, `[unfreeze-rejected]` stdout prints and their throttling state.

## [0.3.1] - 2026-05-25

Lobby and HUD polish: typing a code that no host created no longer drops the player into a fake offline room, free-roam announces itself as a centered DISPERSE banner, and the various wire-flavoured strings that leaked into the UI are now sentences a player can read.

### Added

- Centered "DISPERSE!" banner flashes when the free-roam phase begins, reusing the same label the team battle cries use. Replaces the small left-side event-log line that previously read `free_roam` verbatim.

### Changed

- Lobby code input on the main menu rewrites to upper-case as the player types. The matchmaker uppercased the URL anyway; the field now matches.
- Website copy: the rules list says "Thirty seconds to wander before tags count" to match the actual free-roam window (previously said sixty).
- Matchmaker client error strings are now player-readable sentences. 400 maps to topology / request hints, 404 to "Lobby not found", 429 to a rate-limit notice, 5xx to a server-down notice. Internal labels like `matchmaker returned 404` no longer leak into the lobby status line.

### Fixed

- Typing an arbitrary lobby code no longer falls through to offline-vs-bots. The matchmaker's 404 routes through a new `lobby_not_found` signal that the lobby surfaces as a hard error and bounces back to the menu, instead of pretending the room existed. Matchmaker-unreachable and 5xx failures still fall back to offline play.
- HUD countdown blanks the label when the active phase has no turn-end time (filling phase, or one frame at the boundary where a turn just expired). Previously rendered a stuck `0`.

## [0.3.0] - 2026-05-25

Topology lineup rebuilt around the Möbius strip (rendered as its orientation double cover), with the sphere and double-torus surfaces removed. Spawn placement now rejects positions inside walls and inside other players.

### Added

- Möbius strip topology, rendered as the orientation double cover. X wraps as a plain cylinder; the Möbius twist is baked into the maze geometry (the right half of the cover is the z-mirror of the left), so seam crossings are visually continuous with no live flip event. Bot pathfinding, HUD pretty-name, dropdown entry, and website fundamental-polygon card all included.
- Spawn placement now rejects candidates that sit inside a wall (using the same clearance the runtime collision check uses) and candidates that overlap any existing player (separation of one player diameter plus a small buffer). A deterministic hex-spiral fallback handles dense team areas where random jitter keeps landing on an occupied cell. Bot stuck-in-wall recovery routes through the same validator.

### Changed

- Wall list emitter for the Möbius cover now uses separate `cellX` / `cellZ` for the two axes, matching what the bot pathfinder already assumed; previously the strip's z cells were sized wrong and half the maze fell outside the playfield bounds.
- Cover-seam walls (Möbius col `2N-1` east when the maze keeps it closed) now emit at both `x = +halfX` and `x = -halfX`. `pathCrossesWall` operates on pre-wrap coordinates so the seam wall needs to appear at both ends of the cover for collision to catch the player approaching from either side.
- Möbius fundamental DFS now uses the Möbius row-flip on the x-wrap (col `N-1`'s east neighbour is col `0` at row `rows-1-r`). The cylinder-wrap variant left the cover's middle-seam openings misaligned, producing visible-vs-walkable disagreements and occasionally unreachable islands.
- HUD event log pre-allocates a fixed-size pool of labels and stops calling `add_child` / `queue_free` per event. The previous per-event node churn locked up the client in long playtests.

### Removed

- Sphere topology (both cube T-net and the later rhombicuboctahedron variant). Corner singularities at the face meetings produced collision and rendering artefacts that no nudge or tessellation refinement settled cleanly.
- Double torus / genus-2 topology. The fundamental polygon is a regular octagon, but the surface's universal cover is hyperbolic, so no Euclidean rendering is visually continuous at the vertex meeting where the eight octagon corners all identify to a single cone point. The edge-portal preview hid the artefact most of the time but it surfaced under play. Lineup is now plane, torus, Möbius strip, Klein bottle.

### Fixed

- macOS notarization no longer passes `--timeout` to `notarytool submit`; Apple's queue can take hours under load and the explicit timeout was killing otherwise-successful submissions.
- macOS code-signing now signs nested binaries first, then the `.app` bundle (inside-out), instead of using `--deep`. Entitlements include `allow-jit`, `allow-unsigned-executable-memory`, and `disable-library-validation`, which Godot needs for its scripting host.

## [0.2.0] - 2026-05-24

Online play overhaul: client-side prediction with server reconciliation, 60 Hz server tick, Klein bottle redesigned as a true double cover, sprint hysteresis, smoother bot motion and routing, and a host lobby that gives you time to share the code.

### Added

- Client-side prediction with server reconciliation for the local player. Each input is buffered with its seq number; on every delta the client snaps to the server's authoritative position at the ack and replays the unacked inputs through the same shared `stepMovement` math. Eliminates the 30-plus unit attacker/server divergence that was rejecting tag attempts on direct contact.
- 60 Hz server tick and matching 60 Hz client input cadence. Reconciliation corrections now arrive every ~16.7 ms with proportionally smaller snaps; previous 50 ms windows were visible as per-delta judder.
- Render-rate local-player prediction. `_advance_local_prediction` runs in `_process` (variable, vsync-tied) and the vsync mode switched to mailbox so a 120 Hz panel hits its refresh ceiling.
- True Klein bottle as a 2W x W double cover. The right half of the maze is the z-mirror of the left half so the bottle's orientation flip is walkable space rather than an instantaneous teleport at the seam.
- Wrap-tile visual clones for torus, Klein, and sphere. Players standing at a seam see the wrapped content instead of a void edge.
- Topology label on the HUD ("on the Klein Bottle", etc.) so playtesters know which surface is active.
- Host lobby keeps the code on screen with Copy and Start buttons; clipboard via `DisplayServer.clipboard_set`.
- Bots route around stationary bodies. `BotPathfinder.nextWaypointAvoiding(...)` treats every other player's cell as solid for the chase/rescue BFS, so a frozen enemy in a corridor no longer pins the bot.
- Bot direction smoothing: wrap-aware `wrappedUnitDelta` keeps movement headings consistent across seams; yaw is interpolated with a per-tick angular-velocity cap so slide-fallback corners don't snap the avatar 90 degrees.
- Sprint hysteresis. Once sprint depletes to 0 it stays in walk until energy regens past `SPRINT_ENGAGE_THRESHOLD` (20). Holding shift past the 0-energy line no longer oscillates between WALK_SPEED and SPRINT_SPEED at the tick rate.
- Smart matchmaker is a Durable Object now: humans-first open-room routing with live human/bot counts, no cross-edge race for newly opened rooms.
- Humans displace bots from their preferred team when they join, so a late human always lands on a human-friendly roster.
- Server-side lag compensation rewinds victim position for client tag attempts; `tag_result.reason` carries specific rejection codes (`out_of_range:<dist>`, `not_your_turn`, `wall_in_way`, `same_team`, ...) so the HUD and diagnostics surface why a tag missed.

### Changed

- Movement math lives in `@cm/shared/movement` and is mirrored verbatim in `game/scripts/movement.gd`. Both server `simulateHumans` and client predictor call the same `stepMovement`, so reconciliation replay lands on the same position the server computed.
- `input.move` on the wire is now world-space XZ (rotated by yaw on the client). Reconciliation replay no longer needs to remember historical yaw per input.
- `RoomPhase` drops the pre-match countdown. `filling` goes straight to `free_roam` then `turn_mime` / `turn_clown`, with a 30 s free-roam window.
- Lobby code rendering: the seeded "10" countdown placeholder is gone; the label stays blank until the first phase update arrives.
- HUD event log capped to 5 lines with a fade gradient on older entries.
- Open-lobby route stamps the chosen topology onto the wsUrl so the Room DO applies the correct topology before the first client connects (fixed everyone landing on plane).
- Website drops the lede tagline above the download poster.

### Fixed

- Tagging within contact range against humans now succeeds; the previous client/server position drift was causing `out_of_range` rejections at near-zero player distance.
- Bot rescue no longer stalls behind a frozen enemy in the corridor; routes around via the new avoid-set BFS.
- Bot motion no longer jitters near wrap seams (Euclidean delta replaced with wrap-aware delta).
- Klein wrap renders smoothly: no instant z-flip on x-seam crossings.
- Sphere wrap tiles render the playfield neighbors instead of a void edge.
- Server stops re-applying already-consumed inputs when the client falls a tick behind, so reconciliation no longer snaps backward each delta.

### Known follow-ups

- macOS code signing and notarization once the Apple Developer ID is wired into CI (Apple Team ID is on hand).
- Strict cube-net adjacency for sphere (current wrap is a torus-style approximation).

## [0.1.2] - 2026-05-24

Re-cuts v0.1.1 with the macOS installer attached. The 0.1.1 macOS build failed at export because the preset was configured for App Store distribution, which requires a signing identity we do not have.

### Fixed

- macOS export preset switched from distribution_type=2 (App Store) to 0 (Testing), so the universal binary exports without an Apple Developer ID. Users will need to clear the quarantine xattr to launch the unsigned build on first run.

## [0.1.1] - 2026-05-24

First release with all three platform installers planned. v0.1.0 failed to publish a macOS asset because Godot 4 refuses universal/arm64 exports unless ETC2 ASTC import is enabled in the project; that setting is on now. Also lands topology-aware A\* pathfinding and server-side wall collision for bots.

### Fixed

- macOS export config enables ETC2 ASTC import. Universal binary builds in CI and the release workflow now produces the macOS .zip alongside Windows and Linux.
- Website footer trimmed of the issue-tracker plug.

### Added

- Topology-aware A\* pathfinding. The labyrinth builds a hand-rolled `AStar2D` graph whose border cells include seam edges (torus wraps both axes, Klein flips Z when crossing X). Bots find shortest paths across the seam instead of routing the long way. New `Topology.delta()` returns the shortest wrapped displacement and feeds bot steering.
- Server-side wall geometry. `backend/shared/src/labyrinth.ts` mirrors the GDScript wall generator; the room generates walls in its constructor and rejects bot moves that would clip through them. Both implementations share a pure `(seed, ring, k)` integer hash for gap placement so client and server always compute the same maze.
- `@cm/smoke` package: a single-file TS script that hits a deployed matchmaker end to end (healthz, create lobby, join by code, websocket snapshot). Useful as a manual deploy verification.
- `scripts/playtest-dev.sh` launches the Godot editor pointed at the dev backend so a maintainer can play against live workers without configuration.

### Changed

- Retired the `staging` long-lived branch. Branch model is `feature -> dev -> main`. Both `main` and `dev` are protected by branch rulesets that require PRs and green status checks.
- ARCHITECTURE.md refreshed to match shipped behavior: matchmaker open-room reuse via KV listing, `WORKERS_SUBDOMAIN` in the wsUrl, bot AI sections covering both client-side A\* and server-side fill plus tick, JSON-over-WS protocol, environments table with the real `seanreid.workers.dev` subdomains, smoke and playtest tooling under observability. Dropped the stale Sentry mention from the doc and the budget table.

## [0.1.0] - 2026-05-24

First playable release. Cross-platform installers for Windows, macOS, and Linux are published alongside this tag. The backend matchmaker and room are live on Cloudflare Workers under `*.seanreid.workers.dev`. The website at https://sean-reid.github.io/clowns-and-mimes/ pulls download links from this release.

### Game

- Godot 4 client with title screen, main menu, lobby, and arena scenes.
- Three game modes: host a private room, join by code, or play against internet strangers.
- Four topologies: finite plane, torus, Klein bottle, and sphere. Math mirrored between the GDScript client and the TypeScript backend.
- Symmetric concentric-ring labyrinth generator with rotational symmetry of order 12 and alternating connector orientations. Walls are solid colliders.
- Game rules engine drives phase progression, turn rotation, contact-based tag and unfreeze, and win detection.
- Bot AI: 4-state machine (patrol, chase, flee, rescue) with A\* pathfinding around walls. Runs client-side in offline mode and server-side in stranger rooms.
- HUD: sprint bar, top-center countdown, team status row, side event log, frozen overlay, end-of-match screen.
- Audio: oompa main menu theme, footstep emitter (looped with pitch scaling to current speed), win/lose stingers.
- Photo head textures for mime and clown teams.
- Arena directional lighting with cast shadows on heads and walls; ambient sky source and violet fog.
- In-game menu opened by Esc; the world keeps running while it is open (no pause in a multiplayer game).
- Username generator with ~4 million silly clown/mime combinations.

### Backend

- Cloudflare Workers + Durable Objects.
- Matchmaker: private codes with KV-backed lookup, open-room reuse with a soft capacity threshold, healthz endpoint.
- Room durable object: 20 Hz tick, server-authoritative state, anti-cheat travel clamp, server-side bot fill (3s after the first human joins) and bot AI (chase/flee/patrol with the same canTag path humans use).
- Wire protocol shared between client and server (PROTOCOL_VERSION = 1).

### Website

- Carnival poster aesthetic: cream paper panels with offset shadows, Alfa Slab One and Patrick Hand fonts, hard-edge stripe banner, polka-dot starfield, tilted tiles, falling confetti, wiggling title. Designed to translate cleanly to a Godot Theme later.
- Photo avatars in ellipse frames mirroring the in-game floating heads.
- OS-detected download tile and live hydration from the latest GitHub Release.
- Klein bottle as the textbook fundamental polygon (identified arrows on each edge pair).

### Infrastructure

- Two-branch model: feature -> dev -> main. Branch ruleset on main blocks force-push and deletion, requires PR and green status checks.
- CI pipeline: lint, format, type check, vitest unit tests, headless Godot test runner, Playwright E2E against the built site, build verification, dependency audit.
- Release workflow exports installers for Windows, macOS, and Linux universal, pulls release notes from this CHANGELOG, deploys backend to Cloudflare and the website to GitHub Pages on tag.
- Smoke script (`pnpm --filter @cm/smoke dev`) hits a deployed matchmaker end-to-end (healthz, create lobby, join by code, websocket snapshot).
- Local playtest helper (`scripts/playtest-dev.sh`) launches Godot pointed at the dev workers.

### Security

- Anti-cheat clamp on per-tick player travel.
- Display names sanitized on join.
- Main branch ruleset blocks force-push and deletion.

### Known follow-ups

- macOS code signing and notarization once an Apple Developer ID is in place.
- ARCHITECTURE.md walkthrough to reflect the shipped matchmaker, server-bot, and tooling additions.
- Topology-aware bot paths (currently A\* ignores the torus and Klein seam).
- Server-side wall geometry so server-driven bots do not clip through walls.
