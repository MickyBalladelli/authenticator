import XCTest
@testable import MacAuthenticator

final class TOTPGeneratorTests: XCTestCase {
    /// RFC 6238 Appendix B test vector secret ("12345678901234567890")
    private let sha1Secret = "12345678901234567890".data(using: .ascii)!

    func testRFC6238SHA1Vectors() {
        let vectors: [(time: TimeInterval, expected: String)] = [
            (59, "94287082"),
            (1_111_111_109, "07081804"),
            (1_111_111_111, "14050471"),
            (1_234_567_890, "89005924"),
            (2_000_000_000, "69279037"),
            (20_000_000_000, "65353130")
        ]

        for vector in vectors {
            let code = TOTPGenerator.generate(
                secret: sha1Secret,
                time: Date(timeIntervalSince1970: vector.time),
                period: 30,
                digits: 8,
                algorithm: .sha1
            )
            XCTAssertEqual(code, vector.expected, "Failed for time \(vector.time)")
        }
    }

    func testSixDigitZeroPadding() {
        // Known seed from common authenticator examples
        let secret = Base32.decode("JBSWY3DPEHPK3PXP")!
        let code = TOTPGenerator.generate(
            secret: secret,
            counter: 1,
            digits: 6,
            algorithm: .sha1
        )
        XCTAssertEqual(code.count, 6)
        XCTAssertTrue(code.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) })
    }

    func testRemainingSeconds() {
        // 10 seconds into a 30s window -> 20 remaining
        let date = Date(timeIntervalSince1970: 40)
        XCTAssertEqual(TOTPGenerator.remainingSeconds(period: 30, at: date), 20)

        // Exactly on boundary -> full period
        let boundary = Date(timeIntervalSince1970: 60)
        XCTAssertEqual(TOTPGenerator.remainingSeconds(period: 30, at: boundary), 30)
    }
}
