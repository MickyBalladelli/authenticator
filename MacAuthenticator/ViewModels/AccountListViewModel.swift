import AppKit
import Combine
import Foundation
import LocalAuthentication
import SwiftUI

/// How long codes stay unlocked after a successful authentication before the
/// next prompt. Raw values are persisted in UserDefaults; do not renumber.
enum LockTimeout: Int, CaseIterable, Identifiable {
    case always = 0
    case fiveMinutes = 300
    case oneHour = 3_600
    case threeHours = 10_800

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .always: return "Always"
        case .fiveMinutes: return "5 minutes"
        case .oneHour: return "1 hour"
        case .threeHours: return "3 hours"
        }
    }
}

@MainActor
final class AccountListViewModel: ObservableObject {
    @Published private(set) var accounts: [Account] = []
    @Published private(set) var codes: [UUID: String] = [:]
    @Published private(set) var remainingSeconds: Int = 30
    @Published private(set) var isUnlocked: Bool = true
    @Published private(set) var isContentHidden: Bool = false
    @Published var showAddSheet = false
    @Published var toastMessage: String?
    @Published var errorMessage: String?

    @AppStorage("requireAuthentication") var requireAuthentication = false

    /// Persisted "ask again after" choice (LockTimeout rawValue).
    @AppStorage("lockTimeoutRaw") var lockTimeoutRaw = LockTimeout.always.rawValue

    /// In-memory only: when authentication last succeeded. Never persisted.
    private var lastUnlockDate: Date?
    private var isAuthenticating = false

    private var lockTimeout: LockTimeout {
        LockTimeout(rawValue: lockTimeoutRaw) ?? .always
    }

    private var isWithinGracePeriod: Bool {
        guard let last = lastUnlockDate, lockTimeout != .always else { return false }
        return Date().timeIntervalSince(last) < TimeInterval(lockTimeout.rawValue)
    }

    private let store: AccountStore
    private var timerCancellable: AnyCancellable?
    private var toastCancellable: AnyCancellable?
    private var clipboardClearWorkItem: DispatchWorkItem?
    private var lastCopiedCode: String?
    private var lastPeriodBucket: Int = -1

    init(store: AccountStore = .shared) {
        self.store = store
        reload()
        startTimer()
        if requireAuthentication {
            isUnlocked = false
        }
    }

    func reload() {
        accounts = store.loadAccounts().sorted { $0.createdAt < $1.createdAt }
        regenerateCodes(force: true)
    }

    func startTimer() {
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                self?.tick(at: date)
            }
    }

    func tick(at date: Date = Date()) {
        let globalPeriod = accounts.map(\.period).min() ?? 30
        remainingSeconds = TOTPGenerator.remainingSeconds(period: globalPeriod, at: date)

        let bucket = Int(date.timeIntervalSince1970) / max(globalPeriod, 1)
        if bucket != lastPeriodBucket {
            lastPeriodBucket = bucket
            regenerateCodes(force: true, at: date)
        } else {
            regenerateCodes(force: false, at: date)
        }
    }

    func regenerateCodes(force: Bool, at date: Date = Date()) {
        guard isUnlocked else {
            codes = [:]
            return
        }

        var next: [UUID: String] = [:]
        for account in accounts {
            if !force, let existing = codes[account.id] {
                next[account.id] = existing
                continue
            }
            guard let secretString = store.secret(for: account),
                  let secretData = Base32.decode(secretString) else {
                next[account.id] = String(repeating: "•", count: account.digits)
                continue
            }
            next[account.id] = TOTPGenerator.generate(
                secret: secretData,
                time: date,
                period: account.period,
                digits: account.digits,
                algorithm: account.algorithm
            )
        }
        codes = next
    }

    func code(for account: Account) -> String {
        guard isUnlocked, !isContentHidden else {
            return String(repeating: "•", count: account.digits)
        }
        return codes[account.id] ?? String(repeating: "•", count: account.digits)
    }

    func formattedCode(for account: Account) -> String {
        let raw = code(for: account)
        guard raw.count == 6 || raw.count == 8, !raw.contains("•") else { return raw }
        let mid = raw.count / 2
        return "\(raw.prefix(mid)) \(raw.suffix(raw.count - mid))"
    }

    func addAccount(
        label: String,
        accountName: String,
        secret: String,
        digits: Int,
        period: Int,
        algorithm: TOTPAlgorithm = .sha1
    ) {
        do {
            _ = try store.addAccount(
                label: label,
                accountName: accountName,
                secret: secret,
                digits: digits,
                period: period,
                algorithm: algorithm
            )
            showAddSheet = false
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteAccount(_ account: Account) {
        do {
            try store.deleteAccount(account)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func copyCode(for account: Account) {
        let raw = code(for: account)
        guard !raw.contains("•") else { return }
        copyToClipboard(raw, clearsAfterDelay: true)
    }

    private func copyToClipboard(_ value: String, clearsAfterDelay: Bool) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        showToast("Copied to clipboard!")

        guard clearsAfterDelay else { return }

        lastCopiedCode = value
        clipboardClearWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.clearClipboardIfNeeded()
        }
        clipboardClearWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: workItem)
    }

    func authenticateIfNeeded() {
        guard !isAuthenticating else { return }

        guard requireAuthentication else {
            isUnlocked = true
            regenerateCodes(force: true)
            return
        }

        // Within the grace window after a successful unlock: no prompt,
        // whether the app is still unlocked or was soft-locked meanwhile.
        if isWithinGracePeriod {
            isUnlocked = true
            regenerateCodes(force: true)
            return
        }

        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // If biometrics/password unavailable, keep unlocked so the app remains usable.
            isUnlocked = true
            regenerateCodes(force: true)
            return
        }

        isUnlocked = false
        codes = [:]
        isAuthenticating = true
        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Unlock authenticator codes"
        ) { [weak self] success, _ in
            Task { @MainActor in
                guard let self else { return }
                self.isAuthenticating = false
                self.isUnlocked = success
                if success {
                    self.lastUnlockDate = Date()
                    self.regenerateCodes(force: true)
                }
            }
        }
    }

    func unlockWithoutAuthentication() {
        isUnlocked = true
        lastUnlockDate = nil
        regenerateCodes(force: true)
    }

    func lockForPrivacy() {
        guard requireAuthentication else { return }
        // Grace window still active: keep unlocked; inactive windows are
        // already obscured by obscureForInactiveWindow().
        if isWithinGracePeriod && isUnlocked { return }
        isUnlocked = false
        codes = [:]
    }

    func obscureForInactiveWindow() {
        // Soft privacy: hide codes while the menu bar window is inactive.
        isContentHidden = true
    }

    func revealIfUnlocked() {
        isContentHidden = false
        if isUnlocked {
            regenerateCodes(force: true)
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        toastCancellable?.cancel()
        toastCancellable = Just(())
            .delay(for: .seconds(1.5), scheduler: RunLoop.main)
            .sink { [weak self] in
                self?.toastMessage = nil
            }
    }

    private func clearClipboardIfNeeded() {
        let pasteboard = NSPasteboard.general
        guard let current = pasteboard.string(forType: .string),
              let lastCopiedCode,
              current == lastCopiedCode else {
            return
        }
        pasteboard.clearContents()
        self.lastCopiedCode = nil
    }
}
