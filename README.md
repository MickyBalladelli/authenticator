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

## Open the project

```bash
open /Users/micky/dev/authenticator/MacAuthenticator.xcodeproj
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

Helper scripts in the repo root (output goes to `.derivedData/`):

| Script | Purpose |
|--------|---------|
| [`build.sh`](build.sh) | Build the app |
| [`test.sh`](test.sh) | Run unit tests |
| [`run.sh`](run.sh) | Launch the app (builds first if needed) |

```bash
./build.sh          # Debug (default)
./build.sh Release  # Release

./test.sh

./run.sh            # Launch Debug build
./run.sh Release    # Launch Release build
```

`run.sh` opens the built `.app`. Look for the **lock.shield** icon in the menu bar (no Dock icon).

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

---

## Usage

1. Click the menu-bar icon to open the app.
2. Click **+** (or **Add Account**) to add a new account.
3. Choose:
   - **Raw Secret Key** — enter issuer, account name, and Base32 secret
   - **Paste otpauth:// URI** — paste a standard TOTP URI; fields auto-fill when valid
4. Optionally open **Advanced** to set digits (6/8) and interval (30s/60s).
5. Click **Copy** on a row to copy the current code (toast: “Copied to clipboard!”).
6. Delete via the trash icon or right-click context menu.

### Settings

Open the gear menu in the header:

- **Require Touch ID / Password** — when enabled, authenticate before viewing codes
- **Quit Authenticator** — exits the app

### Privacy behavior

- Clipboard is cleared **30 seconds** after copy (if it still contains the copied code).
- Codes are obscured when the menu-bar window becomes inactive.
- With authentication required, the app locks again when the window resigns active.

---

## Project layout

```
MacAuthenticator/
  MacAuthenticatorApp.swift          # MenuBarExtra entry point
  Info.plist                         # LSUIElement = YES (agent / no Dock icon)
  Models/
    Account.swift
    OTPURIParser.swift
  Crypto/
    Base32.swift
    TOTPGenerator.swift
  Services/
    KeychainManager.swift
    AccountStore.swift
  ViewModels/
    AccountListViewModel.swift
  Views/
    MainListView.swift
    AccountRowView.swift
    AddAccountSheet.swift
    TimerProgressView.swift
MacAuthenticatorTests/
  Base32Tests.swift
  TOTPGeneratorTests.swift
  OTPURIParserTests.swift
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
