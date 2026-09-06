import Foundation
import Observation

// MARK: - Decks list view model

@Observable
@MainActor
final class DecksListViewModel {
    private(set) var decks: [DeckSummary] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let store: AppDataStoring
    private let userId: String

    init(store: AppDataStoring, userId: String) {
        self.store = store
        self.userId = userId
    }

    var emptyStateTitle: String { "Aún no tienes mazos" }
    var emptyStateMessage: String { "Crea tu primer mazo para ver su porcentaje de completitud." }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let rawDecks = try await store.allDecks()
            let collection = try await store.allCollection()
            let ownershipIndex = buildOwnershipIndex(collection)
            let otherAssignments = buildOtherDeckAssignments(rawDecks)
            let summaries: [DeckSummary] = rawDecks.compactMap { deck in
                var ownedTotal = 0
                var unique = 0
                var total = 0
                for card in deck.cards {
                    if card.isCommander { continue }
                    unique += 1
                    total += card.quantity
                    ownedTotal += min(
                        ownershipIndex.ownedCount(scryfallId: card.cardScryfallId, name: card.cardName),
                        card.quantity
                    )
                }
                let missing = max(0, total - ownedTotal)
                let percentage = total > 0 ? (Double(ownedTotal) / Double(total)) * 100 : 0

                return DeckSummary(
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
                    totalCards: total,
                    uniqueCards: unique,
                    ownedCards: ownedTotal,
                    missingCardsCount: missing,
                    completionPercentage: percentage
                )
            }
            decks = summaries
        } catch {
            errorMessage = "No se pudieron cargar los mazos: \(error.localizedDescription)"
        }
    }

    func createDeck(deck: Deck) async throws {
        var all = try await store.allDecks()
        all.append(deck)
        try await store.saveDecks(all)
    }

    func deleteDeck(id: String) async throws {
        var all = try await store.allDecks()
        all.removeAll { $0.id == id }
        try await store.saveDecks(all)
    }

    func updateDeck(_ updated: Deck) async throws {
        var all = try await store.allDecks()
        if let idx = all.firstIndex(where: { $0.id == updated.id }) {
            all[idx] = updated
        }
        try await store.saveDecks(all)
    }
}