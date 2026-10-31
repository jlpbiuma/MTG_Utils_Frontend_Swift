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

/// Symbols of each face of a cost such as `{1}{R} // {1}{U}`; empty faces are dropped.
func parseManaCostFaces(_ cost: String?) -> [[String]] {
    guard let cost, !cost.isEmpty else { return [] }
    return cost.components(separatedBy: "//").map(parseManaCostSymbols).filter { !$0.isEmpty }
}

/// Colors and Phyrexian flag of a hybrid/Phyrexian symbol (`W/U`, `2/W`, `B/P`, `G/U/P`).
func compositeManaParts(_ symbol: String) -> (parts: [String], phyrexian: Bool)? {
    let pieces = symbol.uppercased().split(separator: "/").map(String.init)
    guard pieces.count > 1 else { return nil }
    let phyrexian = pieces.contains("P")
    let parts = pieces.filter { $0 != "P" }
    let colors: Set<String> = ["W", "U", "B", "R", "G", "C"]
    guard parts.contains(where: colors.contains),
          parts.allSatisfy({ colors.contains($0) || Int($0) != nil }),
          parts.count <= 2, phyrexian || parts.count == 2 else { return nil }
    return (parts, phyrexian)
}
