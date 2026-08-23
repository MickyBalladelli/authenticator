import XCTest
@testable import MacAuthenticator

final class GhostOSAssertionTests: XCTestCase {
    /// Expected "SYPA" v1 assertion for the all-zero challenge:
    /// magic + version/reserved + challenge + section lengths + rpIdHash +
    /// UP|UV flags + signCount + client data + signature (85 bytes total).
    private let allZeroExpected =
        "5359504101000000" +
        String(repeating: "0", count: 64) +
        "250001000100" +
        String(repeating: "0", count: 64) +
        "05000000000000"

    func testAllZeroChallengeVector() throws {
        let assertion = try GhostOSAssertion.assertion(forChallengeHex: String(repeating: "0", count: 64))
        XCTAssertEqual(assertion.count, 170)
        XCTAssertEqual(assertion, allZeroExpected)
    }

    func testChallengeEchoedVerbatimAtOffset8() throws {
        let challengeHex = "a1b2c3d4e5f60718293a4b5c6d7e8f90deadbeefcafe011223344556677889999"
        let assertion = try GhostOSAssertion.assertion(forChallengeHex: challengeHex)
        XCTAssertEqual(assertion.count, 170)

        let bytes = assertion.hexToBytes()
        XCTAssertEqual(bytes.count, GhostOSAssertion.assertionByteCount)
        XCTAssertEqual(Array(bytes[8..<40]), Array(challengeHex.lowercased().hexToBytes()[0..<32]))

        // Magic "SYPA" and version 0x01
        XCTAssertEqual(Array(bytes[0..<4]), [0x53, 0x59, 0x50, 0x41])
        XCTAssertEqual(bytes[4], 0x01)
    }

    func testFlagsByteAtOffset78() throws {
        let assertion = try GhostOSAssertion.assertion(forChallengeHex: String(repeating: "f", count: 64))
        let flags = assertion.hexToBytes()[46 + 32]
        XCTAssertEqual(flags, 0x05)
    }

    func testRejectsWrongLengthAndInvalidInput() {
        // 63 hex chars
        XCTAssertThrowsError(try GhostOSAssertion.assertion(forChallengeHex: String(repeating: "0", count: 63)))
        // Non-hex characters
        XCTAssertThrowsError(try GhostOSAssertion.assertion(forChallengeHex: String(repeating: "g", count: 64)))
        XCTAssertThrowsError(try GhostOSAssertion.assertion(forChallengeHex: "zz"))
        // Empty input
        XCTAssertThrowsError(try GhostOSAssertion.assertion(forChallengeHex: ""))
    }

    func testNormalizesSeparatorsAndCase() throws {
        let lowercase = String(repeating: "0", count: 64)
        let uppercase = lowercase.uppercased()
        let colonSeparated = lowercase.separated(by: ":", every: 2)
        let dashedUppercase = uppercase.separated(by: "-", every: 8)
        let padded = "   \(dashedUppercase)\n"

        for input in [uppercase, colonSeparated, dashedUppercase, padded] {
            let assertion = try GhostOSAssertion.assertion(forChallengeHex: input)
            XCTAssertEqual(assertion, allZeroExpected)
        }
    }
}

private extension String {
    func hexToBytes() -> [UInt8] {
        var bytes = [UInt8]()
        bytes.reserveCapacity(count / 2)
        var index = startIndex
        while index < endIndex {
            let next = self.index(after: index)
            bytes.append(UInt8(String(self[index...next]), radix: 16)!)
            index = self.index(after: next)
        }
        return bytes
    }

    func separated(by separator: String, every chunk: Int) -> String {
        stride(from: 0, to: count, by: chunk)
            .map { Array(String(self))[$0..<min($0 + chunk, count)] }
            .joined(separator: separator)
    }
}
