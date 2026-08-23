import AppKit
import SwiftUI

struct MainListView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case codes = "Codes"
        case settings = "Settings"

        var id: String { rawValue }
    }

    @ObservedObject var viewModel: AccountListViewModel
    /// False for the regular app window: it stays usable while unlocked and
    /// only the transient menu-bar popup hides/locks when dismissed.
    var isPopup: Bool = true
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("requireAuthentication") private var requireAuthentication = false
    @State private var selectedTab: Tab = .codes

    private var period: Int {
        viewModel.accounts.map(\.period).min() ?? 30
    }

    var body: some View {
        Group {
            if viewModel.showAddSheet {
                // Presented inline: MenuBarExtra + .sheet dismisses the popup on click.
                AddAccountSheet(viewModel: viewModel)
            } else {
                VStack(spacing: 0) {
                    header
                    Picker("Section", selection: $selectedTab) {
                        ForEach(Tab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
                    Divider()
                    content
                }
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
            }
        }
        .frame(width: isPopup ? 360 : nil, height: isPopup ? 420 : nil)
        .frame(minWidth: isPopup ? nil : 400, minHeight: isPopup ? nil : 460)
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
                // Only the transient popup hides/locks on dismissal; the
                // regular window stays usable within the grace period.
                guard isPopup else { break }
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
            if selectedTab == .codes {
                TimerProgressView(remainingSeconds: viewModel.remainingSeconds, period: period)
                Button {
                    viewModel.showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add account")
                .disabled(!viewModel.isUnlocked && requireAuthentication)
            }

            Menu {
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
        } else {
            switch selectedTab {
            case .codes:
                codesContent
            case .settings:
                SettingsView(viewModel: viewModel)
            }
        }
    }

    @ViewBuilder
    private var codesContent: some View {
        if viewModel.accounts.isEmpty {
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
