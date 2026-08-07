#!/usr/bin/env bash
# Update Casks/mac-authenticator.rb from a packaged zip (or explicit VERSION + SHA256).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CASK="$ROOT/Casks/mac-authenticator.rb"

VERSION="${VERSION:-}"
SHA256="${SHA256:-}"

if [[ -z "$VERSION" || -z "$SHA256" ]]; then
  ZIP="${1:-}"
  if [[ -z "$ZIP" ]]; then
    ZIP="$(ls -t "$ROOT"/dist/MacAuthenticator-*.zip 2>/dev/null | head -1 || true)"
  fi
  if [[ -z "$ZIP" || ! -f "$ZIP" ]]; then
    echo "Usage: $0 [dist/MacAuthenticator-VERSION.zip]" >&2
    echo "   or: VERSION=1.0.0 SHA256=<digest> $0" >&2
    exit 1
  fi
  BASE="$(basename "$ZIP" .zip)"
  VERSION="${BASE#MacAuthenticator-}"
  SHA256="$(shasum -a 256 "$ZIP" | awk '{ print $1 }')"
fi

python3 - "$CASK" "$VERSION" "$SHA256" <<'PY'
import pathlib, re, sys
path, version, sha = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
text = path.read_text()
text, n1 = re.subn(r'version\s+"[^"]+"', f'version "{version}"', text, count=1)
text, n2 = re.subn(r'sha256\s+"[0-9a-fA-F]+"', f'sha256 "{sha}"', text, count=1)
if n1 != 1 or n2 != 1:
    raise SystemExit("Failed to update version/sha256 in cask")
path.write_text(text)
print(f"Updated {path}: version={version} sha256={sha}")
PY
