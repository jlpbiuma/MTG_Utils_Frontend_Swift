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
        imageUri: String? = nil
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
    }

    var isPending: Bool { cardScryfallId.hasPrefix("pending:") }
}

struct CollectionStats: Hashable {
    var uniqueCards: Int
    var totalCards: Int
}