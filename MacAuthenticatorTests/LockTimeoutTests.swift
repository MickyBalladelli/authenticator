import XCTest
@testable import MacAuthenticator

final class LockTimeoutTests: XCTestCase {
    func testRawValuesAreStable() {
        // Persisted in UserDefaults; changing these invalidates saved settings.
        XCTAssertEqual(LockTimeout.always.rawValue, 0)
        XCTAssertEqual(LockTimeout.fiveMinutes.rawValue, 300)
        XCTAssertEqual(LockTimeout.oneHour.rawValue, 3_600)
        XCTAssertEqual(LockTimeout.threeHours.rawValue, 10_800)
    }

    func testRoundTrip() {
        for timeout in LockTimeout.allCases {
            XCTAssertEqual(LockTimeout(rawValue: timeout.rawValue), timeout)
        }
    }

    func testAllCasesCount() {
        XCTAssertEqual(LockTimeout.allCases.count, 4)
    }

    func testUnknownRawValueIsNil() {
        // Call sites must treat unknown persisted values as .always.
        XCTAssertNil(LockTimeout(rawValue: 42))
        XCTAssertEqual(LockTimeout(rawValue: 42) ?? .always, .always)
    }
}
