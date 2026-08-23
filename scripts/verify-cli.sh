#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TMP="${TMPDIR:-/tmp}/ghostos-login-retired-$$"
mkdir -p "$TMP"
trap 'mv "$TMP" "${TMP}.finished" 2>/dev/null || true' EXIT

CLI="$TMP/ghostos-login"

swiftc -O \
  MacAuthenticator/Crypto/GhostOSAssertion.swift \
  ghostos-login/main.swift \
  -o "$CLI"

if "$CLI" >"$TMP/stdout" 2>"$TMP/stderr"; then
  echo "FAIL: retired CLI unexpectedly succeeded"
  exit 1
fi

grep -q "no longer creates legacy SYPA assertions" "$TMP/stderr"
echo "Legacy assertion generation is disabled."
