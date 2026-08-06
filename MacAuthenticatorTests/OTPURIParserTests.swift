import XCTest
@testable import MacAuthenticator

final class OTPURIParserTests: XCTestCase {
    func testParsesStandardTOTPURI() {
        let uri = "otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&digits=6&period=30"
        let result = OTPURIParser.parse(uri)

        guard case .success(let params) = result else {
            return XCTFail("Expected success, got \(result)")
        }

        XCTAssertEqual(params.label, "Example")
        XCTAssertEqual(params.accountName, "alice@google.com")
        XCTAssertEqual(params.secret, "JBSWY3DPEHPK3PXP")
        XCTAssertEqual(params.digits, 6)
        XCTAssertEqual(params.period, 30)
        XCTAssertEqual(params.algorithm, .sha1)
    }

    func testUsesQueryIssuerWhenLabelHasNoColon() {
        let uri = "otpauth://totp/alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Google"
        let result = OTPURIParser.parse(uri)
        guard case .success(let params) = result else {
            return XCTFail("Expected success")
        }
        XCTAssertEqual(params.label, "Google")
        XCTAssertEqual(params.accountName, "alice@google.com")
    }

    func testRejectsHOTP() {
        let uri = "otpauth://hotp/Example:alice?secret=JBSWY3DPEHPK3PXP&counter=1"
        let result = OTPURIParser.parse(uri)
        guard case .failure(let error) = result else {
            return XCTFail("Expected failure for HOTP")
        }
        XCTAssertEqual(error, .unsupportedType("hotp"))
    }

    func testRejectsInvalidSecretAndMissingSecret() {
        XCTAssertEqual(OTPURIParser.parse("otpauth://totp/A?secret=!!!!"), .failure(.invalidSecret))
        XCTAssertEqual(OTPURIParser.parse("otpauth://totp/A"), .failure(.missingSecret))
        XCTAssertEqual(OTPURIParser.parse("https://example.com"), .failure(.unsupportedScheme))
    }

    func testParsesCustomDigitsPeriodAndAlgorithm() {
        let uri = "otpauth://totp/GitHub:user?secret=JBSWY3DPEHPK3PXP&digits=8&period=60&algorithm=SHA256"
        let result = OTPURIParser.parse(uri)
        guard case .success(let params) = result else {
            return XCTFail("Expected success")
        }
        XCTAssertEqual(params.digits, 8)
        XCTAssertEqual(params.period, 60)
        XCTAssertEqual(params.algorithm, .sha256)
    }
}
