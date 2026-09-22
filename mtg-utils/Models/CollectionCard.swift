import Foundation

/// Mirrors the `user_collections` table.
struct CollectionCard: Identifiable, Hashable {
    var id: String
    var userId: String
    var cardScryfallId: String
    var cardName: String
    var quantity: Int
    var setCode: String?
    var collectorNumber: String?
    var manaCost: String?
    var typeLine: String?
    var imageUri: String?
    var isFoil: Bool
    var requestedInDecks: [DeckRequirement]
    var requestedInDecksCount: Int

    init(
        id: String = UUID().uuidString,
        userId: String = "",
        cardScryfallId: String,
        cardName: String,
        quantity: Int = 1,
        setCode: String? = nil,
        collectorNumber: String? = nil,
        manaCost: String? = nil,
        typeLine: String? = nil,
        imageUri: String? = nil,
        isFoil: Bool = false,
        requestedInDecks: [DeckRequirement] = [],
        requestedInDecksCount: Int = 0
    ) {
        self.id = id
        self.userId = userId
        self.cardScryfallId = cardScryfallId
        self.cardName = cardName
        self.quantity = quantity
        self.setCode = setCode
        self.collectorNumber = collectorNumber
        self.manaCost = manaCost
        self.typeLine = typeLine
        self.imageUri = imageUri
        self.isFoil = isFoil
        self.requestedInDecks = requestedInDecks
        self.requestedInDecksCount = requestedInDecksCount
    }

    var isPending: Bool { cardScryfallId.hasPrefix("pending:") }
}

struct CollectionStats: Hashable {
    var uniqueCards: Int
    var totalCards: Int
}

struct CollectionGroupSection: Codable, Identifiable, Hashable {
    let key: String
    let label: String
    let order: Int
    let totalCards: Int
    let uniqueCards: Int
    let ownedCards: Int
    let missingCards: Int
    let completionPercentage: Double
    let sectionTotalPrice: Double
    let sectionMissingPrice: Double
    let sectionOwnedPrice: Double
    let currencySymbol: String
    let cards: [BackendCollectionCard]

    var id: String { key }
}

struct CollectionQueryResponse: Codable {
    let query: String
    let grouped: Bool
    let provider: String
    let currencySymbol: String
    let totalCards: Int
    let uniqueCards: Int
    let sections: [CollectionGroupSection]
    let cards: [BackendCollectionCard]
}