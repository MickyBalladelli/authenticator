import SwiftUI

struct GhostLoginView: View {
    private enum ChallengeStatus: Equatable {
        case empty
        case valid
        case invalid(String)
    }

    @ObservedObject var viewModel: AccountListViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var challengeHex = ""
    @State private var assertionHex: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                intro
                challengeField
                generateButton
                if let assertionHex {
                    resultSection(assertionHex)
                }
            }
            .padding(20)
        }
        .onChange(of: scenePhase) { phase in
            // Drop the displayed assertion when the popup loses focus,
            // mirroring how codes are obscured for privacy.
            if phase != .active {
                assertionHex = nil
            }
        }
    }

    private var intro: some View {
        Text("Paste the console's challenge (shown after \"Challenge:\") to build the passkey assertion.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var challengeField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Challenge (32 bytes, hex)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("e.g. 1a2b3c…  spaces, colons and dashes are ignored", text: $challengeHex)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

            switch status {
            case .empty:
                Text("Challenges are one-shot — request a new one if an assertion is rejected.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .valid:
                Label("Valid challenge (32 bytes)", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            case .invalid(let message):
                Label(message, systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var generateButton: some View {
        Button("Generate Assertion") {
            generate()
        }
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: .infinity)
        .disabled(status != .valid)
    }

    private func resultSection(_ assertion: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Passkey assertion")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(assertion)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(4)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.08))
                )

            HStack {
                Text("Paste at the console's \"Passkey assertion:\" prompt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Copy") {
                    viewModel.copyAssertion(assertion)
                }
                .buttonStyle(.borderedProminent)
            }

            Text("Assertions are never logged or stored, and stay on the clipboard until you copy something else.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var status: ChallengeStatus {
        let trimmed = challengeHex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }
        do {
            _ = try GhostOSAssertion.challengeBytes(fromHex: trimmed)
            return .valid
        } catch {
            return .invalid(error.localizedDescription)
        }
    }

    private func generate() {
        do {
            // Held only in memory; never logged or persisted.
            assertionHex = try GhostOSAssertion.assertion(forChallengeHex: challengeHex)
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}
