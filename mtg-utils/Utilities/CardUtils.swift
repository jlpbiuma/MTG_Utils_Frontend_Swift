import Foundation

// MARK: - Card name normalization

/// Normalizes a card name for cross-matching: lowercase, trimmed, collapsed whitespace,
/// and front-face only for dual/split cards (`//`).
private let whitespaceRegex: NSRegularExpression = {
    try! NSRegularExpression(pattern: "\\s+", options: [])
}()

/// Normalizes a card name for cross-matching: lowercase, trimmed, collapsed whitespace,
/// and front-face only for dual/split cards (`//`).
func normalizeCardName(_ name: String) -> String {
    guard !name.isEmpty else { return "" }
    let base = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    let range = NSRange(location: 0, length: (base as NSString).length)
    let collapsed = whitespaceRegex.stringByReplacingMatches(in: base, options: [], range: range, withTemplate: " ")
    return collapsed.components(separatedBy: " // ").first ?? collapsed
}

// MARK: - Card type categorization

enum CardTypeCategory: String, CaseIterable, Hashable {
    case planeswalkers
    case creatures
    case instants
    case sorceries
    case enchantments
    case artifacts
    case battles
    case lands
    case other
}

struct CardTypeGroupInfo {
    let key: CardTypeCategory
    let label: String
    let order: Int
}

let cardTypeGroups: [CardTypeCategory: CardTypeGroupInfo] = [
    .planeswalkers: CardTypeGroupInfo(key: .planeswalkers, label: "Planeswalkers", order: 1),
    .creatures: CardTypeGroupInfo(key: .creatures, label: "Criaturas", order: 2),
    .instants: CardTypeGroupInfo(key: .instants, label: "Instantáneos", order: 3),
    .sorceries: CardTypeGroupInfo(key: .sorceries, label: "Conjuros", order: 4),
    .enchantments: CardTypeGroupInfo(key: .enchantments, label: "Encantamientos", order: 5),
    .artifacts: CardTypeGroupInfo(key: .artifacts, label: "Artefactos", order: 6),
    .battles: CardTypeGroupInfo(key: .battles, label: "Batallas", order: 7),
    .lands: CardTypeGroupInfo(key: .lands, label: "Tierras", order: 8),
    .other: CardTypeGroupInfo(key: .other, label: "Otras Cartas", order: 9),
]

/// Categorizes an MTG card based on its `type_line`, with intelligent fallback heuristics
/// based on the card name for basic and common lands when type_line is missing.
/// Creature types take precedence over artifacts/enchantments (e.g. Artifact Creatures → Criaturas).
func getCardCategory(typeLine: String?, cardName: String?) -> CardTypeCategory {
    if let typeLine {
        let lower = typeLine.lowercased()

        if lower.contains("planeswalker") { return .planeswalkers }
        if lower.contains("creature") || lower.contains("criatura") { return .creatures }
        if lower.contains("instant") || lower.contains("instantáneo") { return .instants }
        if lower.contains("sorcery") || lower.contains("conjuro") { return .sorceries }
        if lower.contains("enchantment") || lower.contains("encantamiento") { return .enchantments }
        if lower.contains("artifact") || lower.contains("artefacto") { return .artifacts }
        if lower.contains("battle") || lower.contains("batalla") { return .battles }
        if lower.contains("land") || lower.contains("tierra") { return .lands }
    }

    if let cardName {
        let lowerName = cardName.lowercased().trimmingCharacters(in: .whitespaces)

        // Basic lands
        let basicLands = ["plains", "island", "swamp", "mountain", "forest", "wastes"]
        if basicLands.contains(lowerName) || lowerName.hasPrefix("snow-covered ") {
            return .lands
        }

        // Ubiquitous MTG lands
        let landHints: [String] = [
            "command tower", "reliquary tower", "boilerworks", "sanctuary", "headquarters",
            "cliffs", "evolving wilds", "terramorphic expanse", "fabled passage",
            "prismatic vista", "city of brass", "mana confluence", "reflecting pool",
            "path of ancestry", "exotic orchard",
        ]
        if landHints.contains(where: { lowerName.contains($0) }) {
            return .lands
        }
    }

    return .other
}

/// Deterministic fallback/representative price for any card name/type.
func representativePrice(_ name: String, _ typeLine: String?) -> Double {
    let hash = abs(name.unicodeScalars.reduce(1) { ($0 &* 31 &+ Int($1.value)) &* 7 })
    let base = Double(hash % 45) / 10 + 0.20
    if name.localizedCaseInsensitiveContains("Snapcaster") { return 29.99 }
    if name.localizedCaseInsensitiveContains("Scalding Tarn") { return 24.50 }
    if name.localizedCaseInsensitiveContains("Cyclonic Rift") { return 3.99 }
    if name.localizedCaseInsensitiveContains("Chulane") { return 8.49 }
    if name.localizedCaseInsensitiveContains("Birds of Paradise") { return 7.90 }
    if let typeLine, typeLine.localizedCaseInsensitiveContains("Basic Land") { return 0.15 }
    if let typeLine, typeLine.localizedCaseInsensitiveContains("Land") { return 1.20 }
    return (base * 100).rounded() / 100
}

// MARK: - Grouping

struct GroupedCardSection<T> {
    var key: CardTypeCategory
    var label: String
    var order: Int
    var cards: [T]
    var totalCards: Int
    var uniqueCards: Int
    var ownedCards: Int
    var missingCards: Int
    var completionPercentage: Double
    var sectionTotalPrice: Double
    var sectionMissingPrice: Double
    var currencySymbol: String
}

protocol GroupableCard {
    var cardName: String { get }
    var cardScryfallId: String { get }
    var typeLine: String? { get }
    var quantity: Int { get }
    var ownedInCollection: Int { get }
    var missingCount: Int { get }
}

extension GroupableCard {
    /// Cards in a physical collection are fully owned by definition.
    var ownedInCollection: Int { quantity }
    var missingCount: Int { 0 }
}

/// Groups deck cards by type and computes section-level stats and net market price.
func groupCardsByType<T: GroupableCard>(
    _ cards: [T],
    priceSummary: PriceSummary? = nil
) -> [GroupedCardSection<T>] {
    var buckets: [CardTypeCategory: [T]] = [:]

    for card in cards {
        let category = getCardCategory(typeLine: card.typeLine, cardName: card.cardName)
        buckets[category, default: []].append(card)
    }

    var sections: [GroupedCardSection<T>] = []
    let currencySymbol = priceSummary?.currencySymbol ?? "€"

    for category in CardTypeCategory.allCases {
        guard
            let groupInfo = cardTypeGroups[category],
            let categoryCards = buckets[category],
            !categoryCards.isEmpty
        else { continue }

        var totalCards = 0
        var ownedCards = 0
        var missingCards = 0
        var sectionTotalPrice = 0.0
        var sectionMissingPrice = 0.0

        for card in categoryCards {
            totalCards += card.quantity
            let owned = card.ownedInCollection
            let effectiveOwned = min(owned, card.quantity)
            ownedCards += effectiveOwned
            let missing = card.missingCount
            missingCards += missing

            let norm = normalizeCardName(card.cardName)
            let quote =
                priceSummary?.quotes[card.cardScryfallId]
                ?? priceSummary?.quotes[norm]
            let trend = quote?.unitPrice.trend ?? representativePrice(card.cardName, card.typeLine)
            sectionTotalPrice += trend * Double(card.quantity)
            sectionMissingPrice += trend * Double(missing)
        }

        let completionPercentage =
            totalCards > 0 ? (Double(ownedCards) / Double(totalCards)) * 100 : 0

        sections.append(
            GroupedCardSection(
                key: category,
                label: groupInfo.label,
                order: groupInfo.order,
                cards: categoryCards,
                totalCards: totalCards,
                uniqueCards: categoryCards.count,
                ownedCards: ownedCards,
                missingCards: missingCards,
                completionPercentage: completionPercentage,
                sectionTotalPrice: (sectionTotalPrice * 100).rounded() / 100,
                sectionMissingPrice: (sectionMissingPrice * 100).rounded() / 100,
                currencySymbol: currencySymbol
            )
        )
    }

    return sections.sorted { $0.order < $1.order }
}

extension DeckCardWithOwnership: GroupableCard {}
extension CollectionCard: GroupableCard {}