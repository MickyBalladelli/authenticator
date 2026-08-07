#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

CONFIGURATION="Release"
DERIVED_DATA="${DERIVED_DATA:-$ROOT/.derivedData}"
DIST_DIR="${DIST_DIR:-$ROOT/dist}"

# Prefer explicit VERSION=…, then git tag (v1.2.3), then Xcode MARKETING_VERSION.
if [[ -n "${VERSION:-}" ]]; then
  :
elif git describe --tags --exact-match HEAD >/dev/null 2>&1; then
  VERSION="$(git describe --tags --exact-match HEAD)"
  VERSION="${VERSION#v}"
else
  VERSION="$(
    xcodebuild \
      -scheme MacAuthenticator \
      -configuration "$CONFIGURATION" \
      -showBuildSettings \
      2>/dev/null \
      | awk -F' = ' '/MARKETING_VERSION/ { print $2; exit }'
  )"
fi

if [[ -z "${VERSION}" ]]; then
  echo "Could not determine version. Set VERSION=1.0.0 or tag the commit (v1.0.0)." >&2
  exit 1
fi

echo "Packaging MacAuthenticator v${VERSION}..."
"$ROOT/build.sh" "$CONFIGURATION"

APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/MacAuthenticator.app"
if [[ ! -d "$APP" ]]; then
  echo "Missing app bundle: $APP" >&2
  exit 1
fi

mkdir -p "$DIST_DIR"
STAGE="$DIST_DIR/stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"

ZIP_NAME="MacAuthenticator-${VERSION}.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"
rm -f "$ZIP_PATH"

# ditto preserves macOS metadata better than zip for .app bundles.
ditto -c -k --sequesterRsrc --keepParent "$STAGE/MacAuthenticator.app" "$ZIP_PATH"

SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{ print $1 }')"
echo "$SHA256  $ZIP_NAME" >"$DIST_DIR/$ZIP_NAME.sha256"

rm -rf "$STAGE"

echo
echo "Artifact: $ZIP_PATH"
echo "SHA256:   $SHA256"
echo
echo "GitHub release asset name should be: $ZIP_NAME"
echo "Then update Casks/mac-authenticator.rb version + sha256."
