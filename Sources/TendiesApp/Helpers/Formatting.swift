import Foundation

// MARK: - P&L Formatting

func formatPnL(_ value: Double) -> String {
    let sign = value > 0 ? "+" : value < 0 ? "-" : ""
    let absVal = abs(value)
    return "\(sign)$\(String(format: "%.2f", absVal))"
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

private func formatWholeNumber(_ n: Int) -> String {
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

func formatQuantity(_ qty: Double, type: String) -> String {
    let intQty = Int(qty)
    if type == "equity" {
        return "\(intQty)sh"
    }
    return "\(intQty)"
}
