import Foundation

// MARK: - Deck

/// Mirrors the `decks` table from the Prisma schema.
struct Deck: Identifiable, Hashable {
    var id: String
    var userId: String
    var name: String
    var format: String
    var description: String?
    var commander: String?
    var commanderScryfallId: String?
    var commanderImageUri: String?
    var createdAt: Date
    var updatedAt: Date
    var cards: [DeckCard]

    init(
        id: String = UUID().uuidString,
        userId: String = "",
        name: String,
        format: String = "Commander",
        description: String? = nil,
        commander: String? = nil,
        commanderScryfallId: String? = nil,
        commanderImageUri: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        cards: [DeckCard] = []
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.format = format
        self.description = description
        self.commander = commander
        self.commanderScryfallId = commanderScryfallId
        self.commanderImageUri = commanderImageUri
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.cards = cards
    }
}

// MARK: - DeckCard

/// Mirrors the `deck_cards` table.
struct DeckCard: Identifiable, Hashable {
    var id: String
    var deckId: String
    var cardScryfallId: String
    var cardName: String
    var quantity: Int
    var assignedQuantity: Int
    var isSideboard: Bool
    var isCommander: Bool
    var manaCost: String?
    var typeLine: String?
    var imageUri: String?

    init(
        id: String = UUID().uuidString,
        deckId: String = "",
        cardScryfallId: String,
        cardName: String,
        quantity: Int = 1,
        assignedQuantity: Int = 0,
        isSideboard: Bool = false,
        isCommander: Bool = false,
        manaCost: String? = nil,
        typeLine: String? = nil,
        imageUri: String? = nil
    ) {
        self.id = id
        self.deckId = deckId
        self.cardScryfallId = cardScryfallId
        self.cardName = cardName
        self.quantity = quantity
        self.assignedQuantity = assignedQuantity
        self.isSideboard = isSideboard
        self.isCommander = isCommander
        self.manaCost = manaCost
        self.typeLine = typeLine
        self.imageUri = imageUri
    }

    var isPending: Bool { cardScryfallId.hasPrefix("pending:") }
}

// MARK: - DeckSummary

/// Deck with completion statistics (`DeckWithCompletion` in the web app).
struct DeckSummary: Identifiable, Hashable {
    var id: String
    var userId: String
    var name: String
    var format: String
    var description: String?
    var commander: String?
    var commanderScryfallId: String?
    var commanderImageUri: String?
    var createdAt: Date
    var updatedAt: Date
    var totalCards: Int
    var uniqueCards: Int
    var ownedCards: Int
    var missingCardsCount: Int
    var completionPercentage: Double

    var isComplete: Bool { totalCards > 0 && missingCardsCount == 0 }

    // Convenience for previews / lightweight construction.
    init(
        id: String = UUID().uuidString,
        userId: String = "",
        name: String,
        format: String = "Commander",
        description: String? = nil,
        commander: String? = nil,
        commanderScryfallId: String? = nil,
        commanderImageUri: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        totalCards: Int = 0,
        uniqueCards: Int = 0,
        ownedCards: Int = 0,
        missingCardsCount: Int = 0,
        completionPercentage: Double = 0
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.format = format
        self.description = description
        self.commander = commander
        self.commanderScryfallId = commanderScryfallId
        self.commanderImageUri = commanderImageUri
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.totalCards = totalCards
        self.uniqueCards = uniqueCards
        self.ownedCards = ownedCards
        self.missingCardsCount = missingCardsCount
        self.completionPercentage = completionPercentage
    }
}

// MARK: - Ownership & assignment helpers

struct OtherDeckAssignment: Identifiable, Hashable {
    var deckId: String
    var deckName: String
    var quantity: Int
    var id: String { deckId }
}

/// A deck card with per-card ownership/missing breakdown and cross-deck assignment info.
struct DeckCardWithOwnership: Identifiable, Hashable {
    var id: String
    var deckId: String
    var cardScryfallId: String
    var cardName: String
    var quantity: Int
    var assignedQuantity: Int
    var isSideboard: Bool
    var isCommander: Bool
    var manaCost: String?
    var typeLine: String?
    var imageUri: String?
    var ownedInCollection: Int
    var availableToAssign: Int
    var assignedInOtherDecks: [OtherDeckAssignment]
    var missingCount: Int

    var isComplete: Bool { ownedInCollection >= quantity }
}

/// Deck detail with aggregated stats and enriched cards.
struct DeckDetail: Identifiable, Hashable {
    var id: String
    var userId: String
    var name: String
    var format: String
    var description: String?
    var commander: String?
    var commanderScryfallId: String?
    var commanderImageUri: String?
    var createdAt: Date
    var updatedAt: Date
    var totalCards: Int
    var uniqueCards: Int
    var ownedCards: Int
    var missingCardsCount: Int
    var completionPercentage: Double
    var cards: [DeckCardWithOwnership]

    var isComplete: Bool { totalCards > 0 && missingCardsCount == 0 }

    var mainboardCards: [DeckCardWithOwnership] { cards.filter { !$0.isSideboard } }
    var sideboardCards: [DeckCardWithOwnership] { cards.filter { $0.isSideboard } }

    var mainboardCount: Int { mainboardCards.reduce(0) { $0 + $1.quantity } }
    var sideboardCount: Int { sideboardCards.reduce(0) { $0 + $1.quantity } }
}