#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TMP="$ROOT/.derivedData/verify-cli"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

CLI="$TMP/ghostos-login"

echo "Building ghostos-login with swiftc..."
swiftc -O \
  MacAuthenticator/Crypto/GhostOSAssertion.swift \
  ghostos-login/main.swift \
  -o "$CLI"

fail() { echo "FAIL: $1"; exit 1; }

Z64=$(printf '0%.0s' {1..64})
EXPECTED="5359504101000000${Z64}250001000100${Z64}05000000000000"

echo "1. Exact all-zero challenge vector..."
OUT=$("$CLI" "$Z64")
[[ ${#OUT} -eq 170 ]] || fail "expected 170 hex chars, got ${#OUT}"
[[ "$OUT" == "$EXPECTED" ]] || fail "vector mismatch:\n  got:      $OUT\n  expected: $EXPECTED"

echo "2. Challenge echoed verbatim at bytes 8..40..."
CH="A1B2C3D4E5F60718293A4B5C6D7E8F90DEADBEEFCAFE01122334455667788999"
OUT=$("$CLI" "$CH")
CH_LOWER=$(echo "$CH" | tr 'A-Z' 'a-z')
[[ "${OUT:16:64}" == "$CH_LOWER" ]] || fail "challenge not embedded verbatim at offset 8"

echo "3. Rejects invalid challenges..."
C63=$(printf 'a%.0s' {1..63})
"$CLI" "$C63" >/dev/null 2>&1 && fail "accepted 63-char hex"
"$CLI" "$(printf 'g%.0s' {1..64})" >/dev/null 2>&1 && fail "accepted non-hex input"
"$CLI" "" >/dev/null 2>&1 && fail "accepted empty input"

echo "4. Flags byte 0x05 at assertion offset 78..."
OUT=$("$CLI" "$(printf 'f%.0s' {1..64})")
[[ "${OUT:156:2}" == "05" ]] || fail "flags byte at offset 46+32 is '${OUT:156:2}', expected 05"

echo ""
echo "All checks passed."
