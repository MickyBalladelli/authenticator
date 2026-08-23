import SwiftUI

struct AccountRowView: View {
    let account: Account
    let formattedCode: String
    let isObscured: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var didCopy = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayTitle)
                    .font(.headline)
                    .lineLimit(1)

                if !account.accountName.isEmpty,
                   account.accountName.caseInsensitiveCompare(account.displayTitle) != .orderedSame {
                    Text(account.accountName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(formattedCode)
                    .font(.system(.title2, design: .monospaced).weight(.semibold))
                    .foregroundStyle(isObscured ? .secondary : .primary)
                    .contentTransition(.numericText())
            }

            Spacer(minLength: 8)

            Button {
                onCopy()
                withAnimation {
                    didCopy = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation {
                        didCopy = false
                    }
                }
            } label: {
                Text(didCopy ? "Copied!" : "Copy")
                    .font(.caption.weight(.semibold))
                    .frame(minWidth: 52)
            }
            .buttonStyle(.bordered)
            .disabled(isObscured)
            .help("Copy code to clipboard")

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete account")
        }
        .padding(.vertical, 6)
        .contextMenu {
            Button("Copy Code", action: onCopy)
                .disabled(isObscured)
            Divider()
            Button("Delete Account", role: .destructive, action: onDelete)
        }
    }
}
