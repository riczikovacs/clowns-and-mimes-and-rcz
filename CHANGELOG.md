# Changelog

This project follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and uses [Semantic Versioning](https://semver.org/).

When cutting a release: rename the `[Unreleased]` heading below to the version being tagged (for example `[0.1.0]`) and open a fresh `[Unreleased]` block above it. The release workflow extracts the section under the heading that matches the tag (e.g. tag `v0.1.0` -> heading `[0.1.0]`) and uses it as the GitHub Release body.

## [Unreleased]

## [0.3.0] - 2026-05-25

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

## [0.2.0] - 2026-05-25

### Added

- macOS builds are signed with a Developer ID certificate, packaged as a `.dmg` (with a drag-to-Applications symlink), notarized by Apple, and stapled. Gatekeeper accepts the build without the previous one-time `xattr` workaround.

### Changed

- Retired the `staging` long-lived branch and Cloudflare staging environment. Branch model is now `feature -> dev -> main`. Cloudflare per-PR preview deploys cover any pre-prod sanity check.

### Added

- Initial public scaffolding of the monorepo, MIT license, contributor docs, and CI/CD pipelines.
- Architecture document with mermaid diagrams covering topology, networking, matchmaking, room lifecycle, and the release pipeline.
- Godot 4 client: title screen with three-phase animated title, main menu, lobby placeholder, arena with a placeholder labyrinth.
- Player controller (CharacterBody3D) with WASD movement, mouse look, sprint, and exclamation marker for frozen states.
- HUD: sprint bar, top-center countdown, team status row, side event log, frozen overlay, and end-of-match screen.
- Topology adapters for plane, torus, Klein bottle, and sphere. Shared between game and backend (math mirrored in GDScript and TypeScript).
- Symmetric concentric-ring labyrinth generator with alternating connector orientations and rotational symmetry of order 12.
- Authoritative offline game rules engine: phase progression, turn rotation, tag and unfreeze validation, win detection.
- Bot AI with patrol, chase, flee, and rescue states. Decisions tick at 5 Hz. Topology-aware target selection.
- Username generator producing roughly 4 million silly clown/mime combinations.
- Cloudflare Workers backend: matchmaker (private + open lobbies, open-room reuse) and room durable object (tick loop, bot fill, anti-cheat movement clamp).
- Client networking layer: matchmaker HTTP client and room WebSocket client. Lobby falls back to offline-versus-bots when the backend is unreachable.
- Website: hero, topology cards, OS-detected download recommendation, GitHub releases hydration.
- Cross-platform release pipeline: Godot 4 export presets for Linux/X11, Windows, and macOS universal. Workflow_dispatch trigger for non-tag builds.
- GitHub Pages deploys the website on every push to main that touches the website tree.

### Security

- Branch ruleset protecting main: PR required, status checks gated, force-push and deletion blocked.
- Anti-cheat clamp on per-tick player travel.
- Display names sanitized to a safe character set on join.

### Known follow-ups

- A\* pathfinding for bots around labyrinth walls.
- Wiring RoomClient into Arena so online play is server-driven (currently the lobby reaches the matchmaker, then the arena drops to local rules).
- Audio assets and footstep emitters.
