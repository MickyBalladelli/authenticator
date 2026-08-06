import AppKit
import SwiftUI

struct MainListView: View {
    @ObservedObject var viewModel: AccountListViewModel
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("requireAuthentication") private var requireAuthentication = false

    private var period: Int {
        viewModel.accounts.map(\.period).min() ?? 30
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(width: 360, height: 420)
        .overlay(alignment: .bottom) {
            if let toast = viewModel.toastMessage {
                Text(toast)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.toastMessage)
        .sheet(isPresented: $viewModel.showAddSheet) {
            AddAccountSheet(viewModel: viewModel)
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            viewModel.authenticateIfNeeded()
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                viewModel.revealIfUnlocked()
            case .inactive, .background:
                viewModel.obscureForInactiveWindow()
                if requireAuthentication {
                    viewModel.lockForPrivacy()
                }
            @unknown default:
                break
            }
        }
        .onChange(of: requireAuthentication) { enabled in
            if enabled {
                viewModel.lockForPrivacy()
                viewModel.authenticateIfNeeded()
            } else {
                viewModel.unlockWithoutAuthentication()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(.tint)
            Text("Authenticator")
                .font(.headline)
            Spacer()
            TimerProgressView(remainingSeconds: viewModel.remainingSeconds, period: period)
            Button {
                viewModel.showAddSheet = true
            } label: {
                Image(systemName: "plus")
            }
            .help("Add account")
            .disabled(!viewModel.isUnlocked && requireAuthentication)

            Menu {
                Toggle("Require Touch ID / Password", isOn: $requireAuthentication)
                Divider()
                Button("Quit Authenticator") {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.borderlessButton)
            .help("Settings")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if !viewModel.isUnlocked && requireAuthentication {
            lockedState
        } else if viewModel.accounts.isEmpty {
            emptyState
        } else {
            List {
                ForEach(viewModel.accounts) { account in
                    AccountRowView(
                        account: account,
                        formattedCode: viewModel.formattedCode(for: account),
                        isObscured: !viewModel.isUnlocked || viewModel.isContentHidden || viewModel.code(for: account).contains("•"),
                        onCopy: { viewModel.copyCode(for: account) },
                        onDelete: { viewModel.deleteAccount(account) }
                    )
                }
            }
            .listStyle(.inset)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "lock.shield")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No accounts yet")
                .font(.title3.weight(.semibold))
            Text("Add an account with a secret key or otpauth:// URI.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Add Account") {
                viewModel.showAddSheet = true
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var lockedState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Authenticator Locked")
                .font(.title3.weight(.semibold))
            Text("Authenticate to view your codes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Unlock") {
                viewModel.authenticateIfNeeded()
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
