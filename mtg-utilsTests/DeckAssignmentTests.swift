import Foundation
import Testing
@testable import mtg_utils

// Port of frontend/tests/unit/deck-assignment.test.ts exercised through
// buildOwnershipIndex + buildOtherDeckAssignments + deckCardOwnershipResult.

@Suite("Cross-Deck Card Assignment Logic")
struct DeckAssignmentTests {

    private func deckCard(
        id: String,
        deckId: String,
        cardName: String,
        scryfallId: String,
        quantity: Int = 1,
        assignedQuantity: Int = 0
    ) -> DeckCard {
        DeckCard(
            id: id,
            deckId: deckId,
            cardScryfallId: scryfallId,
            cardName: cardName,
            quantity: quantity,
            assignedQuantity: assignedQuantity
        )
    }

    @Test func detectsCardAlreadyAssignedToAnotherDeck() {
        let collection = [
            CollectionCard(cardScryfallId: "scry-sol-ring", cardName: "Sol Ring", quantity: 1)
        ]

        let deckA = Deck(
            id: "deck-a",
            name: "Commander Urza",
            cards: [deckCard(id: "card-1", deckId: "deck-a", cardName: "Sol Ring", scryfallId: "scry-sol-ring", assignedQuantity: 1)]
        )
        let deckB = Deck(
            id: "deck-b",
            name: "Commander Atraxa",
            cards: [deckCard(id: "card-2", deckId: "deck-b", cardName: "Sol Ring", scryfallId: "scry-sol-ring", assignedQuantity: 0)]
        )

        let index = buildOwnershipIndex(collection)
        let assignments = buildOtherDeckAssignments([deckA, deckB])
        let result = deckCardOwnershipResult(
            card: deckB.cards[0],
            ownershipIndex: index,
            otherDecksAssignments: assignments
        )

        #expect(result.ownedInCollection == 1)
        #expect(result.availableToAssign == 0) // 1 owned - 1 in Deck A = 0 free!
        #expect(result.assignedInOtherDecks.count == 1)
        #expect(result.assignedInOtherDecks[0].deckName == "Commander Urza")
        #expect(result.assignedInOtherDecks[0].quantity == 1)
        #expect(result.missingCount == 1)
    }

    @Test func allowsAssignmentWhenEnoughFreeCopiesAvailable() {
        let collection = [
            CollectionCard(cardScryfallId: "scry-bolt", cardName: "Lightning Bolt", quantity: 3)
        ]

        let deckA = Deck(
            id: "deck-a",
            name: "Burn Modern",
            cards: [deckCard(id: "card-1", deckId: "deck-a", cardName: "Lightning Bolt", scryfallId: "scry-bolt", quantity: 4, assignedQuantity: 1)]
        )
        let deckB = Deck(
            id: "deck-b",
            name: "Pauper Delver",
            cards: [deckCard(id: "card-2", deckId: "deck-b", cardName: "Lightning Bolt", scryfallId: "scry-bolt", quantity: 2, assignedQuantity: 0)]
        )

        let index = buildOwnershipIndex(collection)
        let assignments = buildOtherDeckAssignments([deckA, deckB])
        let result = deckCardOwnershipResult(
            card: deckB.cards[0],
            ownershipIndex: index,
            otherDecksAssignments: assignments
        )

        #expect(result.availableToAssign == 2) // 3 owned - 1 in Deck A = 2 available!
        #expect(result.assignedInOtherDecks.count == 1)
        #expect(result.assignedInOtherDecks[0].deckName == "Burn Modern")
        #expect(result.assignedInOtherDecks[0].quantity == 1)
    }

    @Test func recalculatesAfterReleasingACopy() {
        let collection = [
            CollectionCard(cardScryfallId: "scry-rhystic", cardName: "Rhystic Study", quantity: 1)
        ]

        let deckACard = deckCard(id: "card-1", deckId: "deck-a", cardName: "Rhystic Study", scryfallId: "scry-rhystic", assignedQuantity: 1)
        let deckBCard = deckCard(id: "card-2", deckId: "deck-b", cardName: "Rhystic Study", scryfallId: "scry-rhystic", assignedQuantity: 0)

        func state(deckAUsed: Int) -> DeckCardOwnershipResult {
            let assigned = deckACard.assignedQuantity
            let deckA = Deck(id: "deck-a", name: "Mazo 1", cards: [deckCard(id: "card-1", deckId: "deck-a", cardName: "Rhystic Study", scryfallId: "scry-rhystic", assignedQuantity: deckAUsed)])
            let deckB = Deck(id: "deck-b", name: "Mazo 2", cards: [deckBCard])
            _ = assigned
            let index = buildOwnershipIndex(collection)
            let assignments = buildOtherDeckAssignments([deckA, deckB])
            return deckCardOwnershipResult(card: deckBCard, ownershipIndex: index, otherDecksAssignments: assignments)
        }

        let before = state(deckAUsed: 1)
        #expect(before.availableToAssign == 0)
        #expect(before.assignedInOtherDecks.count == 1)

        let after = state(deckAUsed: 0)
        #expect(after.availableToAssign == 1)
        #expect(after.assignedInOtherDecks.isEmpty)
    }
}