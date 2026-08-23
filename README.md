# Mac Authenticator

A lightweight, native macOS menu-bar 2FA (TOTP) authenticator built with **SwiftUI**, **CryptoKit**, and **Keychain Services**.

- Menu-bar only (no Dock icon)
- Secrets stored in the macOS Keychain
- Account metadata stored in Application Support
- Add accounts via Base32 secret or `otpauth://` URI
- Touch ID / system password lock (optional)
- Clipboard auto-clear and code hiding when inactive

**Requirements:** macOS 13.0 (Ventura) or later, Xcode 15+  
**Bundle ID:** `com.micky.MacAuthenticator`

---

## Install with Homebrew

This app is distributed as a Homebrew **Cask** from this repository (personal tap):

```bash
brew tap MickyBalladelli/authenticator https://github.com/MickyBalladelli/authenticator
brew trust mickyballadelli/authenticator
brew install --cask mac-authenticator
```

Upgrade / uninstall:

```bash
brew upgrade --cask mac-authenticator
brew uninstall --cask mac-authenticator
```

> **Note:** Builds are currently ad-hoc signed (not Apple notarized). On first launch macOS may quarantine the app — use **System Settings → Privacy & Security** to allow it, or: `xattr -dr com.apple.quarantine /Applications/MacAuthenticator.app`.

---

## Open the project

```bash
open MacAuthenticator.xcodeproj
```

Or open `MacAuthenticator.xcodeproj` from Finder / Xcode.

---

## Build & run (Xcode)

1. Select the **MacAuthenticator** scheme.
2. Set the destination to **My Mac**.
3. Press **⌘R** to build and run, or **⌘B** to build only.

The app appears as a **lock.shield** icon in the menu bar (no Dock icon). Click it to open the popup window.

Because this is a menu-bar agent app (`LSUIElement`), launching it will **not** show a Dock icon or open a normal window — look in the menu bar.

### Quit the app

Open the menu-bar popup → gear menu → **Quit Authenticator**.

Alternatively:

```bash
killall MacAuthenticator
```

Or use **Activity Monitor** → search **MacAuthenticator** → Quit / Force Quit.

---

## Scripts

Helper scripts in the repo root (build output goes to `.derivedData/`, packages to `dist/`):

| Script | Purpose |
|--------|---------|
| [`build.sh`](build.sh) | Build the app (falls back to CLI-only `swiftc` build when Xcode is absent) |
| [`test.sh`](test.sh) | Run unit tests (requires full Xcode) |
| [`scripts/verify-cli.sh`](scripts/verify-cli.sh) | Xcode-free smoke test of the `ghostos-login` CLI |
| [`run.sh`](run.sh) | Launch the app (builds first if needed) |
| [`package.sh`](package.sh) | Release-build and zip for GitHub / Homebrew |
| [`scripts/update-cask.sh`](scripts/update-cask.sh) | Refresh `Casks/mac-authenticator.rb` version + sha256 |

```bash
./build.sh          # Debug (default)
./build.sh Release  # Release

./test.sh

./run.sh            # Launch Debug build
./run.sh Release    # Launch Release build

VERSION=1.0.0 ./package.sh
./scripts/update-cask.sh dist/MacAuthenticator-1.0.0.zip
```

`run.sh` opens the built `.app`. Look for the **lock.shield** icon in the menu bar (no Dock icon).

### Publish a Homebrew release

1. Bump `MARKETING_VERSION` in the Xcode project (already `1.0.0`).
2. Commit, then tag and push:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
3. GitHub Actions (`.github/workflows/release.yml`) builds a Release zip, uploads it to the GitHub Release, and attaches an updated `Casks/mac-authenticator.rb`.
4. Copy that cask file onto your default branch (so `brew install` / `brew upgrade` see the new checksum), then push.

Local dry-run without tagging:

```bash
VERSION=1.0.0 ./package.sh
./scripts/update-cask.sh
```

### Equivalent `xcodebuild` commands

```bash
# Build
xcodebuild -scheme MacAuthenticator -destination 'platform=macOS' build

# Test
xcodebuild -scheme MacAuthenticator -destination 'platform=macOS' test

# Run a built app manually
open .derivedData/Build/Products/Debug/MacAuthenticator.app
```

Unit tests cover:

- Base32 decoding (`JBSWY3DPEHPK3PXP` and related cases)
- TOTP generation against **RFC 6238** SHA-1 vectors
- `otpauth://` URI parsing (valid TOTP, HOTP rejection, invalid input)
- `SYPA` v1 GhostOS login assertions (exact vector, challenge echo, flags, rejection cases)

---

## Usage

1. Click the menu-bar icon to open the app.
2. Switch between **Codes** (TOTP list) and **GhostOS Login** with the tabs at the top.
3. Click **+** (or **Add Account**) to add a new account.
4. Choose:
   - **Raw Secret Key** — enter issuer, account name, and Base32 secret
   - **Paste otpauth:// URI** — paste a standard TOTP URI; fields auto-fill when valid
5. Optionally open **Advanced** to set digits (6/8) and interval (30s/60s).
6. Click **Copy** on a row to copy the current code (toast: “Copied to clipboard!”).
7. Delete via the trash icon or right-click context menu.

### GhostOS Login tab

1. Copy the challenge shown after `Challenge:` in the GhostOS console.
2. Paste it into the **Challenge** field — validation runs live (spaces,
   colons, dashes and mixed case are accepted; anything else is rejected).
3. Click **Generate Assertion**, then **Copy** and paste at the console's
   `Passkey assertion:` prompt.

Assertions are held only in memory (dropped when the popup loses focus),
never logged or stored. Copied assertions stay on the clipboard until you
copy something else — TOTP codes still auto-clear after 30 seconds.

### Settings

Open the gear menu in the header:

- **Require Touch ID / Password** — when enabled, authenticate before viewing codes
- **Quit Authenticator** — exits the app

### Privacy behavior

- Clipboard is cleared **30 seconds** after copy (if it still contains the copied code).
- Codes are obscured when the menu-bar window becomes inactive.
- With authentication required, the app locks again when the window resigns active.

---

## GhostOS console login

`ghostos-login` builds the passkey assertion the GhostOS local console asks for
after `Challenge:` (mirrors the kernel's `valid_local_passkey_assertion()`):

```bash
./build.sh
.derivedData/Build/Products/Debug/ghostos-login <challenge-hex>
```

Without full Xcode, `./build.sh` automatically falls back to building the CLI
alone with `swiftc` (Command Line Tools only). Run `./scripts/verify-cli.sh`
for an Xcode-free check of the wire format.

Paste the printed hex at the console's `Passkey assertion:` prompt. The input
may contain spaces, colons, dashes, and mixed case; it must decode to exactly
32 bytes or the command fails with a clear error.

Challenges are one-shot: if the console rejects an assertion, request a **new**
challenge — never reuse one. Assertions are credential-bearing artifacts;
the tool only prints them to stdout and does not log or store them.

---

## Project layout

```
MacAuthenticator/
  MacAuthenticatorApp.swift          # MenuBarExtra entry point
  Info.plist                         # LSUIElement = YES (agent / no Dock icon)
  Models/
  Crypto/
  Services/
  ViewModels/
  Views/
MacAuthenticatorTests/
Casks/
  mac-authenticator.rb               # Homebrew Cask (personal tap)
scripts/
  update-cask.sh                     # Sync cask version + sha256 from dist zip
.github/workflows/
  release.yml                        # Tag → zip → GitHub Release
package.sh                           # Release .app → dist/*.zip
```

---

## Storage

| Data | Location |
|------|----------|
| Secrets | Keychain service `com.micky.MacAuthenticator.secrets` (keyed by account UUID) |
| Account metadata | `~/Library/Application Support/MacAuthenticator/accounts.json` |

Secrets are **never** stored in the account model or UserDefaults.

---

## Notes

- Only **TOTP** is supported; HOTP URIs are rejected with a clear error.
- QR camera scanning is not included (manual secret / URI paste only).
- TOTP correctness is validated via RFC 6238 unit tests; you can also spot-check against Google Authenticator, 1Password, or Authy using the same secret.
- UI uses system colors and adapts to light and dark mode.
