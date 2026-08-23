import Foundation

let usage = """
Usage: ghostos-login <challenge-hex>

Builds a "SYPA" v1 passkey assertion for a 32-byte GhostOS console login
challenge and prints it as lowercase hex. Paste it at the console's
"Passkey assertion:" prompt.

The challenge is the hex string shown after "Challenge:"; spaces, colons,
and dashes are ignored. Challenges are one-shot: if the console rejects an
assertion, request a new challenge instead of retrying.
"""

let arguments = Array(CommandLine.arguments.dropFirst())

if arguments.contains("-h") || arguments.contains("--help") {
    print(usage)
    exit(0)
}

guard arguments.count == 1 else {
    fputs("error: expected exactly one argument (the challenge hex)\n\n\(usage)\n", stderr)
    exit(2)
}

do {
    let assertion = try GhostOSAssertion.assertion(forChallengeHex: arguments[0])
    print(assertion)
} catch {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
