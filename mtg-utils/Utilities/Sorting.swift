import Foundation

// MARK: - Sorting

enum SortField: String, CaseIterable, Hashable, Identifiable {
    case name
    case cmc
    case price
    case type
    case color
    case category

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .name: return "Nombre"
        case .cmc: return "Coste de maná"
        case .price: return "Precio"
        case .type: return "Tipo"
        case .color: return "Color"
        case .category: return "Categoría"
        }
    }
}

enum SortDirection: String, CaseIterable, Hashable, Identifiable {
    case ascending
    case descending

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ascending: return "Ascendente"
        case .descending: return "Descendente"
        }
    }
}

/// Extracts the converted mana cost (CMC) from an MTG mana-cost string like `{2}{U}{U}`.
/// Mirrors the web app's `extractCmc`: `{X}`/`{Y}`/`{Z}` contribute 0, hybrid
/// (`{W/U}`) and phyrexian (`{W/P}`) symbols cost 1, numbers contribute their value.
func extractCmc(from manaCost: String?) -> Double {
    guard let manaCost, !manaCost.isEmpty else { return 0 }

    var total: Double = 0
    var scanner = Substring(manaCost)

    while let start = scanner.firstIndex(of: "{") {
        scanner = scanner[scanner.index(after: start)...]
        guard let end = scanner.firstIndex(of: "}") else { break }
        let token = String(scanner[..<end])
        scanner = scanner[scanner.index(after: end)...]

        switch token {
        case "X", "Y", "Z":
            continue
        default:
            if token.contains("/") {
                // Hybrid or phyrexian symbol costs 1.
                total += 1
            } else if let number = Double(token) {
                total += number
            } else if let value = coloredManaValue(token) {
                total += value
            } else {
                // Unknown/other symbol paid in generic terms costs 1.
                total += 1
            }
        }
    }

    return total
}

private func coloredManaValue(_ symbol: String) -> Double? {
    let colorMultipliers = ["W": 1.0, "U": 1.0, "B": 1.0, "R": 1.0, "G": 1.0]
    if let value = colorMultipliers[symbol] { return value }
    // Other single-letter symbols not listed (e.g. "C") cost 1.
    if symbol.count == 1, symbol.rangeOfCharacter(from: .uppercaseLetters) != nil { return 1 }
    return nil
}

/// Protocol for any model that can be sorted.
protocol SortableCard {
    var name: String { get }
    var manaCost: String? { get }
    var cmc: Double? { get }
    var typeLine: String? { get }
    var price: Double { get }
    var colors: [String] { get }
    var category: CardTypeCategory { get }
}

extension SortableCard {
    var cmcValue: Double { cmc ?? extractCmc(from: manaCost) }
    var colors: [String] { [] }
    var category: CardTypeCategory { getCardCategory(typeLine: typeLine, cardName: name) }
}

func sortCards<T: SortableCard>(
    _ cards: [T],
    by field: SortField,
    direction: SortDirection
) -> [T] {
    switch field {
    case .name:
        return compareCards(cards, by: { $0.name.localizedCaseInsensitiveCompare($1.name) }, direction)
    case .cmc:
        return compareCards(cards, by: { $0.cmcValue.compareValue(to: $1.cmcValue) }, direction)
    case .price:
        return compareCards(cards, by: { $0.price.compareValue(to: $1.price) }, direction)
    case .type:
        return compareCards(cards, by: { $0.typeLineValue.compareValue(to: $1.typeLineValue) }, direction)
    case .color:
        return compareCards(cards, by: { colorsKey($0.colors).compareValue(to: colorsKey($1.colors)) }, direction)
    case .category:
        return compareCards(cards, by: { groupingKey($0.category).compareValue(to: groupingKey($1.category)) }, direction)
    }
}

private func compareCards<T: SortableCard>(
    _ cards: [T],
    by compare: (T, T) -> ComparisonResult,
    _ direction: SortDirection
) -> [T] {
    cards.sorted { a, b in
        let result = compare(a, b)
        if result == .orderedSame {
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        return direction == .ascending ? (result == .orderedAscending) : (result == .orderedDescending)
    }
}

extension Comparable {
    func compareValue(to other: Self) -> ComparisonResult {
        if self < other { return .orderedAscending }
        if self > other { return .orderedDescending }
        return .orderedSame
    }
}

enum DeckSortField: String, CaseIterable, Hashable, Identifiable {
    case completion
    case price
    case name
    case date

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .completion: return "Completitud"
        case .price: return "Precio"
        case .name: return "Nombre"
        case .date: return "Fecha"
        }
    }
}

/// Extracts distinct MTG colors from a mana-cost string in W, U, B, R, G order.
func extractColors(from manaCost: String?) -> [String] {
    guard let manaCost, !manaCost.isEmpty else { return [] }
    let symbols = parseManaCostSymbols(manaCost)
    var set = Set<String>()
    for sym in symbols {
        let u = sym.uppercased()
        if u.contains("W") { set.insert("W") }
        if u.contains("U") { set.insert("U") }
        if u.contains("B") { set.insert("B") }
        if u.contains("R") { set.insert("R") }
        if u.contains("G") { set.insert("G") }
    }
    let order = ["W", "U", "B", "R", "G"]
    return order.filter { set.contains($0) }
}

/// Deduces color identity of a deck from its cards.
func extractDeckColors(cards: [DeckCard]) -> [String] {
    var set = Set<String>()
    for card in cards {
        let cardColors = extractColors(from: card.manaCost)
        set.formUnion(cardColors)
    }
    let order = ["W", "U", "B", "R", "G"]
    return order.filter { set.contains($0) }
}

/// Estimates total deck price from its cards using deterministic representative pricing.
func estimateDeckPrice(cards: [DeckCard]) -> Double {
    let total = cards.reduce(0.0) { sum, card in
        sum + (representativePrice(card.cardName, card.typeLine) * Double(card.quantity))
    }
    return total.rounded2()
}

private func colorsKey(_ colors: [String]) -> String {
    colors.sorted().joined(separator: ",")
}

private func groupingKey(_ category: CardTypeCategory) -> Int {
    cardTypeGroups[category]?.order ?? 999
}

extension SortableCard {
    var typeLineValue: String { typeLine ?? "" }
}

extension DeckCardWithOwnership: SortableCard {
    var name: String { cardName }
    var cmc: Double? { nil }
    var price: Double { representativePrice(cardName, typeLine) }
    var colors: [String] { extractColors(from: manaCost) }
}

extension CollectionCard: SortableCard {
    var name: String { cardName }
    var cmc: Double? { nil }
    var price: Double { representativePrice(cardName, typeLine) }
    var colors: [String] { extractColors(from: manaCost) }
}