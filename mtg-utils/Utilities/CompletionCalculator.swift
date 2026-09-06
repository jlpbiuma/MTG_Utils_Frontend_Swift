import Foundation

// MARK: - Completion calculator

/// A normalized collection ownership lookup for cross-matching.
struct OwnershipIndex {
    let ownedByScryfallId: [String: Int]
    let ownedByNormalizedName: [String: Int]

    /// Total owned copies of a card, by scryfall id first, then normalized name.
    func ownedCount(scryfallId: String, name: String) -> Int {
        let byId = ownedByScryfallId[scryfallId] ?? 0
        if byId > 0 { return byId }
        return ownedByNormalizedName[normalizeCardName(name)] ?? 0
    }
}

struct DeckCardOwnershipResult: Hashable {
    var ownedInCollection: Int
    var missingCount: Int
    var availableToAssign: Int
    var assignedInOtherDecks: [OtherDeckAssignment]

    var isComplete: Bool { ownedInCollection >= missingCount }
}

/// Builds an ownership index from a user's collection.
func buildOwnershipIndex(_ collection: [CollectionCard]) -> OwnershipIndex {
    var byId: [String: Int] = [:]
    var byName: [String: Int] = [:]

    for card in collection {
        let normalized = normalizeCardName(card.cardName)
        byName[normalized, default: 0] += card.quantity
        if !card.isPending {
            byId[card.cardScryfallId, default: 0] += card.quantity
        }
    }

    return OwnershipIndex(ownedByScryfallId: byId, ownedByNormalizedName: byName)
}

/// Builds a "used elsewhere" map of quantity assigned to other decks, keyed by card name.
func buildOtherDeckAssignments(_ decks: [Deck]) -> [String: [OtherDeckAssignment]] {
    var result: [String: [OtherDeckAssignment]] = [:]
    for deck in decks {
        for card in deck.cards where card.assignedQuantity > 0 {
            let key = normalizeCardName(card.cardName)
            result[key, default: []].append(
                OtherDeckAssignment(deckId: deck.id, deckName: deck.name, quantity: card.assignedQuantity)
            )
        }
    }
    return result
}

/// Builds the ownership annotation (ownedInCollection, missingCount, availableToAssign,
/// assignedInOtherDecks) for a single deck card given collection and other decks.
func deckCardOwnershipResult(
    card: DeckCard,
    ownershipIndex: OwnershipIndex,
    otherDecksAssignments: [String: [OtherDeckAssignment]]
) -> DeckCardOwnershipResult {
    let owned = ownershipIndex.ownedCount(scryfallId: card.cardScryfallId, name: card.cardName)
    let normalized = normalizeCardName(card.cardName)

    var assignedElsewhere = 0
    var assignments: [OtherDeckAssignment] = []
    for assignment in otherDecksAssignments[normalized] ?? [] {
        if assignment.deckId != card.deckId {
            assignedElsewhere += assignment.quantity
            assignments.append(assignment)
        }
    }

    // Fractional allocation: card copies are assigned to this deck token-by-token; by default
    // we count THIS deck's assignedQuantity toward its own need.
    let alreadyAssignedHere = card.assignedQuantity
    let available = max(0, owned - assignedElsewhere - alreadyAssignedHere)

    let amountOwnedForThisDeck = min(owned - assignedElsewhere, card.quantity)
    let realMissing = max(0, card.quantity - amountOwnedForThisDeck)

    // The numeric "missing count" used by the UI = copies needed to complete this deck.
    let missingCountReal = realMissing

    return DeckCardOwnershipResult(
        ownedInCollection: owned,
        missingCount: missingCountReal,
        availableToAssign: available,
        assignedInOtherDecks: assignments
    )
}

struct DeckCompletionStats: Hashable {
    var totalCards: Int
    var uniqueCards: Int
    var ownedCards: Int
    var missingCards: Int

    var completionPercentage: Double {
        totalCards > 0 ? (Double(ownedCards) / Double(totalCards) * 1000).rounded() / 10 : 0
    }

    var isComplete: Bool { totalCards > 0 && missingCards == 0 }
}

/// Computes completion for a list of deck cards given ownership results.
func deckCompletion(
    cards: [DeckCard],
    ownershipResults: [String: Int]
) -> DeckCompletionStats {
    var total = 0
    var owned = 0

    for card in cards {
        if card.isCommander { continue }
        total += card.quantity
        owned += ownershipResults[card.id] ?? 0
    }

    let missing = max(0, total - owned)
    return DeckCompletionStats(
        totalCards: total,
        uniqueCards: cards.filter { !$0.isCommander }.count,
        ownedCards: owned,
        missingCards: missing
    )
}

/// Computes completion directly from a Deck object and its resolved ownership results.
func computeDeckSummary(
    deck: Deck,
    collection: [CollectionCard]
) -> DeckSummary {
    let index = buildOwnershipIndex(collection)
    let otherDecks = buildOtherDeckAssignments([Deck(
        id: deck.id,
        userId: deck.userId,
        name: deck.name,
        format: deck.format,
        cards: []
    )])

    var ownedByCardId: [String: Int] = [:]
    var uniqueCount = 0
    var total = 0
    var ownedTotal = 0

    for card in deck.cards {
        if card.isCommander { continue }
        uniqueCount += 1
        total += card.quantity
        let result = deckCardOwnershipResult(
            card: card,
            ownershipIndex: index,
            otherDecksAssignments: otherDecks
        )
        ownedByCardId[card.id] = min(result.ownedInCollection, card.quantity)
        ownedTotal += min(result.ownedInCollection, card.quantity)
    }

    let missing = max(0, total - ownedTotal)
    let percentage = total > 0 ? (Double(ownedTotal) / Double(total) * 1000).rounded() / 10 : 0

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
        uniqueCards: uniqueCount,
        ownedCards: ownedTotal,
        missingCardsCount: missing,
        completionPercentage: percentage
    )
}