import Foundation

let message = """
ghostos-login no longer creates legacy SYPA assertions.

Open MacAuthenticator, select GhostOS, and paste the one-time localhost URL
printed by the GhostOS VM. The app creates a real ES256 passkey and sends a
signed SYWB WebAuthn assertion directly.
"""

fputs("\(message)\n", stderr)
exit(2)
