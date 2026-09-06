import Foundation
import Observation

// MARK: - Deck detail view model

@Observable
@MainActor
final class DeckDetailViewModel {
    private(set) var detail: DeckDetail?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    let deckId: String

    private let store: AppDataStoring
    private let deck: Deck

    // Mark: sorting + filters

    var sortField: SortField = .category
    var sortDirection: SortDirection = .ascending
    var filterMissingOnly = false

    var canTransferMissing = false

    init(deck: Deck, store: AppDataStoring) {
        self.deck = deck
        self.deckId = deck.id
        self.store = store
    }

    var commander: DeckCardWithOwnership? {
        detail?.cards.first { $0.isCommander }
    }

    var mainboardSorted: [DeckCardWithOwnership] {
        guard let detail else { return [] }
        var cards = detail.mainboardCards
        if filterMissingOnly {
            cards = cards.filter { $0.missingCount > 0 }
        }
        return sortCards(cards, by: sortField, direction: sortDirection)
    }

    var sideboardSorted: [DeckCardWithOwnership] {
        guard let detail else { return [] }
        var cards = detail.sideboardCards
        if filterMissingOnly {
            cards = cards.filter { $0.missingCount > 0 }
        }
        return sortCards(cards, by: sortField, direction: sortDirection)
    }

    var groupsMainboard: [GroupedCardSection<DeckCardWithOwnership>] {
        groupCardsByType(mainboardSorted)
    }

    var groupsFull: [GroupedCardSection<DeckCardWithOwnership>] {
        guard let detail else { return [] }
        return groupCardsByType(detail.cards)
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let collection = try await store.allCollection()
            let allDecks = try await store.allDecks()
            let ownershipIndex = buildOwnershipIndex(collection)
            let otherAssignments = buildOtherDeckAssignments(allDecks)

            var ownedByCardId: [String: Int] = [:]

            let detailCards: [DeckCardWithOwnership] = deck.cards.map { card in
                let result = deckCardOwnershipResult(
                    card: card,
                    ownershipIndex: ownershipIndex,
                    otherDecksAssignments: otherAssignments
                )
                ownedByCardId[card.id] = result.ownedInCollection
                return DeckCardWithOwnership(
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
                    ownedInCollection: result.ownedInCollection,
                    availableToAssign: result.availableToAssign,
                    assignedInOtherDecks: result.assignedInOtherDecks,
                    missingCount: result.missingCount
                )
            }

            var total = 0
            var ownedTotal = 0
            var unique = 0
            var missingTotal = 0
            for card in detailCards where !card.isCommander {
                total += card.quantity
                ownedTotal += card.ownedInCollection
                missingTotal += card.missingCount
                unique += 1
            }

            let percentage = total > 0 ? (Double(ownedTotal) / Double(total)) * 100 : 0

            detail = DeckDetail(
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
                missingCardsCount: missingTotal,
                completionPercentage: percentage,
                cards: detailCards
            )
            canTransferMissing = missingTotal > 0
        } catch {
            errorMessage = "No se pudo cargar el mazo: \(error.localizedDescription)"
        }
    }

    /// `Tengo las faltantes`: moves missing copies from collection into the deck as owned.
    func transferMissingToCollection() async throws {
        guard let detail else { return }
        var missingByCard: [[String: Any]] = []
        for card in detail.cards where !card.isCommander && card.missingCount > 0 {
            missingByCard.append(["normalizedName": normalizeCardName(card.cardName), "cardName": card.cardName, "missing": card.missingCount])
        }

        var collection = try await store.allCollection()
        for entry in missingByCard {
            guard
                let normalized = entry["normalizedName"] as? String,
                let cardName = entry["cardName"] as? String,
                let missing = entry["missing"] as? Int
            else { continue }

            if let idx = collection.firstIndex(where: { normalizeCardName($0.cardName) == normalized }) {
                collection[idx].quantity += missing
            } else {
                collection.append(
                    CollectionCard(
                        cardScryfallId: "pending:\(normalized)",
                        cardName: cardName,
                        quantity: missing
                    )
                )
            }
        }
        try await store.saveCollection(collection)
        await load()
    }
}