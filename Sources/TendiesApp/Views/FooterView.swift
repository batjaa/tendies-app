import SwiftUI

struct FooterView: View {
    let lastUpdated: Date?
    let isLoading: Bool
    var isAuthenticated: Bool = false
    var subscriptionStatus: SubscriptionStatus?
    var trialEndsAt: String?
    var proUntil: String?
    var onLogout: (() -> Void)?
    var onManageSubscription: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            if let trialText = trialBadgeText {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text(trialText)
                        .font(.system(size: 11))
                }
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                Divider()
            } else if let proText = proBadgeText {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                    Text(proText)
                        .font(.system(size: 11))
                }
                .foregroundStyle(.purple)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                Divider()
            }
            HStack {
                if isLoading, lastUpdated != nil {
                    Text("Updating...")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                } else if let lastUpdated {
                    Text("Updated \(lastUpdated, format: .relative(presentation: .named))")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                if subscriptionStatus == .active, proUntil == nil, let onManageSubscription {
                    Button("Manage subscription") {
                        onManageSubscription()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
                if isAuthenticated, let onLogout {
                    Button("Log out") {
                        onLogout()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var proBadgeText: String? {
        guard subscriptionStatus == .active, let proUntil else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var endDate = formatter.date(from: proUntil)
        if endDate == nil {
            formatter.formatOptions = [.withInternetDateTime]
            endDate = formatter.date(from: proUntil)
        }
        guard let endDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0
        if days <= 0 { return nil }
        return "Pro access — \(days) \(days == 1 ? "day" : "days") remaining"
    }

    private var trialBadgeText: String? {
        guard subscriptionStatus == .trialing, let trialEndsAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var endDate = formatter.date(from: trialEndsAt)
        if endDate == nil {
            formatter.formatOptions = [.withInternetDateTime]
            endDate = formatter.date(from: trialEndsAt)
        }
        guard let endDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0
        if days <= 0 { return nil }
        return days == 1 ? "1 day left in trial" : "\(days) days left in trial"
    }
}
