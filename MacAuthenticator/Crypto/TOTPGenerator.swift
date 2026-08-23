import CryptoKit
import Foundation

enum TOTPAlgorithm: String, Codable, CaseIterable {
    case sha1 = "SHA1"
    case sha256 = "SHA256"
    case sha512 = "SHA512"

    init(uriValue: String?) {
        switch uriValue?.uppercased() {
        case "SHA256":
            self = .sha256
        case "SHA512":
            self = .sha512
        default:
            self = .sha1
        }
    }
}

enum TOTPGenerator {
    static func generate(
        secret: Data,
        time: Date = Date(),
        period: Int = 30,
        digits: Int = 6,
        algorithm: TOTPAlgorithm = .sha1
    ) -> String {
        let safePeriod = max(period, 1)
        let counter = UInt64(floor(time.timeIntervalSince1970 / Double(safePeriod)))
        return generate(secret: secret, counter: counter, digits: digits, algorithm: algorithm)
    }

    static func generate(
        secret: Data,
        counter: UInt64,
        digits: Int = 6,
        algorithm: TOTPAlgorithm = .sha1
    ) -> String {
        var bigEndian = counter.bigEndian
        let counterData = withUnsafeBytes(of: &bigEndian) { Data($0) }
        let hash = hmac(message: counterData, key: secret, algorithm: algorithm)

        let offset = Int(hash[hash.count - 1] & 0x0F)
        let truncatedHash = hash[offset..<offset + 4]
        var value: UInt32 = 0
        for byte in truncatedHash {
            value = (value << 8) | UInt32(byte)
        }
        value &= 0x7FFF_FFFF

        let safeDigits = min(max(digits, 6), 8)
        let modulus = UInt32(pow(10, Double(safeDigits)))
        let otp = value % modulus
        return String(format: "%0\(safeDigits)u", otp)
    }

    static func remainingSeconds(period: Int = 30, at date: Date = Date()) -> Int {
        let safePeriod = max(period, 1)
        let elapsed = Int(date.timeIntervalSince1970) % safePeriod
        let remaining = safePeriod - elapsed
        return remaining == 0 ? safePeriod : remaining
    }

    private static func hmac(message: Data, key: Data, algorithm: TOTPAlgorithm) -> Data {
        let symmetricKey = SymmetricKey(data: key)
        switch algorithm {
        case .sha1:
            return Data(HMAC<Insecure.SHA1>.authenticationCode(for: message, using: symmetricKey))
        case .sha256:
            return Data(HMAC<SHA256>.authenticationCode(for: message, using: symmetricKey))
        case .sha512:
            return Data(HMAC<SHA512>.authenticationCode(for: message, using: symmetricKey))
        }
    }
}
