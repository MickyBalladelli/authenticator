#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

CONFIGURATION="${1:-Debug}"
DERIVED_DATA="${DERIVED_DATA:-$ROOT/.derivedData}"
PRODUCTS_DIR="$DERIVED_DATA/Build/Products/$CONFIGURATION"
APP="$PRODUCTS_DIR/MacAuthenticator.app"

xcodebuild_available() {
  command -v xcodebuild >/dev/null 2>&1 && xcodebuild -version >/dev/null 2>&1
}

if xcodebuild_available; then
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

  echo "Build succeeded: $APP"
  echo "Run with: open \"$APP\""
else
  echo "xcodebuild is not available (only Command Line Tools installed)."
  echo "Falling back to a swiftc-only build of MacAuthenticator.app..."
  echo "(Install full Xcode for the complete xcodebuild flow.)"
  echo ""

  SWIFT_SOURCES=(
    MacAuthenticator/*.swift
    MacAuthenticator/Models/*.swift
    MacAuthenticator/Crypto/*.swift
    MacAuthenticator/Services/*.swift
    MacAuthenticator/ViewModels/*.swift
    MacAuthenticator/Views/*.swift
  )
  TARGET="$(uname -m)-apple-macos13.0"
  local_opts=(-Onone)
  if [[ "$CONFIGURATION" == "Release" ]]; then
    local_opts=(-O)
  fi

  mkdir -p "$PRODUCTS_DIR"

  echo "Building MacAuthenticator.app ($CONFIGURATION)..."
  rm -rf "$APP"
  mkdir -p "$APP/Contents/MacOS"

  # App icon: generate into Resources (canonical) when not yet built;
  # PNG intermediates go to tmp/ (gitignored).
  ICON="MacAuthenticator/Resources/AppIcon.icns"
  if [[ ! -f "$ICON" ]]; then
    swift scripts/make_icon.swift tmp/AppIcon.iconset "$ICON"
  fi

  # Resolve the Xcode build-setting placeholders in Info.plist.
  INFO="$APP/Contents/Info.plist"
  sed \
    -e "s/\$(DEVELOPMENT_LANGUAGE)/en/" \
    -e "s/\$(EXECUTABLE_NAME)/MacAuthenticator/" \
    -e "s/\$(PRODUCT_BUNDLE_IDENTIFIER)/com.micky.MacAuthenticator/" \
    -e "s/\$(PRODUCT_NAME)/MacAuthenticator/" \
    -e "s/\$(MARKETING_VERSION)/${VERSION:-1.0.0}/" \
    -e "s/\$(CURRENT_PROJECT_VERSION)/${BUILD_NUMBER:-1}/" \
    -e "s/\$(MACOSX_DEPLOYMENT_TARGET)/13.0/" \
    MacAuthenticator/Info.plist > "$INFO"
  plutil -lint "$INFO" >/dev/null

  mkdir -p "$APP/Contents/Resources"
  cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"

  swiftc "${local_opts[@]}" -target "$TARGET" \
    "${SWIFT_SOURCES[@]}" \
    -o "$APP/Contents/MacOS/MacAuthenticator"

  codesign --force -s - "$APP"

  echo "Build succeeded: $APP"
  echo "Run with: open \"$APP\""
fi
