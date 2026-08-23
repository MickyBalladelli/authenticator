import SwiftUI

struct SettingsView: View {
    let viewModel: AccountListViewModel

    @AppStorage("requireAuthentication") private var requireAuthentication = false
    @AppStorage("lockTimeoutRaw") private var lockTimeoutRaw = LockTimeout.always.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(isOn: $requireAuthentication) {
                Text("Require Touch ID / Password")
            }

            Picker(selection: $lockTimeoutRaw) {
                ForEach(LockTimeout.allCases) { timeout in
                    Text(timeout.label).tag(timeout.rawValue)
                }
            } label: {
                Text("Ask again after")
            }
            .pickerStyle(.menu)
            .disabled(!requireAuthentication)

            Text(
                requireAuthentication
                    ? "Codes stay unlocked for the selected period, then the next click asks again."
                    : "Turn on authentication to choose when to ask again."
            )
            .font(.caption)
            .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
