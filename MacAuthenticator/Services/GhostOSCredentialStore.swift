import CryptoKit
import Foundation
import LocalAuthentication
import Security

enum GhostOSCredentialError: LocalizedError {
    case missingCredential
    case invalidCredential
    case keychainWriteFailed
    case userVerificationFailed

    var errorDescription: String? {
        switch self {
        case .missingCredential:
            return "No passkey exists for this username. Enroll it with GhostOS first."
        case .invalidCredential:
            return "The stored GhostOS passkey is damaged."
        case .keychainWriteFailed:
            return "The GhostOS passkey could not be saved in Keychain."
        case .userVerificationFailed:
            return "Touch ID or system authentication was not accepted."
        }
    }
}

private enum GhostOSSigningKey {
    case secureEnclave(SecureEnclave.P256.Signing.PrivateKey)
    case software(P256.Signing.PrivateKey)

    var publicKeyRepresentation: Data {
        switch self {
        case .secureEnclave(let key):
            return key.publicKey.x963Representation
        case .software(let key):
            return key.publicKey.x963Representation
        }
    }

    var storedRepresentation: Data {
        switch self {
        case .secureEnclave(let key):
            return Data([1]) + key.dataRepresentation
        case .software(let key):
            return Data([0]) + key.rawRepresentation
        }
    }

    func sign(_ data: Data) throws -> Data {
        switch self {
        case .secureEnclave(let key):
            return try key.signature(for: data).derRepresentation
        case .software(let key):
            return try key.signature(for: data).derRepresentation
        }
    }
}

final class GhostOSCredentialStore {
    static let shared = GhostOSCredentialStore()

    private let accountPrefix = "ghostos.passkey.localhost."

    func enroll(username: String, context: LAContext) throws -> Data {
        let key: GhostOSSigningKey
        if let existing = try load(username: username, context: context) {
            key = existing
        } else {
            key = try create(context: context)
            guard KeychainManager.saveData(
                accountID: accountID(username),
                data: key.storedRepresentation
            ) else {
                throw GhostOSCredentialError.keychainWriteFailed
            }
        }
        return try GhostOSAssertion.coseES256PublicKey(
            fromX963Representation: key.publicKeyRepresentation
        )
    }

    func assertion(
        username: String,
        challengeHex: String,
        origin: URL,
        context: LAContext
    ) throws -> Data {
        guard let key = try load(username: username, context: context) else {
            throw GhostOSCredentialError.missingCredential
        }
        return try GhostOSAssertion.packedAssertion(
            challengeHex: challengeHex,
            origin: origin,
            signer: key.sign
        )
    }

    private func create(context: LAContext) throws -> GhostOSSigningKey {
        if SecureEnclave.isAvailable,
           let accessControl = SecAccessControlCreateWithFlags(
               nil,
               kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
               [.privateKeyUsage, .userPresence],
               nil
           ) {
            let key = try SecureEnclave.P256.Signing.PrivateKey(
                accessControl: accessControl,
                authenticationContext: context
            )
            return .secureEnclave(key)
        }
        return .software(P256.Signing.PrivateKey())
    }

    private func load(username: String, context: LAContext) throws -> GhostOSSigningKey? {
        guard let stored = KeychainManager.fetchData(accountID: accountID(username)) else {
            return nil
        }
        guard let kind = stored.first else { throw GhostOSCredentialError.invalidCredential }
        let representation = Data(stored.dropFirst())
        do {
            switch kind {
            case 0:
                return .software(try P256.Signing.PrivateKey(rawRepresentation: representation))
            case 1:
                return .secureEnclave(try SecureEnclave.P256.Signing.PrivateKey(
                    dataRepresentation: representation,
                    authenticationContext: context
                ))
            default:
                throw GhostOSCredentialError.invalidCredential
            }
        } catch let error as GhostOSCredentialError {
            throw error
        } catch {
            throw GhostOSCredentialError.invalidCredential
        }
    }

    private func accountID(_ username: String) -> String {
        accountPrefix + username.lowercased()
    }
}
