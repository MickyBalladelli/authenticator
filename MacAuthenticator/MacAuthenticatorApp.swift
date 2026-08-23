import AppKit
import SwiftUI

/// Reopens the main window when the Dock icon is clicked while no window is visible.
final class ReopenDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            sender.activate(ignoringOtherApps: true)
            sender.windows
                .first { $0.canBecomeMain && $0.isVisible }
                .map { $0.makeKeyAndOrderFront(self) }
        }
        return true
    }
}

@main
struct MacAuthenticatorApp: App {
    @NSApplicationDelegateAdaptor(ReopenDelegate.self) private var delegate
    @StateObject private var viewModel = AccountListViewModel()

    var body: some Scene {
        WindowGroup("Authenticator", id: "main-window") {
            MainListView(viewModel: viewModel, isPopup: false)
        }

        MenuBarExtra("Authenticator", systemImage: "lock.shield") {
            MainListView(viewModel: viewModel)
                .onAppear {
                    viewModel.reload()
                    viewModel.authenticateIfNeeded()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
