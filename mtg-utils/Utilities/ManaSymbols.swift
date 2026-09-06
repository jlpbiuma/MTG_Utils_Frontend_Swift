import Foundation

// MARK: - Mana cost symbol parsing (pure, unit-testable)

/// Extracts the individual symbols from an MTG mana-cost string like `{2}{U}{U}`.
/// Returns an empty array for `nil` or empty input.
func parseManaCostSymbols(_ cost: String?) -> [String] {
    guard let cost, !cost.isEmpty else { return [] }

    var result: [String] = []
    var scanner = Substring(cost)

    while let start = scanner.firstIndex(of: "{") {
        scanner = scanner[scanner.index(after: start)...]
        guard let end = scanner.firstIndex(of: "}") else { break }
        result.append(String(scanner[..<end]))
        scanner = scanner[scanner.index(after: end)...]
    }

    return result
}

/// The 1–2 character glyph shown inside a mana pill for a symbol.
func manaPillGlyph(_ symbol: String) -> String {
    switch symbol.uppercased() {
    case "W": return "W"
    case "U": return "U"
    case "B": return "B"
    case "R": return "R"
    case "G": return "G"
    case "C": return "C"
    case "S": return "S"
    case "E": return "E"
    case "X", "Y", "Z": return symbol.uppercased()
    default:
        let parts = symbol.split(separator: "/")
        if parts.count == 2 {
            return "\(parts[0])/\(parts[1])"
        }
        return symbol
    }
}