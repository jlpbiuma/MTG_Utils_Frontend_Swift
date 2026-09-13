import Foundation

/// In-memory store for the demo, seeded with sample decks and a partial collection.
/// Acts as the `AppDataStoring` persistence until Supabase is wired in Phase 2.
final class MockDataStore: AppDataStoring, @unchecked Sendable {
    static let demoUserId = "00000000-0000-0000-0000-000000000001"

    private var decks: [Deck]
    private var collection: [CollectionCard]

    init(seed: Bool = true) {
        if seed {
            let seed = SeedData()
            self.decks = seed.decks
            self.collection = seed.collection
        } else {
            self.decks = []
            self.collection = []
        }
    }

    func allDecks() async throws -> [Deck] {
        decks
    }

    func allDeckSummaries() async throws -> [DeckSummary] {
        decks.map { deck in
            DeckSummary(
                id: deck.id,
                userId: deck.userId,
                name: deck.name,
                format: deck.format,
                description: deck.description,
                commander: deck.commander,
                commanderScryfallId: deck.commanderScryfallId,
                commanderImageUri: deck.commanderImageUri,
                createdAt: deck.createdAt,
                updatedAt: deck.updatedAt,
                totalCards: deck.cards.reduce(0) { $0 + $1.quantity },
                uniqueCards: deck.cards.count,
                ownedCards: deck.cards.reduce(0) { $0 + $1.quantity },
                missingCardsCount: 0,
                completionPercentage: 100.0
            )
        }
    }

    func deckDetail(id: String) async throws -> DeckDetail? {
        guard let deck = decks.first(where: { $0.id == id }) else { return nil }
        return DeckDetail(
            id: deck.id,
            userId: deck.userId,
            name: deck.name,
            format: deck.format,
            description: deck.description,
            commander: deck.commander,
            commanderScryfallId: deck.commanderScryfallId,
            commanderImageUri: deck.commanderImageUri,
            createdAt: deck.createdAt,
            updatedAt: deck.updatedAt,
            totalCards: deck.cards.reduce(0) { $0 + $1.quantity },
            uniqueCards: deck.cards.count,
            ownedCards: deck.cards.reduce(0) { $0 + $1.quantity },
            missingCardsCount: 0,
            completionPercentage: 100.0,
            cards: deck.cards.map { card in
                DeckCardWithOwnership(
                    id: card.id,
                    deckId: card.deckId,
                    cardScryfallId: card.cardScryfallId,
                    cardName: card.cardName,
                    quantity: card.quantity,
                    assignedQuantity: card.assignedQuantity,
                    isSideboard: card.isSideboard,
                    isCommander: card.isCommander,
                    manaCost: card.manaCost,
                    typeLine: card.typeLine,
                    imageUri: card.imageUri,
                    setCode: card.setCode,
                    ownedInCollection: card.quantity,
                    availableToAssign: 0,
                    assignedInOtherDecks: [],
                    missingCount: 0
                )
            }
        )
    }

    func saveDecks(_ newDecks: [Deck]) async throws {
        decks = newDecks
    }

    func allCollection() async throws -> [CollectionCard] {
        collection
    }

    func saveCollection(_ newCards: [CollectionCard]) async throws {
        collection = newCards
    }

    func addCollectionCards(_ cards: [CollectionCard]) {
        var byKey: [String: CollectionCard] = [:]
        for card in collection {
            byKey["\(normalizeCardName(card.cardName))|\(card.setCode ?? "")"] = card
        }
        for card in cards {
            let key = "\(normalizeCardName(card.cardName))|\(card.setCode ?? "")"
            if var existing = byKey[key] {
                existing.quantity += card.quantity
                byKey[key] = existing
            } else {
                byKey[key] = card
            }
        }
        collection = Array(byKey.values)
    }
}