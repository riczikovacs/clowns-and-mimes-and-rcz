# Changelog

This project follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

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

- A* pathfinding for bots around labyrinth walls.
- Wiring RoomClient into Arena so online play is server-driven (currently the lobby reaches the matchmaker, then the arena drops to local rules).
- Audio assets and footstep emitters.
- macOS code signing and notarization once Apple Developer secrets are in place.
