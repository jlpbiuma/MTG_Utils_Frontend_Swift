import Foundation

// MARK: - Priorities Models

public struct DeckReassignOption: Codable, Identifiable, Hashable {
    public let sourceDeckId: String
    public let sourceDeckName: String
    public let sourceDeckCompletion: Double
    public let assignedQuantity: Int
    public let targetDeckId: String
    public let targetDeckName: String
    public let targetDeckCompletion: Double
    public let missingQuantity: Int
    public let targetDeckCardId: String

    public var id: String { "\(sourceDeckId)-\(targetDeckId)-\(targetDeckCardId)" }
}

public struct PriorityDeckInfo: Codable, Identifiable, Hashable {
    public let deckId: String
    public let deckName: String
    public let completionPercentage: Double
    public let colors: [String]
    public let requestedQuantity: Int
    public let assignedQuantity: Int
    public let missingQuantity: Int
    public let deckCardId: String
    public let potentialGain: Double

    public var id: String { deckCardId }
}

public struct PriorityItem: Codable, Identifiable, Hashable {
    public let cardName: str_id
    public let cardScryfallId: String
    public let imageUri: String?
    public let manaCost: String?
    public let typeLine: String?
    public let cardType: String
    public let numDecks: Int
    public let decks: [PriorityDeckInfo]
    public let copiesOwned: Int
    public let copiesNeeded: Int
    public let deficit: int_deficit
    public let price: Double
    public let totalDeficitCost: Double
    public let isReassignable: Bool
    public let reassignOptions: [DeckReassignOption]
    public let maxDeckCompletion: Double
    public let maxPotentialGain: Double
    public let avgPotentialGain: Double
    public let netCompletionGain: Double
    public let sumPointsGain: Double

    public var id: String { cardScryfallId.isEmpty ? cardName : cardScryfallId }

    public typealias str_id = String
    public typealias int_deficit = Int
}

public struct PrioritiesResponse: Codable {
    public let totalUniqueCards: Int
    public let totalDeficitCopies: Int
    public let totalDeficitCost: Double
    public let currencySymbol: String
    public let provider: String
    public let page: Int
    public let limit: Int
    public let totalItems: Int
    public let hasMore: Bool
    public let items: [PriorityItem]
}

public struct DeckReassignRequest: Codable {
    public let sourceDeckId: String
    public let targetDeckId: String
    public let cardScryfallId: String
    public let quantity: Int

    public init(sourceDeckId: String, targetDeckId: String, cardScryfallId: String, quantity: Int = 1) {
        self.sourceDeckId = sourceDeckId
        self.targetDeckId = targetDeckId
        self.cardScryfallId = cardScryfallId
        self.quantity = quantity
    }
}
