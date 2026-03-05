import SwiftUI

struct TickerListView: View {
    let tickers: [Ticker]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(tickers, id: \.symbol) { ticker in
                TickerRowView(ticker: ticker)
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
    @State private var isExpanded = false

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
            }
            .buttonStyle(.plain)

            if isExpanded, let closes = ticker.closes {
                ExecutionListView(closes: closes, tickerType: ticker.type)
            }
        }
    }
}
