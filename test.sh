#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

DERIVED_DATA="${DERIVED_DATA:-$ROOT/.derivedData}"

if ! command -v xcodebuild >/dev/null 2>&1 || ! xcodebuild -version >/dev/null 2>&1; then
  echo "error: unit tests require full Xcode (xcodebuild + XCTest)."
  echo "Install Xcode, then run:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

echo "Testing MacAuthenticator..."
xcodebuild \
  -scheme MacAuthenticator \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  test

echo "All tests passed."
