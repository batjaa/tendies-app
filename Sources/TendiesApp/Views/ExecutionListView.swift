import SwiftUI

struct ExecutionListView: View {
    let closes: [CloseTrade]
    let tickerType: String
    var showDate: Bool = false

    private var executions: [Execution] {
        var result: [Execution] = []
        for close in closes {
            for open in close.matchedOpens {
                result.append(Execution(
                    time: open.time,
                    side: open.side ?? (tickerType == "option" ? "BUY_TO_OPEN" : "BUY"),
                    quantity: open.quantity,
                    price: open.price,
                    pnl: nil
                ))
            }
            result.append(Execution(
                time: close.time,
                side: close.side,
                quantity: close.quantity,
                price: close.price,
                pnl: close.pnl
            ))
        }
        // Merge opens from the same lot (same time+price+side) by summing quantity.
        var closes: [Execution] = []
        var opensByKey: [(key: String, exec: Execution)] = []
        for exec in result {
            if exec.pnl != nil {
                closes.append(exec)
            } else {
                let key = "\(exec.time)|\(exec.price)|\(exec.side)"
                if let idx = opensByKey.firstIndex(where: { $0.key == key }) {
                    let prev = opensByKey[idx].exec
                    opensByKey[idx] = (key, Execution(
                        time: prev.time, side: prev.side,
                        quantity: prev.quantity + exec.quantity,
                        price: prev.price, pnl: nil
                    ))
                } else {
                    opensByKey.append((key, exec))
                }
            }
        }
        var merged = opensByKey.map(\.exec) + closes
        merged.sort { a, b in a.time < b.time }
        return merged
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(executions.enumerated()), id: \.offset) { _, exec in
                HStack(spacing: 0) {
                    Text(formatTradeTime(exec.time, showDate: showDate))
                        .foregroundStyle(.tertiary)
                        .frame(width: showDate ? 58 : 36, alignment: .leading)

                    Text(" \(formatQuantity(exec.quantity, type: tickerType)) @ $\(String(format: "%.2f", exec.price))")
                        .foregroundStyle(.tertiary)

                    Spacer()

                    Text(sideLabel(exec.side))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(sideColor(exec.side).opacity(0.7))
                        .frame(width: 28, alignment: .trailing)
                        .padding(.trailing, 8)

                    if let pnl = exec.pnl {
                        Text(formatPnL(pnl))
                            .foregroundStyle(pnlColor(pnl))
                            .frame(minWidth: 50, alignment: .trailing)
                    } else {
                        Text("—")
                            .foregroundStyle(.tertiary)
                            .frame(minWidth: 50, alignment: .trailing)
                    }
                }
                .font(.system(size: 10, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
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

private struct Execution {
    let time: String
    let side: String
    let quantity: Double
    let price: Double
    let pnl: Double?
}

private func sideLabel(_ side: String) -> String {
    switch side {
    case "BUY_TO_OPEN": return "BTO"
    case "SELL_TO_CLOSE": return "STC"
    case "BUY_TO_CLOSE": return "BTC"
    case "SELL_TO_OPEN": return "STO"
    case "BUY": return "BUY"
    case "SELL": return "SELL"
    default: return side
    }
}

private func sideColor(_ side: String) -> Color {
    switch side {
    case "BUY", "BUY_TO_OPEN", "BUY_TO_CLOSE": return .green
    case "SELL", "SELL_TO_OPEN", "SELL_TO_CLOSE": return .red
    default: return .secondary
    }
}
