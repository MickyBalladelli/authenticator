import Combine
import Foundation
import LocalAuthentication

@MainActor
final class GhostOSLoginViewModel: ObservableObject {
    @Published var connectionURL = ""
    @Published var username = UserDefaults.standard.string(forKey: "ghostOSUsername") ?? ""
    @Published private(set) var mode = "disconnected"
    @Published private(set) var message = "Paste the one-time URL printed by the GhostOS VM."
    @Published private(set) var errorMessage = ""
    @Published private(set) var isBusy = false

    var isConnected: Bool { mode != "disconnected" }
    var canAuthenticate: Bool { mode == "enroll" || mode == "login" }
    var actionTitle: String { mode == "enroll" ? "Create Passkey" : "Use Passkey" }

    private var client: GhostOSBridgeClient?
    private var pollTask: Task<Void, Never>?

    deinit {
        pollTask?.cancel()
    }

    func connect() {
        guard !isBusy else { return }
        do {
            let client = try GhostOSBridgeClient(connectionURL: connectionURL)
            self.client = client
            errorMessage = ""
            mode = "waiting"
            message = "Connecting to GhostOS…"
            startPolling(client)
        } catch {
            show(error)
        }
    }

    func disconnect() {
        pollTask?.cancel()
        pollTask = nil
        client = nil
        mode = "disconnected"
        message = "Paste the one-time URL printed by the GhostOS VM."
        errorMessage = ""
        isBusy = false
    }

    func authenticate() {
        guard let client, canAuthenticate, !isBusy else { return }
        let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedUsername.range(
            of: "^[A-Za-z0-9._$-]{1,32}$",
            options: .regularExpression
        ) != nil else {
            errorMessage = "Use 1–32 letters, numbers, or . _ - $"
            return
        }

        isBusy = true
        errorMessage = ""
        pollTask?.cancel()
        let requestedMode = mode

        Task {
            defer {
                isBusy = false
                if self.client != nil { startPolling(client) }
            }
            do {
                UserDefaults.standard.set(normalizedUsername, forKey: "ghostOSUsername")

                if requestedMode == "enroll" {
                    let context = try await verifyUser(reason: "Create a GhostOS passkey")
                    let coseKey = try GhostOSCredentialStore.shared.enroll(
                        username: normalizedUsername,
                        context: context
                    )
                    try await client.enroll(username: normalizedUsername, coseKey: coseKey)
                    message = "Passkey created. GhostOS is creating the administrator account…"
                    mode = "waiting"
                } else {
                    try await client.startLogin(username: normalizedUsername)
                    message = "Waiting for the GhostOS challenge…"
                    mode = "waiting"
                    let challenge = try await client.waitForChallenge()
                    let context = try await verifyUser(reason: "Use your GhostOS passkey")
                    let assertion = try GhostOSCredentialStore.shared.assertion(
                        username: normalizedUsername,
                        challengeHex: challenge,
                        origin: client.origin,
                        context: context
                    )
                    try await client.completeLogin(assertion: assertion)
                    message = "GhostOS is verifying the passkey…"
                }
            } catch is CancellationError {
                return
            } catch {
                show(error)
            }
        }
    }

    private func startPolling(_ client: GhostOSBridgeClient) {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                do {
                    apply(try await client.state())
                } catch is CancellationError {
                    return
                } catch {
                    show(error)
                    mode = "disconnected"
                    self.client = nil
                    return
                }
                try? await Task.sleep(nanoseconds: 750_000_000)
            }
        }
    }

    private func apply(_ state: GhostOSBridgeState) {
        mode = state.mode
        errorMessage = state.error
        switch state.mode {
        case "enroll":
            message = "Create an administrator passkey for this GhostOS machine."
        case "login":
            message = "Unlock GhostOS with your saved passkey."
        case "success":
            message = "Authentication accepted. GhostOS is unlocked."
        default:
            message = "Waiting for GhostOS…"
        }
    }

    private func verifyUser(reason: String) async throws -> LAContext {
        let context = LAContext()
        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            throw policyError ?? GhostOSCredentialError.userVerificationFailed
        }
        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
                if success {
                    continuation.resume(returning: context)
                } else {
                    continuation.resume(
                        throwing: error ?? GhostOSCredentialError.userVerificationFailed
                    )
                }
            }
        }
    }

    private func show(_ error: Error) {
        errorMessage = error.localizedDescription
    }
}
