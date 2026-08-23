import CryptoKit
import XCTest
@testable import MacAuthenticator

final class GhostOSAssertionTests: XCTestCase {
    func testCOSEES256PublicKeyHasExpectedShape() throws {
        let key = P256.Signing.PrivateKey()
        let cose = try GhostOSAssertion.coseES256PublicKey(
            fromX963Representation: key.publicKey.x963Representation
        )

        XCTAssertEqual(cose.count, 77)
        XCTAssertEqual(Array(cose.prefix(10)), [
            0xa5, 0x01, 0x02, 0x03, 0x26, 0x20, 0x01, 0x21, 0x58, 0x20
        ])
        XCTAssertEqual(Array(cose[42..<45]), [0x22, 0x58, 0x20])
    }

    func testSYWBAssertionContainsValidSignatureAndWebAuthnData() throws {
        let key = P256.Signing.PrivateKey()
        let challenge = String(repeating: "01", count: 32)
        let origin = URL(string: "http://localhost:43127")!
        let packed = try GhostOSAssertion.packedAssertion(
            challengeHex: challenge,
            origin: origin,
            signer: { try key.signature(for: $0).derRepresentation }
        )

        XCTAssertEqual(Array(packed[0..<8]), [0x53, 0x59, 0x57, 0x42, 1, 0, 0, 0])
        let authenticatorLength = Int(packed[8]) | Int(packed[9]) << 8
        let clientLength = Int(packed[10]) | Int(packed[11]) << 8
        XCTAssertEqual(authenticatorLength, 37)

        let authenticatorStart = 12
        let clientStart = authenticatorStart + authenticatorLength
        let signatureStart = clientStart + clientLength
        let authenticatorData = packed[authenticatorStart..<clientStart]
        let clientData = packed[clientStart..<signatureStart]
        let signature = try P256.Signing.ECDSASignature(derRepresentation: packed[signatureStart...])

        XCTAssertEqual(authenticatorData[authenticatorData.startIndex + 32], 0x05)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: clientData) as? [String: Any]
        )
        XCTAssertEqual(object["type"] as? String, "webauthn.get")
        XCTAssertEqual(object["origin"] as? String, origin.absoluteString)
        XCTAssertEqual(
            object["challenge"] as? String,
            "AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE"
        )

        var signedData = Data(authenticatorData)
        signedData.append(Data(SHA256.hash(data: clientData)))
        XCTAssertTrue(key.publicKey.isValidSignature(signature, for: signedData))
    }

    func testRejectsInvalidChallengeAndOrigin() {
        XCTAssertThrowsError(try GhostOSAssertion.challengeBytes(fromHex: ""))
        XCTAssertThrowsError(try GhostOSAssertion.challengeBytes(fromHex: String(repeating: "0", count: 63)))
        XCTAssertThrowsError(try GhostOSAssertion.challengeBytes(fromHex: String(repeating: "g", count: 64)))
        XCTAssertFalse(GhostOSAssertion.isValid(origin: URL(string: "https://localhost:1234")!))
        XCTAssertFalse(GhostOSAssertion.isValid(origin: URL(string: "http://example.com:1234")!))
        XCTAssertTrue(GhostOSAssertion.isValid(origin: URL(string: "http://localhost:1234")!))
    }
}
