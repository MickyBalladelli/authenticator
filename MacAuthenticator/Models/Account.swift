import Foundation

struct Account: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var label: String
    var accountName: String
    var digits: Int
    var period: Int
    var algorithm: TOTPAlgorithm
    var createdAt: Date

    init(
        id: UUID = UUID(),
        label: String,
        accountName: String,
        digits: Int = 6,
        period: Int = 30,
        algorithm: TOTPAlgorithm = .sha1,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.label = label
        self.accountName = accountName
        self.digits = digits
        self.period = period
        self.algorithm = algorithm
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        label = try container.decode(String.self, forKey: .label)
        accountName = try container.decode(String.self, forKey: .accountName)
        digits = try container.decodeIfPresent(Int.self, forKey: .digits) ?? 6
        period = try container.decodeIfPresent(Int.self, forKey: .period) ?? 30
        algorithm = try container.decodeIfPresent(TOTPAlgorithm.self, forKey: .algorithm) ?? .sha1
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    /// Display name preferring issuer label, falling back to account name.
    var displayTitle: String {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedLabel.isEmpty ? accountName : trimmedLabel
    }
}
