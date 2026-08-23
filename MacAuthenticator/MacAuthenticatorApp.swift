import SwiftUI

@main
struct MacAuthenticatorApp: App {
    @StateObject private var viewModel = AccountListViewModel()

    var body: some Scene {
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
