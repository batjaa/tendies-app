import AppKit
import SwiftUI

struct PopoverView: View {
    @Bindable var appState: AppState
    @State private var expandedTimeframe: String?
    @State private var showSettings = false
    @State private var eventMonitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(
                isLoading: appState.isLoading,
                onRefresh: { Task { await appState.refresh(manual: true) } },
                onSettings: { showSettings.toggle() }
            )
            Divider()

            if showSettings {
                settingsPlaceholder
            } else {
                mainContent
            }

            Divider()
            FooterView(
                lastUpdated: appState.lastUpdated,
                isLoading: appState.isLoading,
                isAuthenticated: appState.isAuthenticated,
                subscriptionStatus: appState.subscriptionStatus,
                trialEndsAt: appState.trialEndsAt,
                proUntil: appState.proUntil,
                onLogout: { appState.logout() },
                onManageSubscription: { Task { await openPortal() } }
            )
        }
        .frame(width: 300)
        .clipped()
        .onAppear { installKeyboardShortcuts() }
        .onDisappear { removeKeyboardShortcuts() }
    }

    @ViewBuilder
    private var mainContent: some View {
        if !appState.direct && !appState.isAuthenticated && appState.output == nil {
            LoginView(
                onLogin: { Task { await appState.login() } },
                errorMessage: appState.loginError,
                isLoading: appState.authService.isLoggingIn
            )
        } else if appState.subscriptionStatus == .expired || appState.error?.isSubscriptionRequired == true {
            SubscriptionView(appState: appState)
        } else if let error = appState.error, appState.output == nil {
            ErrorView(error: error, appState: appState)
        } else if let output = appState.output {
            timeframeList(output)
        } else {
            // First load — no data yet, show full skeleton.
            LoadingView()
        }
    }

    /// Canonical display order for timeframes.
    private static let timeframeOrder = ["Day", "Week", "Month"]

    @ViewBuilder
    private func timeframeList(_ output: TendiesOutput) -> some View {
        if appState.availableAccounts.count > 1 {
            AccountBarView(
                accounts: appState.availableAccounts,
                selected: appState.selectedAccounts,
                onToggle: { appState.toggleAccount($0) }
            )
        }

        VStack(spacing: 0) {
            // Show all enabled timeframes in canonical order: loaded rows + skeleton for loading.
            ForEach(appState.enabledTimeframes, id: \.self) { label in
                if let tf = output.timeframes.first(where: { $0.label == label }) {
                    TimeframeRowView(
                        timeframe: tf,
                        isExpanded: expandedTimeframe == tf.label,
                        onTap: {
                            guard tf.tradeCount > 0 else { return }
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if expandedTimeframe == tf.label {
                                    expandedTimeframe = nil
                                } else {
                                    expandedTimeframe = tf.label
                                }
                            }
                        }
                    )

                    if expandedTimeframe == tf.label {
                        TickerListView(tickers: tf.tickers, sortOrder: appState.tickerSort)
                            .transition(.opacity)
                    }
                } else if appState.loadingTimeframes.contains(label) {
                    TimeframeLoadingRow(label: label)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)

        // Weekend fallback note.
        if let dayTf = output.timeframes.first(where: { $0.label == "Day" }),
           dayTf.tradeCount == 0,
           appState.menuBarTimeframe == "Day" {
            Text("Showing Week — no Day trades")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
        }
    }

    private func openPortal() async {
        do {
            let urlString = try await appState.getPortalURL()
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        } catch {
            // Silently fail — not critical.
        }
    }

    private var settingsPlaceholder: some View {
        SettingsView(appState: appState, onBack: { showSettings = false })
    }

    private func installKeyboardShortcuts() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) {
                switch event.charactersIgnoringModifiers {
                case "r":
                    Task { await appState.refresh(manual: true) }
                    return nil
                case "q":
                    NSApplication.shared.terminate(nil)
                    return nil
                case ",":
                    showSettings.toggle()
                    return nil
                default:
                    break
                }
            }
            if event.keyCode == 53 { // Esc
                NSApp.keyWindow?.close()
                return nil
            }
            return event
        }
    }

    private func removeKeyboardShortcuts() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
