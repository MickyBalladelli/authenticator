import SwiftUI

struct AddAccountSheet: View {
    enum EntryMode: String, CaseIterable, Identifiable {
        case secret = "Raw Secret Key"
        case uri = "Paste otpauth:// URI"

        var id: String { rawValue }
    }

    @ObservedObject var viewModel: AccountListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var mode: EntryMode = .secret
    @State private var label = ""
    @State private var accountName = ""
    @State private var secret = ""
    @State private var showSecret = false
    @State private var uri = ""
    @State private var digits = 6
    @State private var period = 30
    @State private var algorithm: TOTPAlgorithm = .sha1
    @State private var uriStatus: URIStatus = .empty
    @State private var validationError: String?

    private enum URIStatus: Equatable {
        case empty
        case valid
        case invalid(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Add Account")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            Picker("Entry Mode", selection: $mode) {
                ForEach(EntryMode.allCases) { entry in
                    Text(entry.rawValue).tag(entry)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _ in
                validationError = nil
            }

            if mode == .uri {
                uriSection
            }

            formFields
                .disabled(mode == .uri && uriStatus != .valid && !uri.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            DisclosureGroup("Advanced") {
                Picker("Digits", selection: $digits) {
                    Text("6").tag(6)
                    Text("8").tag(8)
                }
                .pickerStyle(.segmented)

                Picker("Interval", selection: $period) {
                    Text("30s").tag(30)
                    Text("60s").tag(60)
                    if period != 30 && period != 60 {
                        Text("\(period)s").tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.top, 8)
            }

            if let validationError {
                Text(validationError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Add") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private var uriSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("otpauth:// URI")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextEditor(text: $uri)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 72, maxHeight: 96)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3))
                )
                .onChange(of: uri) { newValue in
                    applyURI(newValue)
                }

            switch uriStatus {
            case .empty:
                Text("Paste an otpauth://totp/... link")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .valid:
                Label("Valid URI", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            case .invalid(let message):
                Label(message, systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var formFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            labeledField("Service / Issuer", text: $label, prompt: "AWS, Google, GitHub…")
            labeledField("Account Name / Email", text: $accountName, prompt: "admin@company.com")

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Base32 Secret")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(showSecret ? "Hide" : "Show") {
                        showSecret.toggle()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                }

                Group {
                    if showSecret {
                        TextField("JBSWY3DPEHPK3PXP", text: $secret)
                    } else {
                        SecureField("JBSWY3DPEHPK3PXP", text: $secret)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            }
        }
    }

    private func labeledField(_ title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var canSave: Bool {
        let hasIdentity = !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasSecret = Base32.isValid(secret)
        if mode == .uri {
            return uriStatus == .valid && hasIdentity && hasSecret
        }
        return hasIdentity && hasSecret
    }

    private func applyURI(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            uriStatus = .empty
            return
        }

        switch OTPURIParser.parse(trimmed) {
        case .success(let params):
            uriStatus = .valid
            label = params.label
            accountName = params.accountName
            secret = params.secret
            digits = params.digits
            period = params.period == 60 ? 60 : (params.period == 30 ? 30 : params.period)
            if period != 30 && period != 60 {
                period = params.period
            }
            algorithm = params.algorithm
            validationError = nil
        case .failure(let error):
            uriStatus = .invalid(error.localizedDescription)
        }
    }

    private func save() {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAccount = accountName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedLabel.isEmpty || !trimmedAccount.isEmpty else {
            validationError = "Enter a service name or account name."
            return
        }

        guard Base32.isValid(secret) else {
            validationError = "Secret must be a valid Base32 string."
            return
        }

        viewModel.addAccount(
            label: trimmedLabel.isEmpty ? trimmedAccount : trimmedLabel,
            accountName: trimmedAccount.isEmpty ? trimmedLabel : trimmedAccount,
            secret: secret,
            digits: digits,
            period: period,
            algorithm: algorithm
        )
    }
}
