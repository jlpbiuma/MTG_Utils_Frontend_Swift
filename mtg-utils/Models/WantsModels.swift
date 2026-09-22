import Foundation

// MARK: - Wants Models

public struct WantCardCreate: Codable {
    public let cardScryfallId: String
    public let cardName: String
    public let quantity: Int
    public let setCode: String?
    public let collectorNumber: String?
    public let manaCost: String?
    public let typeLine: String?
    public let imageUri: String?

    public init(
        cardScryfallId: String,
        cardName: String,
        quantity: Int = 1,
        setCode: String? = nil,
        collectorNumber: String? = nil,
        manaCost: String? = nil,
        typeLine: String? = nil,
        imageUri: String? = nil
    ) {
        self.cardScryfallId = cardScryfallId
        self.cardName = cardName
        self.quantity = quantity
        self.setCode = setCode
        self.collectorNumber = collectorNumber
        self.manaCost = manaCost
        self.typeLine = typeLine
        self.imageUri = imageUri
    }
}

public struct WantCardUpdate: Codable {
    public let quantity: Int
    public let setCode: String?

    public init(quantity: Int, setCode: String? = nil) {
        self.quantity = quantity
        self.setCode = setCode
    }
}

public struct WantCardResponse: Codable, Identifiable, Hashable {
    public let id: String
    public let userId: String
    public let cardScryfallId: String
    public let cardName: String
    public let quantity: Int
    public let setCode: String?
    public let collectorNumber: String?
    public let manaCost: String?
    public let typeLine: String?
    public let imageUri: String?
    public let updatedAt: Date
    public let requestedInDecks: [DeckRequirement]
    public let requestedInDecksCount: Int
}

public struct WantStats: Codable {
    public let totalCards: Int
    public let uniqueCards: Int
}

public struct WantGroupSection: Codable, Identifiable, Hashable {
    public let key: String
    public let label: String
    public let order: Int
    public let totalCards: Int
    public let uniqueCards: Int
    public let ownedCards: Int
    public let missingCards: Int
    public let completionPercentage: Double
    public let sectionTotalPrice: Double
    public let sectionMissingPrice: Double
    public let sectionOwnedPrice: Double
    public let currencySymbol: String
    public let cards: [WantCardResponse]

    public var id: String { key }
}

public struct WantQueryResponse: Codable {
    public let query: String
    public let grouped: bool_grouped
    public let provider: String
    public let currencySymbol: String
    public let totalCards: Int
    public let uniqueCards: Int
    public let sections: [WantGroupSection]
    public let cards: [WantCardResponse]

    public typealias bool_grouped = Bool
}
