import AppKit
import SwiftUI

struct SubscriptionView: View {
    @Bindable var appState: AppState
    @State private var isLoadingCheckout = false
    @State private var checkoutError: String?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text("Your free trial has ended")
                .font(.system(size: 12.5, weight: .medium))

            if let trialEndsAt = appState.trialEndsAt {
                Text("Trial ended \(formatTrialDate(trialEndsAt))")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Text("Subscribe to keep tracking your P&L.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                Button(action: { startCheckout(plan: "monthly") }) {
                    HStack(spacing: 6) {
                        if isLoadingCheckout {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Monthly ($5/mo)")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoadingCheckout)

                Button(action: { startCheckout(plan: "yearly") }) {
                    HStack(spacing: 6) {
                        Text("Yearly ($40/yr)")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .disabled(isLoadingCheckout)
            }

            if let checkoutError {
                Text(checkoutError)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: { Task { await appState.refresh() } }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                    Text("Refresh status")
                        .font(.system(size: 11))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private func startCheckout(plan: String) {
        isLoadingCheckout = true
        checkoutError = nil
        Task {
            defer { isLoadingCheckout = false }
            do {
                let urlString = try await appState.getCheckoutURL(plan: plan)
                if let url = URL(string: urlString) {
                    NSWorkspace.shared.open(url)
                } else {
                    checkoutError = "Invalid checkout URL"
                }
            } catch {
                checkoutError = error.localizedDescription
            }
        }
    }

    private func formatTrialDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            return formatRelativeDate(date)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: isoString) {
            return formatRelativeDate(date)
        }
        return isoString
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let rf = RelativeDateTimeFormatter()
        rf.unitsStyle = .full
        return rf.localizedString(for: date, relativeTo: Date())
    }
}
