import Foundation

// MARK: - Data repository protocols

/// Persistence abstraction. Production will back this with Supabase; the demo
/// uses an in-memory store seeded from `SeedData`.
protocol AppDataStoring {
    func allDecks() async throws -> [Deck]
    func allDeckSummaries() async throws -> [DeckSummary]
    func deckDetail(id: String) async throws -> DeckDetail?
    func saveDecks(_ decks: [Deck]) async throws
    func allCollection() async throws -> [CollectionCard]
    func saveCollection(_ cards: [CollectionCard]) async throws

    // MARK: - Granular deck operations
    func createDeck(_ deck: Deck) async throws -> Deck
    func updateDeck(_ deck: Deck) async throws
    func deleteDeck(id: String) async throws
    func addDeckCard(deckId: String, card: DeckCard) async throws
    func updateDeckCard(cardId: String, quantity: Int, setCode: String?) async throws
    func removeDeckCard(cardId: String) async throws

    // MARK: - Granular collection operations
    func addCollectionCard(_ card: CollectionCard) async throws
    func updateCollectionCard(id: String, quantity: Int, setCode: String?) async throws
    func removeCollectionCard(id: String) async throws
}

extension AppDataStoring {
    func createDeck(_ deck: Deck) async throws -> Deck {
        var all = try await allDecks()
        all.append(deck)
        try await saveDecks(all)
        return deck
    }

    func updateDeck(_ deck: Deck) async throws {
        var all = try await allDecks()
        if let idx = all.firstIndex(where: { $0.id == deck.id }) {
            all[idx] = deck
        } else {
            all.append(deck)
        }
        try await saveDecks(all)
    }

    func deleteDeck(id: String) async throws {
        var all = try await allDecks()
        all.removeAll { $0.id == id }
        try await saveDecks(all)
    }

    func addDeckCard(deckId: String, card: DeckCard) async throws {
        var all = try await allDecks()
        guard let deckIndex = all.firstIndex(where: { $0.id == deckId }) else { return }
        var target = all[deckIndex]
        if let existing = target.cards.firstIndex(where: {
            $0.cardScryfallId == card.cardScryfallId && $0.isSideboard == card.isSideboard
        }) {
            target.cards[existing].quantity += card.quantity
        } else {
            target.cards.append(card)
        }
        all[deckIndex] = target
        try await saveDecks(all)
    }

    func updateDeckCard(cardId: String, quantity: Int, setCode: String?) async throws {
        var all = try await allDecks()
        var modified = false
        for i in 0..<all.count {
            if let cardIndex = all[i].cards.firstIndex(where: { $0.id == cardId }) {
                all[i].cards[cardIndex].quantity = quantity
                if let setCode {
                    all[i].cards[cardIndex].setCode = setCode
                }
                modified = true
                break
            }
        }
        if modified {
            try await saveDecks(all)
        }
    }

    func removeDeckCard(cardId: String) async throws {
        var all = try await allDecks()
        var modified = false
        for i in 0..<all.count {
            if all[i].cards.contains(where: { $0.id == cardId }) {
                all[i].cards.removeAll { $0.id == cardId }
                modified = true
                break
            }
        }
        if modified {
            try await saveDecks(all)
        }
    }

    func addCollectionCard(_ card: CollectionCard) async throws {
        var all = try await allCollection()
        all.append(card)
        try await saveCollection(all)
    }

    func updateCollectionCard(id: String, quantity: Int, setCode: String?) async throws {
        var all = try await allCollection()
        if let idx = all.firstIndex(where: { $0.id == id }) {
            all[idx].quantity = quantity
            if let setCode {
                all[idx].setCode = setCode
            }
            try await saveCollection(all)
        }
    }

    func removeCollectionCard(id: String) async throws {
        var all = try await allCollection()
        all.removeAll { $0.id == id }
        try await saveCollection(all)
    }
}