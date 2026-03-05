import SwiftUI

@main
struct TendiesApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(appState: appState)
        } label: {
            Text(appState.menuBarLabel)
                .onAppear {
                    appState.startAutoRefresh()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
