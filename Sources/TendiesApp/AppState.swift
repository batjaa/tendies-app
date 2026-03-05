import Foundation
import os
import SwiftUI

private let logger = Logger(subsystem: "site.batjaa.tendies-app", category: "AppState")

@Observable
final class AppState {
    private enum Defaults {
        static let refreshMinutes = "refreshMinutes"
        static let menuBarTimeframe = "menuBarTimeframe"
        static let enabledTimeframes = "enabledTimeframes"
        static let direct = "direct"
        static let symbols = "symbols"
        static let cliPath = "cliPath"
        static let selectedAccounts = "selectedAccounts"
        static let availableAccounts = "availableAccounts"
        static let accountIDsByLabel = "accountIDsByLabel"
    }

    var output: TendiesOutput?
    var error: AppError?
    var isLoading = false
    var lastUpdated: Date?
    var loginError: String?
    var subscriptionStatus: SubscriptionStatus?
    var trialEndsAt: String?

    // Account selection (labels for display, IDs for CLI filtering).
    var availableAccounts: [String] = []
    var accountIDsByLabel: [String: String] = [:]
    var selectedAccounts: Set<String> = []

    // Settings (persisted via UserDefaults).
    var refreshMinutes: Int = 1
    var menuBarTimeframe: String = "Day"
    var enabledTimeframes: [String] = ["Day"]
    var direct: Bool = false
    var symbols: String = ""
    var cliPath: String?

    let authService = AuthService()

    init() {
        let ud = UserDefaults.standard
        if ud.object(forKey: Defaults.refreshMinutes) != nil {
            refreshMinutes = ud.integer(forKey: Defaults.refreshMinutes)
        }
        if let s = ud.string(forKey: Defaults.menuBarTimeframe) {
            menuBarTimeframe = s
        }
        if let arr = ud.stringArray(forKey: Defaults.enabledTimeframes) {
            enabledTimeframes = arr
        }
        direct = ud.bool(forKey: Defaults.direct)
        if let s = ud.string(forKey: Defaults.symbols) {
            symbols = s
        }
        cliPath = ud.string(forKey: Defaults.cliPath)
        if let arr = ud.stringArray(forKey: Defaults.availableAccounts) {
            availableAccounts = arr
        }
        if let data = ud.data(forKey: Defaults.selectedAccounts),
           let set = try? JSONDecoder().decode(Set<String>.self, from: data) {
            selectedAccounts = set
        }
        if let data = ud.data(forKey: Defaults.accountIDsByLabel),
           let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            accountIDsByLabel = dict
        }
    }

    func persistSettings() {
        let ud = UserDefaults.standard
        ud.set(refreshMinutes, forKey: Defaults.refreshMinutes)
        ud.set(menuBarTimeframe, forKey: Defaults.menuBarTimeframe)
        ud.set(enabledTimeframes, forKey: Defaults.enabledTimeframes)
        ud.set(direct, forKey: Defaults.direct)
        ud.set(symbols, forKey: Defaults.symbols)
        ud.set(cliPath, forKey: Defaults.cliPath)
        ud.set(availableAccounts, forKey: Defaults.availableAccounts)
        if let data = try? JSONEncoder().encode(selectedAccounts) {
            ud.set(data, forKey: Defaults.selectedAccounts)
        }
        if let data = try? JSONEncoder().encode(accountIDsByLabel) {
            ud.set(data, forKey: Defaults.accountIDsByLabel)
        }
    }

    private var refreshTimer: Timer?

    var isAuthenticated: Bool {
        guard let token = KeychainService.loadToken() else { return false }
        // Consider authenticated if token hasn't fully expired yet
        // (refresh may still work even if access token is near expiry).
        return token.expiry.timeIntervalSinceNow > -3600
    }

    var menuBarLabel: String {
        if let error {
            _ = error // suppress unused warning
            return "⚠ $---"
        }
        if output == nil && isLoading {
            return "◌ $---"
        }
        guard let output else {
            return "◌ $---"
        }

        // Find the configured timeframe.
        let primary = output.timeframes.first { $0.label == menuBarTimeframe }

        // Weekend fallback: if primary has 0 trades, fall back to Week.
        let useFallback = primary != nil && primary!.tradeCount == 0 && menuBarTimeframe == "Day"
        let tf: Timeframe?
        let suffix: String

        if useFallback {
            tf = output.timeframes.first { $0.label == "Week" }
            suffix = " (w)"
        } else {
            tf = primary
            suffix = ""
        }

        guard let tf else {
            return "● $0"
        }

        return formatMenuBarLabel(tf.net) + suffix
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        // In broker mode, ensure we have a valid token before calling CLI.
        if !direct {
            do {
                try await authService.ensureValidToken()
            } catch is AuthError {
                self.error = .authExpired("Login required")
                return
            } catch {
                self.error = .authExpired("Authentication error: \(error.localizedDescription)")
                return
            }

            // Check subscription status before running CLI.
            if let token = KeychainService.loadToken() {
                let config = TendiesConfig.load()
                do {
                    let info = try await SubscriptionService.fetchStatus(
                        token: token.accessToken,
                        brokerURL: config.resolvedBrokerURL
                    )
                    self.subscriptionStatus = info.status
                    self.trialEndsAt = info.trialEndsAt

                    if info.status == .expired {
                        self.error = .subscriptionRequired("Your free trial has ended. Subscribe to continue.")
                        return
                    }
                } catch {
                    // If subscription check fails, log and proceed — the CLI will catch
                    // subscription_required via the 403 middleware if applicable.
                    logger.warning("Subscription check failed: \(error.localizedDescription)")
                }
            }
        }
        logger.notice("Refreshing with timeframes=\(self.enabledTimeframes.joined(separator: ","))")

        // Build account filter: only pass if user has deselected some accounts.
        let accountFilter: String? = if !selectedAccounts.isEmpty && selectedAccounts.count < availableAccounts.count {
            selectedAccounts.compactMap { accountIDsByLabel[$0] }.joined(separator: ",")
        } else {
            nil
        }

        let result = await CLIRunner.run(
            customPath: cliPath,
            direct: direct,
            symbols: symbols.isEmpty ? nil : symbols,
            account: accountFilter,
            timeframes: enabledTimeframes
        )

        switch result {
        case .success(var data):
            // Filter to only enabled timeframes (CLI may return extras when no flag is passed).
            data.timeframes = data.timeframes.filter { enabledTimeframes.contains($0.label) }
            self.output = data
            self.error = nil
            self.lastUpdated = Date()
            // Update available accounts from CLI response (only on first load
            // to avoid shrinking the list when a filter is active).
            if !data.accounts.isEmpty && availableAccounts.isEmpty {
                self.availableAccounts = data.accounts
                for (i, label) in data.accounts.enumerated() {
                    if i < data.accountIDs.count {
                        accountIDsByLabel[label] = data.accountIDs[i]
                    }
                }
                selectedAccounts = Set(data.accounts)
                persistSettings()
            }
        case .failure(let err):
            self.error = err
        }
    }

    func login() async {
        loginError = nil
        do {
            try await authService.login()
            await refresh()
        } catch AuthError.loginCancelled {
            // User cancelled — no error to show.
        } catch {
            loginError = error.localizedDescription
        }
    }

    func toggleAccount(_ account: String) {
        if selectedAccounts.contains(account) {
            // Don't allow deselecting all.
            guard selectedAccounts.count > 1 else { return }
            selectedAccounts.remove(account)
        } else {
            selectedAccounts.insert(account)
        }
        persistSettings()
        Task { await refresh() }
    }

    func logout() {
        KeychainService.deleteToken()
        output = nil
        error = nil
        lastUpdated = nil
        loginError = nil
        subscriptionStatus = nil
        trialEndsAt = nil
        stopAutoRefresh()
    }

    func getCheckoutURL(plan: String) async throws -> String {
        guard let token = KeychainService.loadToken() else {
            throw AuthError.notAuthenticated
        }
        let config = TendiesConfig.load()
        return try await SubscriptionService.getCheckoutURL(
            token: token.accessToken,
            brokerURL: config.resolvedBrokerURL,
            plan: plan
        )
    }

    func getPortalURL() async throws -> String {
        guard let token = KeychainService.loadToken() else {
            throw AuthError.notAuthenticated
        }
        let config = TendiesConfig.load()
        return try await SubscriptionService.getPortalURL(
            token: token.accessToken,
            brokerURL: config.resolvedBrokerURL
        )
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        // Initial fetch.
        Task { await refresh() }
        // Recurring timer.
        let interval = TimeInterval(max(refreshMinutes, 1) * 60)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.refresh() }
        }
        observeSleepWake()
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func observeSleepWake() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            logger.notice("System sleeping — pausing auto-refresh")
            self.refreshTimer?.invalidate()
            self.refreshTimer = nil
        }
        nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            logger.notice("System woke — refreshing and restarting timer")
            Task { await self.refresh() }
            let interval = TimeInterval(max(self.refreshMinutes, 1) * 60)
            self.refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                guard let self else { return }
                Task { await self.refresh() }
            }
        }
    }
}
