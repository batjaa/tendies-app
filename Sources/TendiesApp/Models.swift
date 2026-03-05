import Foundation

struct TendiesOutput: Codable {
    let timeframes: [Timeframe]
    let accounts: [String]
    let warnings: [String]
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case timeframes, accounts, warnings
        case updatedAt = "updated_at"
    }
}

struct Timeframe: Codable {
    let label: String
    let gains: Double
    let losses: Double
    let net: Double
    let tradeCount: Int
    let tickers: [Ticker]

    enum CodingKeys: String, CodingKey {
        case label, gains, losses, net, tickers
        case tradeCount = "trade_count"
    }
}

struct Ticker: Codable {
    let symbol: String
    let display: String
    let type: String
    let underlying: String?
    let expiry: String?
    let strike: Double?
    let optionType: String?
    let net: Double
    let tradeCount: Int
    let closes: [CloseTrade]?

    enum CodingKeys: String, CodingKey {
        case symbol, display, type, underlying, expiry, strike, net, closes
        case optionType = "option_type"
        case tradeCount = "trade_count"
    }
}

struct CloseTrade: Codable {
    let time: String
    let side: String
    let quantity: Double
    let price: Double
    let pnl: Double
    let matchedOpens: [MatchedOpen]

    enum CodingKeys: String, CodingKey {
        case time, side, quantity, price, pnl
        case matchedOpens = "matched_opens"
    }
}

struct MatchedOpen: Codable {
    let time: String
    let side: String?
    let quantity: Double
    let price: Double
}

struct TendiesError: Codable {
    let error: String
    let message: String
}
