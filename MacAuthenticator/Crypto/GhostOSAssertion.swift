import CryptoKit
import Foundation

enum GhostOSAssertionError: LocalizedError {
    case emptyChallenge
    case invalidLength(actual: Int)
    case invalidCharacter(Character)
    case invalidOrigin
    case invalidPublicKey
    case assertionTooLarge

    var errorDescription: String? {
        switch self {
        case .emptyChallenge:
            return "GhostOS login challenge is empty."
        case .invalidLength(let actual):
            return "GhostOS login challenge must be exactly 64 hex characters, got \(actual)."
        case .invalidCharacter(let character):
            return "GhostOS login challenge contains a non-hex character: \"\(character)\"."
        case .invalidOrigin:
            return "GhostOS origin must be http://localhost with a valid port."
        case .invalidPublicKey:
            return "The passkey did not produce a valid P-256 public key."
        case .assertionTooLarge:
            return "The WebAuthn assertion is too large for GhostOS."
        }
    }
}

enum GhostOSAssertion {
    static let relyingPartyID = "localhost"
    static let challengeHexLength = 64
    static let challengeByteCount = 32
    static let maximumAssertionByteCount = 512

    private static let magic: [UInt8] = [0x53, 0x59, 0x57, 0x42]
    private static let separators: Set<Character> = [" ", "\t", "\n", "\r", ":", "-"]
    private static let asciiHexDigits: Set<Character> = [
        "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
        "a", "b", "c", "d", "e", "f",
        "A", "B", "C", "D", "E", "F"
    ]

    static func coseES256PublicKey(fromX963Representation representation: Data) throws -> Data {
        guard representation.count == 65, representation.first == 0x04 else {
            throw GhostOSAssertionError.invalidPublicKey
        }

        let x = representation[1..<33]
        let y = representation[33..<65]
        var cose = Data([0xa5, 0x01, 0x02, 0x03, 0x26, 0x20, 0x01, 0x21, 0x58, 0x20])
        cose.append(x)
        cose.append(contentsOf: [0x22, 0x58, 0x20])
        cose.append(y)
        return cose
    }

    static func packedAssertion(
        challengeHex: String,
        origin: URL,
        signCount: UInt32 = 0,
        signer: (Data) throws -> Data
    ) throws -> Data {
        let challenge = Data(try challengeBytes(fromHex: challengeHex))
        guard isValid(origin: origin) else { throw GhostOSAssertionError.invalidOrigin }

        let clientObject: [String: Any] = [
            "type": "webauthn.get",
            "challenge": challenge.base64URLEncodedString(),
            "origin": origin.absoluteString,
            "crossOrigin": false
        ]
        let clientData = try JSONSerialization.data(withJSONObject: clientObject, options: [.sortedKeys])

        var authenticatorData = Data(SHA256.hash(data: Data(relyingPartyID.utf8)))
        authenticatorData.append(0x05)
        authenticatorData.append(UInt8((signCount >> 24) & 0xff))
        authenticatorData.append(UInt8((signCount >> 16) & 0xff))
        authenticatorData.append(UInt8((signCount >> 8) & 0xff))
        authenticatorData.append(UInt8(signCount & 0xff))

        var signedData = authenticatorData
        signedData.append(Data(SHA256.hash(data: clientData)))
        let signature = try signer(signedData)

        var packed = Data(magic)
        packed.append(contentsOf: [0x01, 0x00, 0x00, 0x00])
        appendLE16(authenticatorData.count, to: &packed)
        appendLE16(clientData.count, to: &packed)
        packed.append(authenticatorData)
        packed.append(clientData)
        packed.append(signature)

        guard packed.count <= maximumAssertionByteCount else {
            throw GhostOSAssertionError.assertionTooLarge
        }
        return packed
    }

    static func challengeBytes(fromHex value: String) throws -> [UInt8] {
        var cleaned = ""
        cleaned.reserveCapacity(value.count)

        for character in value {
            if separators.contains(character) { continue }
            guard asciiHexDigits.contains(character) else {
                throw GhostOSAssertionError.invalidCharacter(character)
            }
            cleaned.append(character.lowercased())
        }

        if cleaned.isEmpty { throw GhostOSAssertionError.emptyChallenge }
        guard cleaned.count == challengeHexLength else {
            throw GhostOSAssertionError.invalidLength(actual: cleaned.count)
        }

        var bytes = [UInt8]()
        bytes.reserveCapacity(challengeByteCount)
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(after: index)
            guard let high = cleaned[index].hexDigitValue,
                  let low = cleaned[next].hexDigitValue else {
                throw GhostOSAssertionError.invalidCharacter(cleaned[index])
            }
            bytes.append(UInt8(high << 4 | low))
            index = cleaned.index(after: next)
        }
        return bytes
    }

    static func isValid(origin: URL) -> Bool {
        origin.scheme == "http"
            && origin.host?.lowercased() == relyingPartyID
            && origin.port.map { (1...65_535).contains($0) } == true
            && (origin.path.isEmpty || origin.path == "/")
            && origin.query == nil
            && origin.fragment == nil
            && origin.user == nil
            && origin.password == nil
    }

    private static func appendLE16(_ value: Int, to data: inout Data) {
        data.append(UInt8(value & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
    }
}

extension Data {
    var lowercaseHexString: String {
        map { String(format: "%02x", $0) }.joined()
    }

    fileprivate func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
