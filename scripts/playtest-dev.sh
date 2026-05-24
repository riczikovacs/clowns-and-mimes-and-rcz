#!/usr/bin/env bash
# Launches Godot against the deployed dev backend so the editor build talks to
# the live cm-matchmaker-dev worker. Falls back to printing instructions if
# godot is not on PATH.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="${ROOT}/game"
export CLOWNS_MM_URL="${CLOWNS_MM_URL:-https://cm-matchmaker-dev.seanreid.workers.dev}"

echo "Pointing the game at: ${CLOWNS_MM_URL}"

if command -v godot >/dev/null 2>&1; then
  exec godot --path "${PROJECT}"
fi

if [ -d "/Applications/Godot.app" ]; then
  exec /Applications/Godot.app/Contents/MacOS/Godot --path "${PROJECT}"
fi

cat <<EOF
Godot binary not found on PATH. Open the editor at:

  ${PROJECT}/project.godot

with the environment variable CLOWNS_MM_URL pre-exported, or set it inside
the editor's run command.
EOF
