# Contributing

Thanks for your interest in contributing. This project is built in public and PRs are welcome.

## Quickstart

Prerequisites:

- [Godot 4.3](https://godotengine.org/download) or newer for the game client.
- Node.js 22+ and [pnpm](https://pnpm.io/) for the backend and website.
- A GitHub account.

Clone and install JS dependencies:

```
git clone git@github.com:sean-reid/clowns-and-mimes.git
cd clowns-and-mimes
pnpm install
```

Open the game client in Godot by pointing the editor at the `game/` folder.

Start the backend workers locally (each in its own terminal):

```
pnpm --filter @cm/matchmaker dev
pnpm --filter @cm/room dev
```

Start the website locally:

```
pnpm --filter website dev
```

## Branching model

Two long-lived branches:

- `dev` is the active integration branch. Feature branches target it.
- `main` is the production branch. `dev` is promoted to `main` via PR. Releases are tagged from `main`.

Feature branches: `feat/<short-slug>`, fixes: `fix/<short-slug>`, chores: `chore/<short-slug>`.

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/). Examples:

```
feat(game): add Klein bottle topology adapter
fix(backend): reject duplicate join codes
chore(ci): add visual regression workflow
docs(architecture): describe room lifecycle
```

Keep commits atomic. One logical change per commit. The repo must be deployable from every commit on `main`.

## Pull requests

- Branch from `dev`.
- Keep PRs focused. Smaller is better.
- Fill out the PR template.
- All checks must pass before merge.
- Squash merge is the default.

## Testing

- Unit tests live next to the code they cover.
- Integration tests for the backend live under `backend/<package>/test/integration`.
- End-to-end tests live under `tests/e2e`.
- For the website, Playwright tests cover the public flows.

Run everything:

```
pnpm test
```

## Style

- Markdown: no emdashes, no AI tropes, plain hyphens. Sentence case for headings.
- TypeScript: strict mode, ESLint clean, Prettier formatted.
- GDScript: follow the [official style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html). Tabs for indentation.
- Public API surface is documented at the type level. Avoid prose comments that restate code.

## Reporting bugs

Open an issue using the bug report template. Include:

- Platform and version
- Steps to reproduce
- Expected vs actual behavior
- Logs if relevant
