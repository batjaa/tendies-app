import SwiftUI

struct TimeframeRowView: View {
    let timeframe: Timeframe
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 16)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))

                Text(timeframe.label)
                    .font(.system(size: 12.5, weight: .medium))
                    .frame(width: 46, alignment: .leading)

                Spacer()

                Text(formatPnL(timeframe.net))
                    .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(pnlColor(timeframe.net))
                    .frame(alignment: .trailing)

                Text("\(timeframe.tradeCount) trades")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(width: 62, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isExpanded ? Color.primary.opacity(0.05) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

func pnlColor(_ value: Double) -> Color {
    if value > 0 { return .green }
    if value < 0 { return .red }
    return .primary
}
