import AppKit
import SwiftUI

struct SettingsView: View {
    let viewModel: AccountListViewModel

    @AppStorage("requireAuthentication") private var requireAuthentication = false
    @AppStorage("lockTimeoutRaw") private var lockTimeoutRaw = LockTimeout.always.rawValue
    @AppStorage(LaunchMode.storageKey) private var launchModeRaw = LaunchMode.menuBar.rawValue

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

            Divider()

            Picker(selection: $launchModeRaw) {
                Text("Menu Bar Only").tag(LaunchMode.menuBar.rawValue)
                Text("Application").tag(LaunchMode.windowApp.rawValue)
            } label: {
                Text("Run as")
            }
            .pickerStyle(.menu)

            Text("Only one form is active at a time. Takes effect on relaunch.")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Relaunch Now") { relaunch() }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Spawns a fresh instance via `open -n`, then quits this one.
    private func relaunch() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", Bundle.main.bundlePath]
        try? process.run()
        NSApplication.shared.terminate(nil)
    }
}
