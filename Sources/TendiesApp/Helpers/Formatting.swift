import Foundation

// MARK: - P&L Formatting

private let currencyFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.minimumFractionDigits = 2
    f.maximumFractionDigits = 2
    f.groupingSeparator = ","
    f.usesGroupingSeparator = true
    return f
}()

func formatPnL(_ value: Double) -> String {
    let sign = value > 0 ? "+" : value < 0 ? "-" : ""
    let absVal = abs(value)
    let num = currencyFormatter.string(from: NSNumber(value: absVal)) ?? String(format: "%.2f", absVal)
    return "\(sign)$\(num)"
}

func formatPnLCompact(_ value: Double) -> String {
    let absVal = abs(value)
    let formatted: String

    if absVal >= 1_000_000 {
        formatted = "$\(String(format: "%.1f", absVal / 1_000_000))M"
    } else if absVal >= 10_000 {
        formatted = "$\(String(format: "%.1f", absVal / 1_000))K"
    } else {
        formatted = "$\(formatWholeNumber(Int(absVal)))"
    }

    if value > 0 {
        return "+\(formatted)"
    } else if value < 0 {
        return "-\(formatted)"
    } else {
        return "$0"
    }
}

func formatWholeNumber(_ n: Int) -> String {
    let s = String(n)
    guard s.count > 3 else { return s }
    var result = ""
    for (i, ch) in s.reversed().enumerated() {
        if i > 0 && i % 3 == 0 { result.append(",") }
        result.append(ch)
    }
    return String(result.reversed())
}

// MARK: - Time Formatting

func formatTradeTime(_ isoString: String) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: isoString) {
        let tf = DateFormatter()
        tf.dateFormat = "h:mm"
        return tf.string(from: date)
    }
    // Try without fractional seconds.
    formatter.formatOptions = [.withInternetDateTime]
    if let date = formatter.date(from: isoString) {
        let tf = DateFormatter()
        tf.dateFormat = "h:mm"
        return tf.string(from: date)
    }
    return isoString
}

// MARK: - Side Formatting

/// Converts instruction like "BUY_TO_OPEN" to a short label for matched opens.
func formatSideShort(_ side: String) -> String {
    switch side {
    case "BUY", "BUY_TO_OPEN": return "bought"
    case "SELL", "SELL_TO_OPEN": return "sold"
    default: return "opened"
    }
}

func formatQuantity(_ qty: Double, type: String) -> String {
    let intQty = Int(qty)
    if type == "equity" {
        return "\(intQty)sh"
    }
    return "\(intQty)"
}

// MARK: - Menu Bar Label

func formatMenuBarLabel(_ net: Double) -> String {
    let absVal = abs(net)
    let formatted: String

    if absVal >= 1_000_000 {
        formatted = "$\(String(format: "%.1f", absVal / 1_000_000))M"
    } else if absVal >= 10_000 {
        formatted = "$\(String(format: "%.1f", absVal / 1_000))K"
    } else {
        formatted = "$\(formatWholeNumber(Int(absVal)))"
    }

    if net > 0 {
        return "▲ +\(formatted)"
    } else if net < 0 {
        return "▼ -\(formatted)"
    } else {
        return "● $0"
    }
}
