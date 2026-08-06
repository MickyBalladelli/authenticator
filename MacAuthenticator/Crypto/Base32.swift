import Foundation

enum Base32 {
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
    private static let decodeTable: [Character: UInt8] = {
        var table: [Character: UInt8] = [:]
        for (index, character) in alphabet.enumerated() {
            table[character] = UInt8(index)
        }
        return table
    }()

    /// Decodes an RFC 4648 Base32 string into raw bytes.
    /// Strips spaces, uppercases input, and ignores padding (`=`).
    static func decode(_ string: String) -> Data? {
        let cleaned = string
            .uppercased()
            .filter { !$0.isWhitespace && $0 != "=" }

        guard !cleaned.isEmpty else { return nil }

        var buffer: UInt64 = 0
        var bitsLeft = 0
        var output = [UInt8]()
        output.reserveCapacity(cleaned.count * 5 / 8)

        for character in cleaned {
            guard let value = decodeTable[character] else { return nil }
            buffer = (buffer << 5) | UInt64(value)
            bitsLeft += 5

            if bitsLeft >= 8 {
                bitsLeft -= 8
                let byte = UInt8((buffer >> bitsLeft) & 0xFF)
                output.append(byte)
            }
        }

        return Data(output)
    }

    /// Returns true when the string contains only valid Base32 characters (after sanitizing).
    static func isValid(_ string: String) -> Bool {
        decode(string) != nil
    }
}
