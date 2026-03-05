import Testing
@testable import TendiesApp

@Suite("Formatting")
struct FormattingTests {

    // MARK: - formatPnL

    @Test func formatPnL_positive() {
        #expect(formatPnL(123.45) == "+$123.45")
    }

    @Test func formatPnL_negative() {
        #expect(formatPnL(-42.10) == "-$42.10")
    }

    @Test func formatPnL_zero() {
        #expect(formatPnL(0) == "$0.00")
    }

    @Test func formatPnL_large() {
        #expect(formatPnL(99999.99) == "+$99999.99")
    }

    // MARK: - formatPnLCompact

    @Test func formatPnLCompact_millions() {
        #expect(formatPnLCompact(1_500_000) == "+$1.5M")
    }

    @Test func formatPnLCompact_thousands() {
        #expect(formatPnLCompact(25_000) == "+$25.0K")
    }

    @Test func formatPnLCompact_commas() {
        #expect(formatPnLCompact(5_432) == "+$5,432")
    }

    @Test func formatPnLCompact_zero() {
        #expect(formatPnLCompact(0) == "$0")
    }

    @Test func formatPnLCompact_negative() {
        #expect(formatPnLCompact(-75_000) == "-$75.0K")
    }

    // MARK: - formatWholeNumber

    @Test func formatWholeNumber_threeDigits() {
        #expect(formatWholeNumber(999) == "999")
    }

    @Test func formatWholeNumber_fourDigits() {
        #expect(formatWholeNumber(1234) == "1,234")
    }

    @Test func formatWholeNumber_sevenDigits() {
        #expect(formatWholeNumber(1_234_567) == "1,234,567")
    }

    // MARK: - formatMenuBarLabel

    @Test func formatMenuBarLabel_positive() {
        #expect(formatMenuBarLabel(250) == "▲ +$250")
    }

    @Test func formatMenuBarLabel_negative() {
        #expect(formatMenuBarLabel(-1300) == "▼ -$1,300")
    }

    @Test func formatMenuBarLabel_zero() {
        #expect(formatMenuBarLabel(0) == "● $0")
    }

    @Test func formatMenuBarLabel_thousands() {
        #expect(formatMenuBarLabel(15_000) == "▲ +$15.0K")
    }

    @Test func formatMenuBarLabel_millions() {
        #expect(formatMenuBarLabel(-2_500_000) == "▼ -$2.5M")
    }

    // MARK: - formatTradeTime

    @Test func formatTradeTime_validISO() {
        let result = formatTradeTime("2024-03-04T14:30:00Z")
        #expect(result != "2024-03-04T14:30:00Z")
        #expect(result.contains(":"))
    }

    @Test func formatTradeTime_fractionalSeconds() {
        let result = formatTradeTime("2024-03-04T14:30:00.123Z")
        #expect(result != "2024-03-04T14:30:00.123Z")
        #expect(result.contains(":"))
    }

    @Test func formatTradeTime_invalidFallback() {
        #expect(formatTradeTime("not-a-date") == "not-a-date")
    }

    // MARK: - formatSideShort

    @Test func formatSideShort_buyToOpen() {
        #expect(formatSideShort("BUY_TO_OPEN") == "bought")
    }

    @Test func formatSideShort_sellToOpen() {
        #expect(formatSideShort("SELL_TO_OPEN") == "sold")
    }

    @Test func formatSideShort_buy() {
        #expect(formatSideShort("BUY") == "bought")
    }

    @Test func formatSideShort_sell() {
        #expect(formatSideShort("SELL") == "sold")
    }

    @Test func formatSideShort_unknown() {
        #expect(formatSideShort("SOMETHING_ELSE") == "opened")
    }

    // MARK: - formatQuantity

    @Test func formatQuantity_equity() {
        #expect(formatQuantity(100, type: "equity") == "100sh")
    }

    @Test func formatQuantity_option() {
        #expect(formatQuantity(5, type: "option") == "5")
    }
}
