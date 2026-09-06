import Foundation

// MARK: - Formatting helpers

extension Double {
    /// Formats a price with the given currency symbol, preserving 2 decimals (or 2 when > 0.01).
    func formattedPrice(symbol: String, locale: Locale = Locale(identifier: "es_ES")) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let number = formatter.string(from: NSNumber(value: self)) ?? String(format: "%.2f", self)
        return "\(symbol)\(number)"
    }

    func percentFormatted(locale: Locale = Locale(identifier: "es_ES")) -> String {
        let value = self
        return String(format: "%.1f%%", value)
    }

    func rounded2() -> Double {
        (self * 100).rounded() / 100
    }
}

extension Int {
    var thousandsFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension Date {
    var relativeShort: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

/// Converts a count to its Spanish ordinal-ish label (1º, 2º, ...).
func ordinal(_ n: Int) -> String {
    "\(n)º"
}