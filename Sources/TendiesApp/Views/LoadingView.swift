import SwiftUI

/// Full loading state shown on initial load — centered spinner with text.
struct LoadingView: View {
    var timeframes: [String] = ["Day", "Week", "Month"]

    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("Loading P&L data...")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

/// Inline skeleton row for a single timeframe that is still loading.
struct TimeframeLoadingRow: View {
    let label: String

    var body: some View {
        HStack(spacing: 0) {
            Text("◌")
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
                .frame(width: 16)

            Text(label)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .leading)

            Spacer()

            RoundedRectangle(cornerRadius: 3)
                .fill(Color.primary.opacity(0.04))
                .frame(width: 70, height: 12)

            RoundedRectangle(cornerRadius: 3)
                .fill(Color.primary.opacity(0.04))
                .frame(width: 50, height: 10)
                .padding(.leading, 10)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }
}
