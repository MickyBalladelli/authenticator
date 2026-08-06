#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

DERIVED_DATA="${DERIVED_DATA:-$ROOT/.derivedData}"

echo "Testing MacAuthenticator..."
xcodebuild \
  -scheme MacAuthenticator \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  test

echo "All tests passed."
