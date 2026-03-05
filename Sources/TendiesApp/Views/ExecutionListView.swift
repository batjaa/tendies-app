import SwiftUI

struct ExecutionListView: View {
    let closes: [CloseTrade]
    let tickerType: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(closes.enumerated()), id: \.offset) { _, close in
                // Closing trade row.
                HStack(spacing: 0) {
                    Text(formatTradeTime(close.time))
                        .frame(width: 36, alignment: .leading)
                    Text(close.side)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                    Text(" \(formatQuantity(close.quantity, type: tickerType)) @ $\(String(format: "%.2f", close.price))")
                    Spacer()
                    Text(formatPnL(close.pnl))
                        .foregroundStyle(pnlColor(close.pnl))
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)

                // Matched opening legs.
                ForEach(Array(close.matchedOpens.enumerated()), id: \.offset) { idx, open in
                    let connector = idx == close.matchedOpens.count - 1 ? "└" : "├"
                    let sideLabel = open.side.map { formatSideShort($0) } ?? "opened"
                    Text("\(connector) \(sideLabel) \(formatTradeTime(open.time))  \(formatQuantity(open.quantity, type: tickerType)) @ $\(String(format: "%.2f", open.price))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 1)
                }
            }
        }
        .padding(.leading, 16)
        .padding(.vertical, 2)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(width: 1)
                .padding(.leading, 20)
        }
    }
}
