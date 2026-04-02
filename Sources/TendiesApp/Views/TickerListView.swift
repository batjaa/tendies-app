import SwiftUI

struct TickerListView: View {
    let tickers: [Ticker]
    var sortOrder: String = "az"
    var timeframeLabel: String = "Day"
    var instrumentFilter: Set<String> = ["equity", "option", "future"]
    var groupBy: String = "ticker"

    private static let typeOrder = ["equity", "option", "future"]
    private static let typeLabels = ["equity": "Equities", "option": "Options", "future": "Futures"]

    private var filteredTickers: [Ticker] {
        let filtered = tickers.filter { instrumentFilter.contains($0.type) }
        if sortOrder == "pnl" {
            return filtered.sorted { abs($0.net) > abs($1.net) }
        }
        return filtered
    }

    private var groupedTickers: [(key: String, tickers: [Ticker])] {
        guard groupBy == "type" else { return [] }
        let grouped = Dictionary(grouping: filteredTickers, by: { $0.type })
        return Self.typeOrder.compactMap { type in
            guard let tickers = grouped[type], !tickers.isEmpty else { return nil }
            return (key: type, tickers: tickers)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if groupBy == "type" {
                ForEach(groupedTickers, id: \.key) { group in
                    HStack {
                        Text(Self.typeLabels[group.key] ?? group.key)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 6)
                    .padding(.bottom, 2)

                    ForEach(group.tickers, id: \.symbol) { ticker in
                        TickerRowView(ticker: ticker, showDate: timeframeLabel != "Day")
                    }
                }
            } else {
                ForEach(filteredTickers, id: \.symbol) { ticker in
                    TickerRowView(ticker: ticker, showDate: timeframeLabel != "Day")
                }
            }
        }
        .background(Color.primary.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
    }
}

struct TickerRowView: View {
    let ticker: Ticker
    var showDate: Bool = false
    @State private var isExpanded = false
    @State private var isHovered = false

    private var hasCloses: Bool {
        ticker.closes != nil && !(ticker.closes?.isEmpty ?? true)
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                guard hasCloses else { return }
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 0) {
                    if hasCloses {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 16)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    } else {
                        Spacer().frame(width: 16)
                    }

                    Text(ticker.display)
                        .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                        .lineLimit(1)

                    Spacer()

                    Text(formatPnL(ticker.net))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(pnlColor(ticker.net))

                    Text("\(ticker.tradeCount) exe")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .frame(width: 36, alignment: .trailing)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(isHovered ? Color.primary.opacity(0.03) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .onHover { hovering in isHovered = hovering }

            if isExpanded, let closes = ticker.closes {
                ExecutionListView(closes: closes, tickerType: ticker.type, showDate: showDate)
            }
        }
    }
}
