import Foundation
import Observation

// MARK: - Collection view model

@Observable
@MainActor
final class CollectionViewModel {
    private(set) var cards: [CollectionCard] = []
    private(set) var stats: CollectionStats = CollectionStats(uniqueCards: 0, totalCards: 0)
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var sortField: SortField = .category
    var sortDirection: SortDirection = .ascending
    var searchText = ""

    private let store: AppDataStoring

    init(store: AppDataStoring) {
        self.store = store
    }

    var filtered: [CollectionCard] {
        var result = cards
        if !searchText.isEmpty {
            result = result.filter {
                $0.cardName.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var sorted: [CollectionCard] {
        sortCards(filtered, by: sortField, direction: sortDirection)
    }

    var groups: [GroupedCardSection<CollectionCard>] {
        groupCardsByType(sorted)
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            cards = try await store.allCollection()
            stats = CollectionStats(
                uniqueCards: cards.count,
                totalCards: cards.reduce(0) { $0 + $1.quantity }
            )
        } catch {
            errorMessage = "No se pudo cargar la colección: \(error.localizedDescription)"
        }
    }

    func addCards(_ newCards: [CollectionCard]) async throws {
        var byKey: [String: CollectionCard] = [:]
        for card in cards {
            byKey["\(normalizeCardName(card.cardName))|\(card.setCode ?? "")"] = card
        }
        for card in newCards {
            let key = "\(normalizeCardName(card.cardName))|\(card.setCode ?? "")"
            if var existing = byKey[key] {
                existing.quantity += card.quantity
                byKey[key] = existing
            } else {
                byKey[key] = card
            }
        }
        cards = Array(byKey.values)
        try await store.saveCollection(cards)
        stats = CollectionStats(
            uniqueCards: cards.count,
            totalCards: cards.reduce(0) { $0 + $1.quantity }
        )
    }
}