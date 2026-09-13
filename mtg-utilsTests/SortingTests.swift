import Foundation
import Testing
@testable import mtg_utils

// Port of frontend/tests/unit/sorting.test.ts (name, cmc and price_trend fields).
// The Swift engine sorts by SortField (.name/.cmc/.price/...) with a stable
// name tiebreak; price comes from the card model rather than a PriceSummary.

@Suite("Card Sorting Engine")
struct SortingTests {

    @Test func extractsCmcCorrectly() {
        #expect(extractCmc(from: "{2}{U}{B}") == 4)
        #expect(extractCmc(from: "{W}") == 1)
        #expect(extractCmc(from: "{X}{R}") == 1)
        #expect(extractCmc(from: "{7}") == 7)
        #expect(extractCmc(from: "{0}") == 0)
        #expect(extractCmc(from: nil) == 0)
        #expect(extractCmc(from: "") == 0)
    }

    private var sampleCards: [TestSortableCard] {
        [
            TestSortableCard(name: "Sol Ring", manaCost: "{1}", typeLine: "Artifact", price: 1.5, category: .artifacts),
            TestSortableCard(name: "Lightning Bolt", manaCost: "{R}", typeLine: "Instant", price: 2.0, category: .instants),
            TestSortableCard(name: "Black Lotus", manaCost: "{0}", typeLine: "Artifact", price: 5000.0, category: .artifacts),
            TestSortableCard(name: "Counterspell", manaCost: "{U}{U}", typeLine: "Instant", price: 1.2, category: .instants),
        ]
    }

    @Test func sortsByNameAscendingAndDescending() {
        let asc = sortCards(sampleCards, by: .name, direction: .ascending)
        #expect(asc.map(\.name) == ["Black Lotus", "Counterspell", "Lightning Bolt", "Sol Ring"])

        let desc = sortCards(sampleCards, by: .name, direction: .descending)
        #expect(desc.map(\.name) == ["Sol Ring", "Lightning Bolt", "Counterspell", "Black Lotus"])
    }

    @Test func sortsByCmcWithNameTiebreak() {
        let cards = sortCards(sampleCards, by: .cmc, direction: .ascending)
        #expect(cards.map(\.name) == ["Black Lotus", "Lightning Bolt", "Sol Ring", "Counterspell"])
    }

    @Test func sortsByPriceTrendAscendingAndDescending() {
        let desc = sortCards(sampleCards, by: .price, direction: .descending)
        #expect(desc.map(\.name) == ["Black Lotus", "Lightning Bolt", "Sol Ring", "Counterspell"])

        let asc = sortCards(sampleCards, by: .price, direction: .ascending)
        #expect(asc.map(\.name) == ["Counterspell", "Sol Ring", "Lightning Bolt", "Black Lotus"])
    }

    @Test func sortsByCategoryThenName() {
        let cards = sortCards(sampleCards, by: .category, direction: .ascending)
        // instants (order 3) come first, then artifacts (order 5); name is the tiebreak.
        #expect(cards.map(\.name) == ["Counterspell", "Lightning Bolt", "Black Lotus", "Sol Ring"])
    }

    @Test func extractsColorsInWubrgOrder() {
        #expect(extractColors(from: "{2}{U}{B}") == ["U", "B"])
        #expect(extractColors(from: "{R}{G}{W}") == ["W", "R", "G"])
        #expect(extractColors(from: "{W/U}") == ["W", "U"])
        #expect(extractColors(from: "{1}") == [])
        #expect(extractColors(from: nil) == [])
    }

    @Test func extractsDeckColorsAggregated() {
        let cards = [
            DeckCard(id: "1", deckId: "d1", cardScryfallId: "s1", cardName: "Opt", quantity: 4, manaCost: "{U}"),
            DeckCard(id: "2", deckId: "d1", cardScryfallId: "s2", cardName: "Lightning Bolt", quantity: 4, manaCost: "{R}"),
            DeckCard(id: "3", deckId: "d1", cardScryfallId: "s3", cardName: "Sol Ring", quantity: 1, manaCost: "{1}")
        ]
        #expect(extractDeckColors(cards: cards) == ["U", "R"])
    }

    @Test func estimatesDeckPriceCorrectly() {
        let cards = [
            DeckCard(id: "1", deckId: "d1", cardScryfallId: "s1", cardName: "Snapcaster Mage", quantity: 1, typeLine: "Creature - Human Wizard"),
            DeckCard(id: "2", deckId: "d1", cardScryfallId: "s2", cardName: "Island", quantity: 2, typeLine: "Basic Land - Island")
        ]
        let estimated = estimateDeckPrice(cards: cards)
        // Snapcaster Mage = 29.99, Island = 0.15 * 2 = 0.30 -> Total 30.29
        #expect(estimated == 30.29)
    }

    @Test func deckSortFieldDisplayNames() {
        #expect(DeckSortField.completion.displayName == "Completitud")
        #expect(DeckSortField.price.displayName == "Precio")
        #expect(DeckSortField.name.displayName == "Nombre")
        #expect(DeckSortField.date.displayName == "Fecha")
    }
}