# Changelog

This project follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and uses [Semantic Versioning](https://semver.org/).

When cutting a release: rename the `[Unreleased]` heading below to the version being tagged (for example `[0.1.0]`) and open a fresh `[Unreleased]` block above it. The release workflow extracts the section under the heading that matches the tag (e.g. tag `v0.1.0` -> heading `[0.1.0]`) and uses it as the GitHub Release body.

## [Unreleased]

## [0.1.1] - 2026-05-24

First release with all three platform installers. v0.1.0 failed to publish a macOS asset because Godot 4 refuses universal/arm64 exports unless ETC2 ASTC import is enabled in the project; that setting is on now. Also lands topology-aware A\* pathfinding and server-side wall collision for bots.

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
