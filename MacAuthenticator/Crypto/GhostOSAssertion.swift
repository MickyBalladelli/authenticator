import Foundation

enum GhostOSAssertionError: LocalizedError {
    case emptyChallenge
    case invalidLength(actual: Int)
    case invalidCharacter(Character)

    var errorDescription: String? {
        switch self {
        case .emptyChallenge:
            return "GhostOS login challenge is empty. Copy the 32 bytes shown after \"Challenge:\"."
        case .invalidLength(let actual):
            return "GhostOS login challenge must be exactly 64 hex characters (32 bytes), got \(actual)."
        case .invalidCharacter(let character):
            return "GhostOS login challenge contains a non-hex character: \"\(character)\"."
        }
    }
}

/// Builds "SYPA" v1 passkey assertion blobs for GhostOS local-console logins.
///
/// Mirrors the structural check in the GhostOS kernel
/// (`valid_local_passkey_assertion()`): magic, version, verbatim challenge echo,
/// authenticator data with UP|UV flags, then client data and signature.
///
/// Assertions are credential-bearing artifacts: callers must not log or store
/// them, and challenges are one-shot — a rejected assertion requires fetching a
/// new challenge, never replay.
enum GhostOSAssertion {
    /// Length of the challenge hex string after separator stripping.
    static let challengeHexLength = 64
    /// Byte length of the challenge embedded at offsets 8..40.
    static let challengeByteCount = 32
    /// Total assertion size with default client data and signature (170 hex chars).
    static let assertionByteCount = 85

    private static let magic: [UInt8] = [0x53, 0x59, 0x50, 0x41] // "SYPA"
    private static let version: UInt8 = 0x01
    private static let authenticatorDataLength = 37
    private static let clientDataLength = 1
    private static let signatureLength = 1
    private static let userPresenceFlag: UInt8 = 0x01
    private static let userVerificationFlag: UInt8 = 0x04

    private static let separators: Set<Character> = [" ", "\t", "\n", "\r", ":", "-"]
    private static let asciiHexDigits: Set<Character> = [
        "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
        "a", "b", "c", "d", "e", "f",
        "A", "B", "C", "D", "E", "F"
    ]

    /// Builds the "SYPA" v1 assertion for a console login challenge.
    ///
    /// - Parameter challengeHex: The 32-byte challenge from the GhostOS console,
    ///   given as hex with optional spaces, colons, dashes, and mixed case.
    /// - Returns: The assertion as a lowercase hex string (170 chars by default),
    ///   ready to paste at the console's "Passkey assertion:" prompt.
    static func assertion(forChallengeHex challengeHex: String) throws -> String {
        let challenge = try challengeBytes(fromHex: challengeHex)

        var blob = Data()
        blob.reserveCapacity(assertionByteCount)
        blob.append(contentsOf: magic)
        blob.append(version)
        blob.append(contentsOf: [0x00, 0x00, 0x00])
        blob.append(contentsOf: challenge)
        appendLE16(authenticatorDataLength, to: &blob)
        appendLE16(clientDataLength, to: &blob)
        appendLE16(signatureLength, to: &blob)
        blob.append(contentsOf: [UInt8](repeating: 0x00, count: challengeByteCount))
        blob.append(userPresenceFlag | userVerificationFlag)
        blob.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
        blob.append(0x00)
        blob.append(0x00)
        return blob.map { String(format: "%02x", $0) }.joined()
    }

    /// Validates and decodes a console login challenge given as hex with
    /// optional spaces, colons, dashes, and mixed case.
    ///
    /// - Returns: The 32 raw challenge bytes.
    /// - Throws: `GhostOSAssertionError` describing why the input was rejected.
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

    private static func appendLE16(_ value: Int, to data: inout Data) {
        data.append(UInt8(value & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
    }
}
