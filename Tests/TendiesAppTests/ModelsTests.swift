import Foundation
import Testing
@testable import TendiesApp

@Suite("Models")
struct ModelsTests {

    // MARK: - TendiesOutput decoding

    @Test func decodeFull() throws {
        let json = """
        {
            "timeframes": [
                {
                    "label": "Day",
                    "gains": 500.0,
                    "losses": -200.0,
                    "net": 300.0,
                    "trade_count": 5,
                    "tickers": [
                        {
                            "symbol": "AAPL",
                            "display": "AAPL",
                            "type": "equity",
                            "underlying": null,
                            "expiry": null,
                            "strike": null,
                            "option_type": null,
                            "net": 300.0,
                            "trade_count": 5,
                            "closes": [
                                {
                                    "time": "2024-03-04T14:30:00Z",
                                    "side": "SELL",
                                    "quantity": 100.0,
                                    "price": 175.50,
                                    "pnl": 300.0,
                                    "matched_opens": [
                                        {
                                            "time": "2024-03-04T10:00:00Z",
                                            "side": "BUY",
                                            "quantity": 100.0,
                                            "price": 172.50
                                        }
                                    ]
                                }
                            ]
                        }
                    ]
                }
            ],
            "accounts": ["Acct1", "Acct2"],
            "account_ids": ["hash-a", "hash-b"],
            "warnings": [],
            "updated_at": "2024-03-04T15:00:00Z"
        }
        """
        let data = Data(json.utf8)
        let output = try JSONDecoder().decode(TendiesOutput.self, from: data)

        #expect(output.timeframes.count == 1)
        #expect(output.timeframes[0].label == "Day")
        #expect(output.timeframes[0].net == 300.0)
        #expect(output.timeframes[0].tradeCount == 5)
        #expect(output.timeframes[0].tickers.count == 1)
        #expect(output.timeframes[0].tickers[0].symbol == "AAPL")
        #expect(output.timeframes[0].tickers[0].closes?.count == 1)
        #expect(output.timeframes[0].tickers[0].closes?[0].matchedOpens.count == 1)
        #expect(output.accounts == ["Acct1", "Acct2"])
        #expect(output.accountIDs == ["hash-a", "hash-b"])
        #expect(output.updatedAt == "2024-03-04T15:00:00Z")
    }

    @Test func decodeMissingOptionals() throws {
        let json = """
        {
            "timeframes": [
                {
                    "label": "Week",
                    "gains": 0,
                    "losses": 0,
                    "net": 0,
                    "trade_count": 0,
                    "tickers": [
                        {
                            "symbol": "SPY 250321C500",
                            "display": "SPY 3/21 $500 Call",
                            "type": "option",
                            "net": -50.0,
                            "trade_count": 1
                        }
                    ]
                }
            ],
            "accounts": [],
            "account_ids": [],
            "warnings": ["some warning"],
            "updated_at": "2024-03-04T15:00:00Z"
        }
        """
        let data = Data(json.utf8)
        let output = try JSONDecoder().decode(TendiesOutput.self, from: data)

        let ticker = output.timeframes[0].tickers[0]
        #expect(ticker.underlying == nil)
        #expect(ticker.expiry == nil)
        #expect(ticker.strike == nil)
        #expect(ticker.optionType == nil)
        #expect(ticker.closes == nil)
        #expect(output.warnings == ["some warning"])
    }

    // MARK: - TendiesError decoding

    @Test func decodeTendiesError() throws {
        let json = """
        {"error": "auth_expired", "message": "Token has expired"}
        """
        let data = Data(json.utf8)
        let err = try JSONDecoder().decode(TendiesError.self, from: data)

        #expect(err.error == "auth_expired")
        #expect(err.message == "Token has expired")
    }

    // MARK: - MatchedOpen optional side

    @Test func matchedOpenOptionalSide() throws {
        let json = """
        {"time": "2024-03-04T10:00:00Z", "quantity": 50.0, "price": 100.0}
        """
        let data = Data(json.utf8)
        let open = try JSONDecoder().decode(MatchedOpen.self, from: data)
        #expect(open.side == nil)
        #expect(open.quantity == 50.0)
    }
}
