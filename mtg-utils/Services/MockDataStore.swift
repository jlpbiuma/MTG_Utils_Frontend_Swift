import Foundation

/// In-memory store for the demo, seeded with sample decks and a partial collection.
/// Acts as the `AppDataStoring` persistence until Supabase is wired in Phase 2.
@MainActor
final class MockDataStore: AppDataStoring {
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