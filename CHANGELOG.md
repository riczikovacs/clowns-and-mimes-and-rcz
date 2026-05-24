# Changelog

This project follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and uses [Semantic Versioning](https://semver.org/).

When cutting a release: rename the `[Unreleased]` heading below to the version being tagged (for example `[0.1.0]`) and open a fresh `[Unreleased]` block above it. The release workflow extracts the section under the heading that matches the tag (e.g. tag `v0.1.0` -> heading `[0.1.0]`) and uses it as the GitHub Release body.

## [Unreleased]

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
