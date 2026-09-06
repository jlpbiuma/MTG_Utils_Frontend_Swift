import Foundation
import Testing
@testable import mtg_utils

// Port of frontend/tests/unit/data-cross-matching.test.ts (snapshot of the
// fixture files copied into mtg-utilsTests/Data/).

@Suite("Local Data Cross-Matching (data/mazos vs data/coleciones)")
struct CrossMatchingTests {

    private struct CrossMatchResult {
        var totalDeckCards: Int
        var uniqueDeckCards: Int
        var matchedUniqueCards: Int
        var ownedCards: Int
        var missingCardsCount: Int
        var completionPercentage: Double
        var matchedNames: [String]
    }

    /// Mirrors Vitest's calculateCrossMatching (name-based matching).
    private func crossMatch(deck: [ParsedDeckEntry], collectionMap: [String: Int]) -> CrossMatchResult {
        var total = 0
        var matchedUnique = 0
        var owned = 0
        var matchedNames: [String] = []

        for card in deck {
            let key = normalizeCardName(card.name)
            total += card.quantity
            let ownedQty = collectionMap[key] ?? 0
            if ownedQty > 0 {
                matchedUnique += 1
                owned += min(ownedQty, card.quantity)
                matchedNames.append(card.name)
            }
        }

        let missing = max(0, total - owned)
        let percentage = total > 0 ? ((Double(owned) / Double(total)) * 1000).rounded() / 10 : 0

        return CrossMatchResult(
            totalDeckCards: total,
            uniqueDeckCards: deck.count,
            matchedUniqueCards: matchedUnique,
            ownedCards: owned,
            missingCardsCount: missing,
            completionPercentage: percentage,
            matchedNames: matchedNames
        )
    }

    private func collectionMap(from text: String) throws -> [String: Int] {
        let entries = try parseCollectionText(text)
        var map: [String: Int] = [:]
        for entry in entries {
            map[normalizeCardName(entry.name), default: 0] += entry.quantity
        }
        return map
    }

    /// Builds a full Deck + Collection through the shared Swift pipeline so the
    /// DeckSummary (used by the UI) is validated against the same fixtures.
    private func pipelineSummary(deckText: String, collectionTexts: [String]) throws -> (deck: Deck, summary: DeckSummary, matchedUnique: Int) {
        let decklist = try parseDecklistText(deckText)

        let deckCards = decklist.mainboard.map { entry in
            DeckCard(
                id: "deck-\(entry.lineNumber)",
                deckId: "deck-1",
                cardScryfallId: "pending:\(normalizeCardName(entry.name))",
                cardName: entry.name,
                quantity: entry.quantity
            )
        }
        let deck = Deck(id: "deck-1", name: "Test Deck", cards: deckCards)

        let collectionCards: [CollectionCard] = try collectionTexts.flatMap { text in
            try parseCollectionText(text).map { entry in
                CollectionCard(
                    id: "col-\(normalizeCardName(entry.name))",
                    cardScryfallId: "pending:\(normalizeCardName(entry.name))",
                    cardName: entry.name,
                    quantity: entry.quantity
                )
            }
        }

        let index = buildOwnershipIndex(collectionCards)
        let assignments = buildOtherDeckAssignments([deck])

        var matchedUnique = 0
        for card in deck.cards {
            let result = deckCardOwnershipResult(card: card, ownershipIndex: index, otherDecksAssignments: assignments)
            if result.ownedInCollection > 0 { matchedUnique += 1 }
        }

        let summary = computeDeckSummary(deck: deck, collection: collectionCards)
        return (deck, summary, matchedUnique)
    }

    @Test func verifiesDeckFileParsesExactly100Cards() throws {
        let raw = try Fixtures.load("Cards")
        let parsed = try parseDecklistText(raw)

        #expect(parsed.mainboard.count == 86)
        #expect(parsed.totalCards == 100)
    }

    @Test func matchesDeckAgainstIndividualCollectionFiles() throws {
        let deckText = try Fixtures.load("Cards")
        let deck = try parseDecklistText(deckText)

        let expectations: [(String, Int, Int)] = [
            ("Collection1", 1, 1),
            ("Collection2", 26, 40),
            ("Collection3", 3, 3),
            ("Collection4", 7, 7),
        ]

        for (name, expectedUnique, expectedOwned) in expectations {
            let raw = try Fixtures.load(name)
            let colMap = try collectionMap(from: raw)
            let result = crossMatch(deck: deck.mainboard, collectionMap: colMap)

            #expect(result.matchedUniqueCards == expectedUnique, "\(name) matchedUnique")
            #expect(result.ownedCards == expectedOwned, "\(name) owned")
        }
    }

    @Test func calculatesExactCombinedCrossMatching() throws {
        let deckText = try Fixtures.load("Cards")
        let deck = try parseDecklistText(deckText)

        var combined: [String: Int] = [:]
        for name in ["Collection1", "Collection2", "Collection3", "Collection4"] {
            let text = try Fixtures.load(name)
            let map = try collectionMap(from: text)
            for (key, qty) in map {
                combined[key, default: 0] += qty
            }
        }

        let match = crossMatch(deck: deck.mainboard, collectionMap: combined)

        #expect(match.totalDeckCards == 100)
        #expect(match.uniqueDeckCards == 86)
        #expect(match.matchedUniqueCards == 32)
        #expect(match.ownedCards == 46)
        #expect(match.missingCardsCount == 54)
        #expect(match.completionPercentage == 46.0)

        for keyCard in [
            "Aragorn, the Uniter",
            "Annie Joins Up",
            "Arcane Signet",
            "Command Tower",
            "Cultivate",
            "Elven Chorus",
            "Exotic Orchard",
            "Farseek",
        ] {
            #expect(match.matchedNames.contains(keyCard), "missing \(keyCard)")
        }
    }

    @Test func pipelineDeckSummaryMatchesFixtureNumbers() throws {
        let deckText = try Fixtures.load("Cards")
        let collectionTexts = try ["Collection1", "Collection2", "Collection3", "Collection4"].map(Fixtures.load)

        let (_, summary, matchedUnique) = try pipelineSummary(deckText: deckText, collectionTexts: collectionTexts)

        #expect(summary.totalCards == 100)
        #expect(summary.uniqueCards == 86)
        #expect(summary.ownedCards == 46)
        #expect(summary.missingCardsCount == 54)
        #expect(summary.completionPercentage == 46.0)
        #expect(matchedUnique == 32)
    }
}