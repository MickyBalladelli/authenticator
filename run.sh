#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

CONFIGURATION="${1:-Debug}"
DERIVED_DATA="${DERIVED_DATA:-$ROOT/.derivedData}"
APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/MacAuthenticator.app"

if [[ ! -d "$APP" ]]; then
  echo "App not found at $APP"
  echo "Building first..."
  "$ROOT/build.sh" "$CONFIGURATION"
fi

echo "Launching $APP"
echo "Look for the lock.shield icon in the menu bar (no Dock icon)."
open "$APP"
