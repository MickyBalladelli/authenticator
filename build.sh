#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

CONFIGURATION="${1:-Debug}"
DERIVED_DATA="${DERIVED_DATA:-$ROOT/.derivedData}"

echo "Building MacAuthenticator ($CONFIGURATION)..."
xcodebuild \
  -scheme MacAuthenticator \
  -configuration "$CONFIGURATION" \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  build

APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/MacAuthenticator.app"
echo "Build succeeded: $APP"
echo "Run with: open \"$APP\""
