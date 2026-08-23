import XCTest
@testable import MacAuthenticator

final class Base32Tests: XCTestCase {
    /// Classic authenticator demo secret: "Hello!" + 0xDEADBEEF
    private let demoSecret = Data([0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x21, 0xDE, 0xAD, 0xBE, 0xEF])

    func testDecodesStandardVector() {
        let data = Base32.decode("JBSWY3DPEHPK3PXP")
        XCTAssertEqual(data, demoSecret)
    }

    func testDecodesHelloWithPadding() {
        let data = Base32.decode("JBSWY3DPEE======")
        XCTAssertEqual(data.flatMap { String(data: $0, encoding: .utf8) }, "Hello!")
    }

    func testIgnoresSpacesPaddingAndCase() {
        let data = Base32.decode("jbswy3dpehpk3pxp====")
        XCTAssertEqual(data, demoSecret)

        let spaced = Base32.decode("JBSW Y3DP EHPK 3PXP")
        XCTAssertEqual(spaced, demoSecret)
    }

    func testRejectsInvalidCharacters() {
        XCTAssertNil(Base32.decode("JBSWY3DP!HPK3PXP"))
        XCTAssertFalse(Base32.isValid("@@@@"))
    }

    func testEmptyOrWhitespaceReturnsNil() {
        XCTAssertNil(Base32.decode(""))
        XCTAssertNil(Base32.decode("   "))
        XCTAssertNil(Base32.decode("===="))
    }
}
