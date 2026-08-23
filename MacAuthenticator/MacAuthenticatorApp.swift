import AppKit
import SwiftUI

/// How the app presents itself. Persisted in UserDefaults (`launchModeRaw`)
/// and applied at launch: exactly one of the two forms is ever active.
enum LaunchMode: Int {
    case menuBar = 0
    case windowApp = 1

    static let storageKey = "launchModeRaw"

    static var current: LaunchMode {
        LaunchMode(rawValue: UserDefaults.standard.integer(forKey: storageKey)) ?? .menuBar
    }

    /// Snapshot taken once per process. Settings can rewrite the persisted
    /// value while running, but the form only changes on the next launch.
    static let launchTime = LaunchMode.current
}

extension Notification.Name {
    static let agentPopoverWillShow = Notification.Name("agentPopoverWillShow")
    static let agentPopoverDidClose = Notification.Name("agentPopoverDidClose")
}

/// Placeholder filling the WindowGroup in menu-bar mode; it closes its own
/// window as soon as it appears (the popover is the entire UI in this mode).
struct AgentIdleView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onAppear {
                dismiss()
            }
    }
}

/// Forwards popover visibility into the scenePhase environment so the popup
/// gets the same privacy treatment as the SwiftUI-native MenuBarExtra window.
struct PopoverHostView: View {
    @StateObject private var viewModel = AccountListViewModel()
    @State private var phase: ScenePhase = .inactive

    var body: some View {
        MainListView(viewModel: viewModel)
            .environment(\.scenePhase, phase)
            .onReceive(NotificationCenter.default.publisher(for: .agentPopoverWillShow)) { _ in
                phase = .active
                // Content persists between opens, so drive the unlock prompt
                // here instead of relying on a fresh onAppear per open.
                viewModel.authenticateIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: .agentPopoverDidClose)) { _ in
                phase = .background
            }
    }
}

/// Menu-bar mode: shield status item toggling a transient popover.
final class StatusItemController: NSObject, NSPopoverDelegate {
    static let shared = StatusItemController()

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()

    func install() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "lock.shield",
            accessibilityDescription: "Authenticator"
        )
        item.button?.action = #selector(togglePopover(_:))
        item.button?.target = self

        popover.contentSize = NSSize(width: 360, height: 420)
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: PopoverHostView())
        statusItem = item
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            NotificationCenter.default.post(name: .agentPopoverWillShow, object: nil)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func popoverDidClose(_ notification: Notification) {
        NotificationCenter.default.post(name: .agentPopoverDidClose, object: nil)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Accessory: no Dock icon (menu-bar agent). Regular: standard app.
        NSApp.setActivationPolicy(LaunchMode.launchTime == .menuBar ? .accessory : .regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard LaunchMode.launchTime == .menuBar else { return }
        // Belt and braces: hide the auto-created window if it already exists.
        for window in NSApp.windows where window.canBecomeMain {
            window.orderOut(nil)
        }
        StatusItemController.shared.install()
    }

    /// Menu-bar mode has no windows by design; closing the placeholder must
    /// not terminate the app (SwiftUI's default would).
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Reopens the main window when the Dock icon is clicked while none is visible.
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
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var viewModel = AccountListViewModel()

    var body: some Scene {
        WindowGroup("Authenticator", id: "main-window") {
            if LaunchMode.launchTime == .menuBar {
                AgentIdleView()
            } else {
                MainListView(viewModel: viewModel, isPopup: false)
                    .onAppear {
                        viewModel.reload()
                        viewModel.authenticateIfNeeded()
                    }
            }
        }
    }
}
