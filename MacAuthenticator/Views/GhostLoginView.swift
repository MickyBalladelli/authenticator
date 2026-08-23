import SwiftUI

struct GhostLoginView: View {
    @StateObject private var login = GhostOSLoginViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label("GhostOS", systemImage: "desktopcomputer.and.arrow.down")
                    .font(.title2.weight(.semibold))

                Text(login.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if login.isConnected {
                    connectedContent
                } else {
                    connectionContent
                }

                if !login.errorMessage.isEmpty {
                    Label(login.errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Text("The private key stays in this Mac's Secure Enclave or Keychain.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
    }

    private var connectionContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GhostOS connection URL")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("http://localhost:…/?code=…", text: $login.connectionURL)
                .textFieldStyle(.roundedBorder)
                .font(.system(.caption, design: .monospaced))
                .onSubmit { login.connect() }

            Button("Connect") {
                login.connect()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .disabled(login.connectionURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var connectedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(statusTitle, systemImage: statusIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
                Spacer()
                Button("Disconnect") {
                    login.disconnect()
                }
                .buttonStyle(.link)
            }

            if login.canAuthenticate {
                Text("Administrator username")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField("micky", text: $login.username)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.username)
                    .disabled(login.isBusy)

                Button {
                    login.authenticate()
                } label: {
                    HStack {
                        if login.isBusy {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(login.actionTitle)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(login.isBusy || login.username.isEmpty)
            } else if login.mode != "success" {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private var statusTitle: String {
        switch login.mode {
        case "enroll": return "Enrollment ready"
        case "login": return "Login ready"
        case "success": return "GhostOS unlocked"
        default: return "Connected"
        }
    }

    private var statusIcon: String {
        login.mode == "success" ? "checkmark.circle.fill" : "link.circle.fill"
    }

    private var statusColor: Color {
        login.mode == "success" ? .green : .accentColor
    }
}
