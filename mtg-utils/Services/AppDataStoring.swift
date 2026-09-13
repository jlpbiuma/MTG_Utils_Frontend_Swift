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
}