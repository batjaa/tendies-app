import Foundation
import os
import SwiftUI

private let logger = Logger(subsystem: "site.batjaa.tendies-app", category: "AppState")

@Observable
final class AppState {
    var output: TendiesOutput?
    var error: AppError?
    var isLoading = false
    var lastUpdated: Date?
    var loginError: String?
    var subscriptionStatus: SubscriptionStatus?
    var trialEndsAt: String?

    // Settings (defaults — will be backed by UserDefaults in Step 8).
    var refreshMinutes: Int = 1
    var menuBarTimeframe: String = "Day"
    var enabledTimeframes: [String] = ["Day"]
    var direct: Bool = false
    var symbols: String = ""
    var cliPath: String?

    let authService = AuthService()

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

        isLoading = true
        defer { isLoading = false }
        logger.notice("Refreshing with timeframes=\(self.enabledTimeframes.joined(separator: ","))")

        let result = await CLIRunner.run(
            customPath: cliPath,
            direct: direct,
            symbols: symbols.isEmpty ? nil : symbols,
            timeframes: enabledTimeframes
        )

        switch result {
        case .success(let data):
            self.output = data
            self.error = nil
            self.lastUpdated = Date()
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
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Label formatting

private func formatMenuBarLabel(_ net: Double) -> String {
    let absVal = abs(net)
    let formatted: String

    if absVal >= 1_000_000 {
        formatted = "$\(String(format: "%.1f", absVal / 1_000_000))M"
    } else if absVal >= 10_000 {
        formatted = "$\(String(format: "%.1f", absVal / 1_000))K"
    } else {
        formatted = "$\(formatWholeNumber(Int(absVal)))"
    }

    if net > 0 {
        return "▲ +\(formatted)"
    } else if net < 0 {
        return "▼ -\(formatted)"
    } else {
        return "● $0"
    }
}

private func formatWholeNumber(_ n: Int) -> String {
    let s = String(n)
    guard s.count > 3 else { return s }
    var result = ""
    for (i, ch) in s.reversed().enumerated() {
        if i > 0 && i % 3 == 0 { result.append(",") }
        result.append(ch)
    }
    return String(result.reversed())
}
