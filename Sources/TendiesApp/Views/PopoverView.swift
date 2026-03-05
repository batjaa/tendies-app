import AppKit
import SwiftUI

struct PopoverView: View {
    @Bindable var appState: AppState
    @State private var expandedTimeframe: String?
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(
                isLoading: appState.isLoading,
                onRefresh: { Task { await appState.refresh() } },
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
                onLogout: { appState.logout() },
                onManageSubscription: { Task { await openPortal() } }
            )
        }
        .frame(width: 300)
    }

    @ViewBuilder
    private var mainContent: some View {
        if !appState.direct && !appState.isAuthenticated && appState.output == nil {
            LoginView(
                onLogin: { Task { await appState.login() } },
                errorMessage: appState.loginError,
                isLoading: appState.authService.isLoggingIn
            )
        } else if appState.subscriptionStatus == .expired {
            SubscriptionView(appState: appState)
        } else if let error = appState.error, appState.output == nil {
            ErrorView(error: error, appState: appState)
        } else if let output = appState.output {
            timeframeList(output)
        } else {
            LoadingView()
                .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func timeframeList(_ output: TendiesOutput) -> some View {
        VStack(spacing: 0) {
            ForEach(output.timeframes, id: \.label) { tf in
                TimeframeRowView(
                    timeframe: tf,
                    isExpanded: expandedTimeframe == tf.label,
                    onTap: {
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
                    TickerListView(tickers: tf.tickers)
                        .transition(.opacity.combined(with: .move(edge: .top)))
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
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { showSettings = false }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Text("Settings coming in next update")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
