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

/// Mana value from an MTG mana-cost string like `{2}{U}{U}`. Mirrors the web
/// app's `extractCmc`: `{X}`/`{Y}`/`{Z}` are 0, hybrid symbols cost their most
/// expensive half (`{2/W}` is 2, `{W/U}` and Phyrexian `{W/P}` are 1) and half
/// mana (`{HW}`, `{1/2}`) is 0.5. A split cost (`{1}{R} // {1}{U}`) adds both
/// halves; Adventure and Omen cards only count their main half.
func extractCmc(from manaCost: String?, typeLine: String? = nil) -> Double {
    guard let manaCost, !manaCost.isEmpty else { return 0 }

    var halves = manaCost.components(separatedBy: "//")
    if halves.count > 1, let type = typeLine?.lowercased(),
       ["adventure", "aventura", "omen", "presagio"].contains(where: type.contains) {
        halves = Array(halves.prefix(1))
    }
    return halves.flatMap(parseManaCostSymbols).reduce(0) { $0 + symbolManaValue($1) }
}

private func symbolManaValue(_ symbol: String) -> Double {
    let token = symbol.trimmingCharacters(in: .whitespaces).uppercased()
    switch token {
    case "X", "Y", "Z": return 0
    case "½", "1/2": return 0.5
    default:
        if let number = Double(token), token.allSatisfy(\.isNumber) { return number }
        if token.hasPrefix("H"), token.count > 1 { return 0.5 }
        if token.contains("/") {
            return token.split(separator: "/").map { Double($0) ?? 1 }.max() ?? 1
        }
        return 1
    }
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
    var cmcValue: Double { cmc ?? extractCmc(from: manaCost, typeLine: typeLine) }
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