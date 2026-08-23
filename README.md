# Mac Authenticator

A lightweight, native macOS menu-bar 2FA (TOTP) authenticator built with **SwiftUI**, **CryptoKit**, and **Keychain Services**.

- Runs as a menu-bar agent (no Dock icon) or a regular application — pick one in Settings
- Creates real GhostOS ES256 passkeys and authenticates through the VM's local bridge
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
| [`scripts/verify-cli.sh`](scripts/verify-cli.sh) | Confirms the retired legacy CLI cannot create assertions |
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
- COSE ES256 public keys and signed `SYWB` GhostOS WebAuthn assertions

---

## Usage

1. Click the menu-bar icon to open the app.
2. Switch between **Codes**, **GhostOS**, and **Settings** with the tabs at the top.
3. Click **+** (or **Add Account**) to add a new account.
4. Choose:
   - **Raw Secret Key** — enter issuer, account name, and Base32 secret
   - **Paste otpauth:// URI** — paste a standard TOTP URI; fields auto-fill when valid
5. Optionally open **Advanced** to set digits (6/8) and interval (30s/60s).
6. Click **Copy** on a row to copy the current code (toast: “Copied to clipboard!”).
7. Delete via the trash icon or right-click context menu.

### GhostOS tab

1. Start GhostOS and copy the one-time `http://localhost:<port>/?code=…` URL
   printed by the VM.
2. Paste the URL into the **GhostOS** tab and click **Connect**.
3. Enter the administrator username.
4. Choose **Create Passkey** during first setup or **Use Passkey** at login.
5. Approve Touch ID or the macOS authentication prompt.

The app creates a P-256 ES256 credential, sends only its COSE public key during
enrollment, and sends a signed `SYWB` WebAuthn assertion during login. Private
key material stays in the Secure Enclave when available, with a Keychain-backed
software key fallback.

### Settings

Open the **Settings** tab in the popup (the gear menu now only holds
**Quit Authenticator**):

- **Require Touch ID / Password** — when enabled, authenticate before viewing codes
- **Ask again after** — how long codes stay unlocked after a successful
  authentication before the next click prompts again:
  - **Always** (default) — authenticate on every open
  - **5 minutes** / **1 hour** / **3 hours** — grace period; the choice is
    remembered across launches. Unlock state itself is never persisted: after
    quitting the app always starts locked.
- **Run as** — how the app presents itself; only one form is ever active:
  - **Menu Bar Only** (default) — shield icon in the menu bar, no Dock icon
  - **Application** — Dock icon, Cmd-Tab, and a resizable window
  The choice is remembered across launches and takes effect after relaunch;
  press **Relaunch Now** to apply it immediately.
- **Quit Authenticator** — exits the app

### Menu bar vs application

The two forms are mutually exclusive. In **Menu Bar Only** mode there is no
Dock icon and no regular window — the shield popover *is* the app. In
**Application** mode the window opens at launch with the same Codes / Passkey /
Settings tabs and no menu-bar item appears. Switch via Settings → **Run as**,
then relaunch (or **Relaunch Now**).

### Privacy behavior

- Clipboard is cleared **30 seconds** after copying a TOTP code (if it still
  contains the copied code). GhostOS assertions never enter the clipboard.
- Codes are obscured when the menu-bar popup becomes inactive.
- With authentication required and no grace period left, the app locks again
  when the popup resigns active.

---

## GhostOS console login

The old `ghostos-login` legacy `SYPA` generator is retired. Use the GhostOS tab:

```bash
./build.sh
```

The app talks directly to the loopback VM bridge. Users do not copy challenges,
COSE keys, assertions, or hexadecimal credential material.

This macOS project supports TOTP and GhostOS passkeys. It does not contain a
TPM implementation; macOS provides Secure Enclave rather than a TPM API.

---

## Project layout

```
MacAuthenticator/
  MacAuthenticatorApp.swift          # Entry point; picks menu-bar or window mode
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
