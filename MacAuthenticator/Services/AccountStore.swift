import Foundation

enum AccountStoreError: LocalizedError {
    case invalidSecret
    case keychainFailure
    case persistenceFailure

    var errorDescription: String? {
        switch self {
        case .invalidSecret:
            return "The secret key is not valid Base32."
        case .keychainFailure:
            return "Could not store the secret in Keychain."
        case .persistenceFailure:
            return "Could not save account metadata."
        }
    }
}

final class AccountStore {
    static let shared = AccountStore()

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let queue = DispatchQueue(label: "com.micky.MacAuthenticator.AccountStore")

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let directory = support.appendingPathComponent("MacAuthenticator", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            self.fileURL = directory.appendingPathComponent("accounts.json")
        }
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func loadAccounts() -> [Account] {
        queue.sync {
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
            do {
                let data = try Data(contentsOf: fileURL)
                return try decoder.decode([Account].self, from: data)
            } catch {
                return []
            }
        }
    }

    func addAccount(
        label: String,
        accountName: String,
        secret: String,
        digits: Int = 6,
        period: Int = 30,
        algorithm: TOTPAlgorithm = .sha1
    ) throws -> Account {
        let sanitizedSecret = secret
            .uppercased()
            .filter { !$0.isWhitespace && $0 != "=" }

        guard Base32.isValid(sanitizedSecret) else {
            throw AccountStoreError.invalidSecret
        }

        let account = Account(
            label: label.trimmingCharacters(in: .whitespacesAndNewlines),
            accountName: accountName.trimmingCharacters(in: .whitespacesAndNewlines),
            digits: digits,
            period: period,
            algorithm: algorithm
        )

        guard KeychainManager.saveSecret(accountID: account.id.uuidString, secret: sanitizedSecret) else {
            throw AccountStoreError.keychainFailure
        }

        do {
            try queue.sync {
                var accounts = loadAccountsUnlocked()
                accounts.append(account)
                try persistUnlocked(accounts)
            }
        } catch {
            _ = KeychainManager.deleteSecret(accountID: account.id.uuidString)
            throw AccountStoreError.persistenceFailure
        }

        return account
    }

    func deleteAccount(_ account: Account) throws {
        _ = KeychainManager.deleteSecret(accountID: account.id.uuidString)
        try queue.sync {
            var accounts = loadAccountsUnlocked()
            accounts.removeAll { $0.id == account.id }
            try persistUnlocked(accounts)
        }
    }

    func secret(for account: Account) -> String? {
        KeychainManager.fetchSecret(accountID: account.id.uuidString)
    }

    private func loadAccountsUnlocked() -> [Account] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode([Account].self, from: data)
        } catch {
            return []
        }
    }

    private func persistUnlocked(_ accounts: [Account]) throws {
        let data = try encoder.encode(accounts)
        try data.write(to: fileURL, options: [.atomic])
    }
}
