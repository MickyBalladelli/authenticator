# TODO: Custom macOS 2FA Authenticator App (Swift / SwiftUI)

A comprehensive, step-by-step roadmap to build a lightweight, native macOS Menu Bar 2FA Authenticator app using **SwiftUI**, **CryptoKit**, and **Keychain Services**.

---

## 📋 Table of Contents
- [TODO: Custom macOS 2FA Authenticator App (Swift / SwiftUI)](#todo-custom-macos-2fa-authenticator-app-swift--swiftui)
  - [📋 Table of Contents](#-table-of-contents)
    - [Phase 1: Project Setup \& Architecture](#phase-1-project-setup--architecture)
    - [Phase 2: Core Cryptography \& Data Parsing](#phase-2-core-cryptography--data-parsing)
    - [Phase 3: Secure Storage (Keychain Integration)](#phase-3-secure-storage-keychain-integration)
    - [Phase 4: Data Models \& Persistence Manager](#phase-4-data-models--persistence-manager)
    - [Phase 5: User Interface (SwiftUI \& Menu Bar)](#phase-5-user-interface-swiftui--menu-bar)
    - [Phase 6: Manual Entry \& Account Association](#phase-6-manual-entry--account-association)
    - [Phase 7: Dynamic Timer \& UX Polish](#phase-7-dynamic-timer--ux-polish)
    - [Phase 8: Security \& Production Hardening](#phase-8-security--production-hardening)

---

## Phase 1: Project Setup & Architecture

- [x] **1.1 Initialize Xcode Project**
  - Select **macOS App** template.
  - Set interface to **SwiftUI** and Language to **Swift**.
  - Target Minimum Deployment Version: macOS 13.0 (Ventura) or later.
  - Set Bundle Identifier (e.g., `com.domain.MacAuthenticator`).

- [x] **1.2 Configure App Properties (`Info.plist`)**
  - Set `Application is agent (UIElement)` (`LSUIElement`) to `YES` (hides standard Dock icon for menu bar-only apps).

- [x] **1.3 Folder Structure Setup**
  - `Models/` (Account, OTPParameters)
  - `Crypto/` (Base32, TOTPGenerator)
  - `Services/` (KeychainManager, StorageService)
  - `ViewModels/` (AccountListViewModel)
  - `Views/` (MenuBarView, AccountRowView, AddAccountSheet, TimerView)

---

## Phase 2: Core Cryptography & Data Parsing

- [x] **2.1 Implement Base32 Decoder (`Crypto/Base32.swift`)**
  - Write custom decoder function for RFC 4648 Base32 specification.
  - Handle padding characters (`=`) gracefully.
  - Strip spaces and convert user input to uppercase automatically.
  - Return `Data?` byte array for valid Base32 strings.
  - Add unit tests for standard test vectors (e.g., `"JBSWY3DPEHPK3PXP"`).

- [x] **2.2 Implement `otpauth://` URI Parser (`Models/OTPURIParser.swift`)**
  - Write parser to validate and decompose standard 2FA URI formats:
    `otpauth://totp/Issuer:AccountName?secret=BASE32SECRET&issuer=Issuer&digits=6&period=30`
  - Extract key components:
    - [x] Protocol scheme validation (`otpauth://`)
    - [x] Type check (TOTP vs HOTP - flag warning if HOTP)
    - [x] Issuer / Label extraction
    - [x] Account name extraction
    - [x] Secret key query parameter
    - [x] Optional custom period (default: 30s)
    - [x] Optional digit length (default: 6)

- [x] **2.3 Implement TOTP Core Generator (`Crypto/TOTPGenerator.swift`)**
  - Import `CryptoKit` and `Foundation`.
  - Calculate 8-byte big-endian Unix timestamp divided by time period (`floor(T / X)`).
  - Compute `HMAC-SHA1` using `Insecure.SHA1` (or SHA256/SHA512 if requested).
  - Apply Dynamic Truncation to extract 4-byte integer from offset.
  - Calculate modulo $10^{\text{digits}}$ to output clean $N$-digit string.
  - Add zero-padding to keep length fixed (e.g., `"012345"`).

---

## Phase 3: Secure Storage (Keychain Integration)

- [x] **3.1 Create Keychain Wrapper (`Services/KeychainManager.swift`)**
  - Encapsulate `Security.framework` C API into a clean Swift interface.
  - Set constant Service Name identifier: `kSecAttrService = "com.domain.MacAuthenticator.secrets"`.

- [x] **3.2 Implement CRUD Operations**
  - [x] `saveSecret(accountID: String, secret: String) -> Bool`
    - Configure accessibility: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
  - [x] `fetchSecret(accountID: String) -> String?`
  - [x] `updateSecret(accountID: String, newSecret: String) -> Bool`
  - [x] `deleteSecret(accountID: String) -> Bool`

---

## Phase 4: Data Models & Persistence Manager

- [x] **4.1 Define Account Model (`Models/Account.swift`)**
  - Create `Identifiable`, `Codable` struct:
    ```swift
    struct Account: Identifiable, Codable {
        let id: UUID
        var label: String         // e.g., "Google", "GitHub"
        var accountName: String   // e.g., "user@gmail.com"
        var digits: Int           // Default: 6
        var period: Int           // Default: 30
        var createdAt: Date
    }
    ```
  - Note: *The secret key itself is NEVER stored in the model struct or `UserDefaults` — only in macOS Keychain keyed by `id.uuidString`.*

- [x] **4.2 Implement Account Storage (`Services/AccountStore.swift`)**
  - Store metadata list (excluding secrets) in `UserDefaults` or local JSON file in Application Support.
  - Link model `id` to Keychain secret entry.

---

## Phase 5: User Interface (SwiftUI & Menu Bar)

- [x] **5.1 Setup `MenuBarExtra` Entry Point (`MacAuthenticatorApp.swift`)**
  - Replace `WindowGroup` with `MenuBarExtra("Authenticator", systemImage: "lock.shield")`.
  - Configure `.menuBarExtraStyle(.window)` for interactive popup styling.

- [x] **5.2 Create Main List View (`Views/MainListView.swift`)**
  - Container header with app title, dynamic countdown circle, and **"+"** Add Button.
  - `ScrollView` or `List` displaying saved accounts.
  - Empty state UI with clear prompt when no accounts are present.

- [x] **5.3 Create Account Row View (`Views/AccountRowView.swift`)**
  - Display Label / Issuer in bold caption.
  - Display Account Name in muted subheadline text.
  - Large monospace text display for the active 6-digit TOTP code (e.g., `123 456`).
  - Single-click "Copy Code" button with visual feedback indicator ("Copied!").
  - Hover state context action (Right-click or trash icon to Delete Account).

---

## Phase 6: Manual Entry & Account Association

- [x] **6.1 Create Add Account Sheet (`Views/AddAccountSheet.swift`)**
  - Modal sheet triggered by the **"+"** button in `MainListView`.
  - Segmented Picker: **"Raw Secret Key"** vs **"Paste otpauth:// URI"**.

- [x] **6.2 Implement Manual Secret Form Fields**
  - Input field for **Service / Issuer** (e.g., `AWS`).
  - Input field for **Account Name / Email** (e.g., `admin@company.com`).
  - Secure / Plaintext togglable input for **Base32 Secret String** (e.g., `JBSWY3DPEHPK3PXP`).
  - Advanced section (optional disclosure group):
    - Digits: 6 or 8 (Picker).
    - Interval: 30s or 60s (Picker).

- [x] **6.3 Implement URI Paste Parser Field**
  - Single large text field for pasting `otpauth://` link.
  - Real-time URI validation status label (green checkmark for valid, red error text for invalid).
  - Auto-fill Label, Account Name, and Secret fields upon valid URI paste.

- [x] **6.4 Input Validation & Error Handling**
  - Sanitize spaces and formatting characters in key entries.
  - Validate that secret contains valid Base32 characters.
  - Validate non-empty Account / Service name.
  - Alert/Error presentation for failure scenarios.

---

## Phase 7: Dynamic Timer & UX Polish

- [x] **7.1 Implement Clock Synchronization Timer (`ViewModels/AccountListViewModel.swift`)**
  - Setup a 1-second interval timer using `Timer.publish`.
  - Compute current epoch interval remaining: `30 - (Int(Date().timeIntervalSince1970) % 30)`.
  - Trigger code re-computation synchronously across all active accounts when remaining time hits 30 or 0.

- [x] **7.2 Add Circular Countdown Timer UI (`Views/TimerProgressView.swift`)**
  - Radial ring or progress bar shrinking as time ticks down from 30 to 0.
  - Smooth color transition (Blue $\rightarrow$ Orange when time $< 5$s remaining).

- [x] **7.3 Add Clipboard Functionality**
  - Copy code to `NSPasteboard.general`.
  - Show transient popover / toast notice: *"Copied to clipboard!"*.

---

## Phase 8: Security \& Production Hardening

- [x] **8.1 Add Auto-Lock & Biometric Protection (Touch ID)**
  - Integrate `LocalAuthentication` framework (`LAContext`).
  - Option to require Touch ID / System Password when clicking menu bar icon.

- [x] **8.2 Privacy Protections**
  - Clear clipboard automatically after 30 seconds.
  - Ensure window content obscures or hides when main window loses focus.

- [x] **8.3 Testing & Build Validation**
  - Verify generated TOTP tokens against reference apps (Google Authenticator / 1Password / Authy).
  - Test behavior during macOS dark mode and system theme switches.
