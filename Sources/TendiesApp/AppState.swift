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
        static let tickerSort = "tickerSort"
        static let selectedAccounts = "selectedAccounts"
        static let availableAccounts = "availableAccounts"
        static let accountIDsByLabel = "accountIDsByLabel"
        static let instrumentFilter = "instrumentFilter"
        static let tickerGroup = "tickerGroup"
    }

    var output: TendiesOutput?
    var error: AppError?
    var isLoading = false
    var loadingTimeframes: Set<String> = []
    var lastUpdated: Date?
    var loginError: String?
    var subscriptionStatus: SubscriptionStatus?
    var trialEndsAt: String?
    var proUntil: String?
    private var consecutiveErrors = 0

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
    var tickerSort: String = "az"
    var instrumentFilter: Set<String> = ["equity", "option", "future"]
    var tickerGroup: String = "ticker"  // "ticker" or "type"

    var resolvedCLIPath: String? {
        CLIRunner.resolveBinary(customPath: cliPath)
    }

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
        if let s = ud.string(forKey: Defaults.tickerSort) {
            tickerSort = s
        }
        if let data = ud.data(forKey: Defaults.instrumentFilter),
           let set = try? JSONDecoder().decode(Set<String>.self, from: data) {
            instrumentFilter = set
        }
        if let s = ud.string(forKey: Defaults.tickerGroup) {
            tickerGroup = s
        }
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
        ud.set(tickerSort, forKey: Defaults.tickerSort)
        if let data = try? JSONEncoder().encode(instrumentFilter) {
            ud.set(data, forKey: Defaults.instrumentFilter)
        }
        ud.set(tickerGroup, forKey: Defaults.tickerGroup)
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

    func refresh(manual: Bool = false) async {
        guard !isLoading else { return }
        if manual { consecutiveErrors = 0 }
        isLoading = true
        loadingTimeframes = Set(enabledTimeframes)

        // In broker mode, ensure we have a valid token before calling CLI.
        if !direct {
            do {
                try await authService.ensureValidToken()
            } catch is AuthError {
                self.error = .authExpired("Login required")
                isLoading = false
                loadingTimeframes = []
                return
            } catch {
                self.error = .authExpired("Authentication error: \(error.localizedDescription)")
                isLoading = false
                loadingTimeframes = []
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
                    self.proUntil = info.proUntil

                    if info.status == .expired {
                        self.error = .subscriptionRequired("Your free trial has ended. Subscribe to continue.")
                        isLoading = false
                        loadingTimeframes = []
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

        // Capture settings for concurrent use.
        let path = cliPath
        let isDirect = direct
        let syms = symbols.isEmpty ? nil : symbols
        let timeframes = enabledTimeframes

        self.error = nil

        // Run one CLI process per timeframe in parallel, streaming results as they arrive.
        await withTaskGroup(of: (String, Result<TendiesOutput, AppError>).self) { group in
            for tf in timeframes {
                group.addTask {
                    let result = await CLIRunner.run(
                        customPath: path,
                        direct: isDirect,
                        symbols: syms,
                        account: accountFilter,
                        timeframe: tf
                    )
                    return (tf, result)
                }
            }

            for await (tf, result) in group {
                switch result {
                case .success(let data):
                    // Merge this timeframe into the existing output, replacing stale data.
                    if var existing = self.output {
                        let newLabels = Set(data.timeframes.map(\.label))
                        existing.timeframes.removeAll { newLabels.contains($0.label) }
                        existing.timeframes.append(contentsOf: data.timeframes)
                        let order = ["Day": 0, "Week": 1, "Month": 2]
                        existing.timeframes.sort { (order[$0.label] ?? 99) < (order[$1.label] ?? 99) }
                        self.output = existing
                    } else {
                        self.output = data
                    }
                    self.loadingTimeframes.remove(tf)
                    self.lastUpdated = Date()
                    self.consecutiveErrors = 0

                    // Update available accounts from CLI response (only on first load).
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
                    self.loadingTimeframes.remove(tf)
                    self.error = err
                    consecutiveErrors += 1
                    if consecutiveErrors >= 3 {
                        logger.warning("3 consecutive errors — pausing auto-refresh")
                        stopAutoRefresh()
                    }
                }
            }
        }

        isLoading = false

        // Restart auto-refresh if it was stopped due to consecutive errors.
        if manual && refreshTimer == nil && error == nil {
            restartTimer()
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
        restartTimer()
        observeSleepWake()
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func restartTimer() {
        refreshTimer?.invalidate()
        let interval = TimeInterval(max(refreshMinutes, 1) * 60)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.refresh() }
        }
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
            self.restartTimer()
        }
    }
}
