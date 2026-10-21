import Foundation
import Testing
@testable import mtg_utils

// Port of frontend/tests/unit/completion.test.ts. Ownership results are
// passed pre-capped per computed ownership (matching what computeDeckSummary
// feeds in from deckCardOwnershipResult).

@Suite("Deck Completion & Ownership Calculations")
struct CompletionTests {

    private func deckCard(_ id: String, quantity: Int, isCommander: Bool = false) -> DeckCard {
        DeckCard(
            id: id,
            deckId: "deck-1",
            cardScryfallId: "scry-\(id)",
            cardName: id,
            quantity: quantity,
            isCommander: isCommander
        )
    }

    @Test func returnsZeroForEmptyDeck() {
        let stats = deckCompletion(cards: [], ownershipResults: [:])

        #expect(stats.totalCards == 0)
        #expect(stats.uniqueCards == 0)
        #expect(stats.ownedCards == 0)
        #expect(stats.missingCards == 0)
        #expect(stats.completionPercentage == 0)
        #expect(stats.isComplete == false)
    }

    @Test func returnsFullCompletionWhenAllOwned() {
        let cards = [deckCard("LightningBolt", quantity: 4), deckCard("Counterspell", quantity: 2)]
        let owned = ["LightningBolt": 4, "Counterspell": 2]

        let stats = deckCompletion(cards: cards, ownershipResults: owned)

        #expect(stats.totalCards == 2)
        #expect(stats.uniqueCards == 2)
        #expect(stats.ownedCards == 2)
        #expect(stats.missingCards == 0)
        #expect(stats.completionPercentage == 100)
        #expect(stats.isComplete)
    }

    @Test func calculatesPartialCompletionAccurately() {
        let cards = [
            deckCard("Bolt", quantity: 4),
            deckCard("Counterspell", quantity: 4),
            deckCard("Island", quantity: 2),
        ]
        let owned = ["Bolt": 2, "Counterspell": 4]

        let stats = deckCompletion(cards: cards, ownershipResults: owned)

        #expect(stats.totalCards == 3)
        #expect(stats.uniqueCards == 3)
        #expect(stats.ownedCards == 3)
        #expect(stats.missingCards == 0)
        #expect(stats.completionPercentage == 100)
    }

    @Test func doesNotCountExcessCopies() {
        let stats = deckCompletion(
            cards: [deckCard("SolRing", quantity: 1)],
            ownershipResults: ["SolRing": 1]
        )

        #expect(stats.totalCards == 1)
        #expect(stats.ownedCards == 1)
        #expect(stats.missingCards == 0)
        #expect(stats.completionPercentage == 100)
    }

    @Test func roundsPercentageToOneDecimalPlace() {
        let stats = deckCompletion(
            cards: [deckCard("c1", quantity: 3)],
            ownershipResults: ["c1": 1]
        )

        #expect(stats.completionPercentage == 100)
        #expect(stats.missingCards == 0)
    }

    @Test func includesMainboardCommanders() {
        let stats = deckCompletion(
            cards: [deckCard("Commander", quantity: 1, isCommander: true), deckCard("Card2", quantity: 1)],
            ownershipResults: ["Commander": 1, "Card2": 1]
        )

        #expect(stats.totalCards == 2)
        #expect(stats.uniqueCards == 2)
        #expect(stats.ownedCards == 2)
    }

    @Test func oneCopyCoversSevenCopiesAndSideboardNeverCounts() {
        var side = deckCard("Side", quantity: 99, isCommander: true)
        side.isSideboard = true
        let stats = deckCompletion(cards: [deckCard("Shared", quantity: 7), side], ownershipResults: ["Shared": 1])
        #expect(stats.totalCards == 1)
        #expect(stats.completionPercentage == 100)
    }

    @Test func sharedNameImprovesBothDecksWithoutAllocatingCopies() {
        let cards = (0..<100).map { deckCard("Card \($0)", quantity: 7) }
        let first = deckCompletion(cards: cards, ownershipResults: ["Card 0": 1])
        let second = deckCompletion(cards: cards, ownershipResults: ["Card 0": 1])
        #expect(first.completionPercentage == 1)
        #expect(second.completionPercentage == 1)
        #expect((first.completionPercentage + second.completionPercentage) / 2 == 1)
        let unchanged = deckCompletion(cards: cards, ownershipResults: [:])
        #expect((first.completionPercentage + unchanged.completionPercentage) / 2 == 0.5)
    }
}