#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

CONFIGURATION="${1:-Debug}"
DERIVED_DATA="${DERIVED_DATA:-$ROOT/.derivedData}"

XCODEBUILD_ARGS=(
  -scheme MacAuthenticator
  -configuration "$CONFIGURATION"
  -destination 'platform=macOS'
  -derivedDataPath "$DERIVED_DATA"
)

# Optional overrides used by package/release: VERSION=1.2.3 ./build.sh Release
if [[ -n "${VERSION:-}" ]]; then
  XCODEBUILD_ARGS+=(MARKETING_VERSION="$VERSION")
fi
if [[ -n "${BUILD_NUMBER:-}" ]]; then
  XCODEBUILD_ARGS+=(CURRENT_PROJECT_VERSION="$BUILD_NUMBER")
fi

echo "Building MacAuthenticator ($CONFIGURATION)..."
xcodebuild "${XCODEBUILD_ARGS[@]}" build

APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/MacAuthenticator.app"
echo "Build succeeded: $APP"
echo "Run with: open \"$APP\""
