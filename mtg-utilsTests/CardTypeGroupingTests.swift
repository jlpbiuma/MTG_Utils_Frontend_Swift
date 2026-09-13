import Foundation
import Testing
@testable import mtg_utils

// Port of frontend/tests/unit/card-type-grouping.test.ts

@Suite("Card Type Categorization & Grouping")
struct CardTypeGroupingTests {

    @Test func categorizesStandardEnglishTypes() {
        #expect(getCardCategory(typeLine: "Creature — Human Soldier", cardName: nil) == .creatures)
        #expect(getCardCategory(typeLine: "Artifact Creature — Golem", cardName: nil) == .creatures)
        #expect(getCardCategory(typeLine: "Enchantment Creature — God", cardName: nil) == .creatures)
        #expect(getCardCategory(typeLine: "Legendary Planeswalker — Chandra", cardName: nil) == .planeswalkers)
        #expect(getCardCategory(typeLine: "Instant", cardName: nil) == .instants)
        #expect(getCardCategory(typeLine: "Sorcery", cardName: nil) == .sorceries)
        #expect(getCardCategory(typeLine: "Artifact — Equipment", cardName: nil) == .artifacts)
        #expect(getCardCategory(typeLine: "Enchantment — Aura", cardName: nil) == .enchantments)
        #expect(getCardCategory(typeLine: "Battle — Siege", cardName: nil) == .battles)
        #expect(getCardCategory(typeLine: "Basic Land — Mountain", cardName: nil) == .lands)
        #expect(getCardCategory(typeLine: "Land", cardName: nil) == .lands)
    }

    @Test func categorizesSpanishTypes() {
        #expect(getCardCategory(typeLine: "Criatura legendaria — Humano", cardName: nil) == .creatures)
        #expect(getCardCategory(typeLine: "Instantáneo", cardName: nil) == .instants)
        #expect(getCardCategory(typeLine: "Conjuro", cardName: nil) == .sorceries)
        #expect(getCardCategory(typeLine: "Artefacto", cardName: nil) == .artifacts)
        #expect(getCardCategory(typeLine: "Encantamiento", cardName: nil) == .enchantments)
        #expect(getCardCategory(typeLine: "Batalla — Asedio", cardName: nil) == .battles)
        #expect(getCardCategory(typeLine: "Tierra básica — Montaña", cardName: nil) == .lands)
    }

    @Test func fallsBackToOtherForUnknownOrMissing() {
        #expect(getCardCategory(typeLine: nil, cardName: nil) == .other)
        #expect(getCardCategory(typeLine: "", cardName: nil) == .other)
        #expect(getCardCategory(typeLine: "Conspiracy", cardName: nil) == .other)
        #expect(getCardCategory(typeLine: nil, cardName: "Unknown Card 12345") == .other)
    }

    @Test func usesCardNameHeuristicsForLands() {
        #expect(getCardCategory(typeLine: nil, cardName: "Island") == .lands)
        #expect(getCardCategory(typeLine: nil, cardName: "Mountain") == .lands)
        #expect(getCardCategory(typeLine: nil, cardName: "Plains") == .lands)
        #expect(getCardCategory(typeLine: nil, cardName: "Swamp") == .lands)
        #expect(getCardCategory(typeLine: nil, cardName: "Forest") == .lands)
        #expect(getCardCategory(typeLine: nil, cardName: "Wastes") == .lands)
        #expect(getCardCategory(typeLine: nil, cardName: "Snow-Covered Island") == .lands)
        #expect(getCardCategory(typeLine: nil, cardName: "Command Tower") == .lands)
        #expect(getCardCategory(typeLine: nil, cardName: "Reliquary Tower") == .lands)
        #expect(getCardCategory(typeLine: nil, cardName: "Izzet Boilerworks") == .lands)
        #expect(getCardCategory(typeLine: nil, cardName: "Spara's Headquarters") == .lands)
        #expect(getCardCategory(typeLine: nil, cardName: "Evolving Wilds") == .lands)
    }

    @Test func returnsEmptySectionsForEmptyCards() {
        let sections = groupCardsByType(
            [TestGroupableCard](),
            priceSummary: makePriceSummary(trending: [:])
        )
        #expect(sections.isEmpty)
    }

    @Test func groupsAndOrdersSectionsByHierarchy() {
        let priceSummary = makePriceSummary(
            trending: ["scry-bolt": 2.5, "scry-goyf": 15.0, "scry-mountain": 0.1]
        )

        let cards = [
            TestGroupableCard(
                cardName: "Mountain",
                cardScryfallId: "scry-mountain",
                typeLine: "Basic Land — Mountain",
                quantity: 10,
                ownedInCollection: 10,
                missingCount: 0
            ),
            TestGroupableCard(
                cardName: "Tarmogoyf",
                cardScryfallId: "scry-goyf",
                typeLine: "Creature — Lhurgoyf",
                quantity: 4,
                ownedInCollection: 2,
                missingCount: 2
            ),
            TestGroupableCard(
                cardName: "Lightning Bolt",
                cardScryfallId: "scry-bolt",
                typeLine: "Instant",
                quantity: 4,
                ownedInCollection: 4,
                missingCount: 0
            ),
        ]

        let sections = groupCardsByType(cards, priceSummary: priceSummary)

        #expect(sections.count == 3)
        #expect(sections[0].key == .creatures)
        #expect(sections[0].label == "Criaturas")
        #expect(sections[1].key == .instants)
        #expect(sections[1].label == "Instantáneos")
        #expect(sections[2].key == .lands)
        #expect(sections[2].label == "Tierras")
    }

    @Test func calculatesSectionStatsCompletionAndPrice() {
        let priceSummary = makePriceSummary(trending: ["scry-goyf": 15.0])

        let cards = [
            TestGroupableCard(
                cardName: "Tarmogoyf",
                cardScryfallId: "scry-goyf",
                typeLine: "Creature — Lhurgoyf",
                quantity: 4,
                ownedInCollection: 2,
                missingCount: 2
            ),
        ]

        let sections = groupCardsByType(cards, priceSummary: priceSummary)
        #expect(sections.count == 1)

        let creatureSection = sections[0]
        #expect(creatureSection.totalCards == 4)
        #expect(creatureSection.uniqueCards == 1)
        #expect(creatureSection.ownedCards == 2)
        #expect(creatureSection.missingCards == 2)
        #expect(creatureSection.completionPercentage == 50)
        #expect(creatureSection.sectionTotalPrice == 60)
        #expect(creatureSection.sectionMissingPrice == 30)
        #expect(creatureSection.currencySymbol == "€")
    }

    @Test func handlesFullCompletionCorrectly() {
        let priceSummary = makePriceSummary(trending: ["scry-bolt": 2.5])

        let cards = [
            TestGroupableCard(
                cardName: "Lightning Bolt",
                cardScryfallId: "scry-bolt",
                typeLine: "Instant",
                quantity: 4,
                ownedInCollection: 4,
                missingCount: 0
            ),
        ]

        let instantSection = groupCardsByType(cards, priceSummary: priceSummary)[0]
        #expect(instantSection.completionPercentage == 100)
        #expect(instantSection.missingCards == 0)
        #expect(instantSection.sectionMissingPrice == 0)
        #expect(instantSection.sectionTotalPrice == 10)
    }

    @Test func groupsLandsUsingNameHeuristicsWhenTypeLineMissing() {
        let cards = [
            TestGroupableCard(
                cardName: "Island",
                cardScryfallId: "pending:island",
                typeLine: nil,
                quantity: 10,
                ownedInCollection: 10,
                missingCount: 0
            ),
            TestGroupableCard(
                cardName: "Command Tower",
                cardScryfallId: "pending:command-tower",
                typeLine: nil,
                quantity: 1,
                ownedInCollection: 1,
                missingCount: 0
            ),
        ]

        let sections = groupCardsByType(cards)
        #expect(sections.count == 1)
        #expect(sections[0].key == .lands)
        #expect(sections[0].label == "Tierras")
        #expect(sections[0].totalCards == 11)
        #expect(sections[0].uniqueCards == 2)
    }

    @Test func ordersAllCategoriesAccordingToSpec() {
        let cards: [TestGroupableCard] = [
            TestGroupableCard(cardName: "Plains", cardScryfallId: "1", typeLine: "Basic Land — Plains"),
            TestGroupableCard(cardName: "Invasion of Gobakhan", cardScryfallId: "2", typeLine: "Battle — Siege"),
            TestGroupableCard(cardName: "Sol Ring", cardScryfallId: "3", typeLine: "Artifact"),
            TestGroupableCard(cardName: "Rhystic Study", cardScryfallId: "4", typeLine: "Enchantment"),
            TestGroupableCard(cardName: "Wrath of God", cardScryfallId: "5", typeLine: "Sorcery"),
            TestGroupableCard(cardName: "Brainstorm", cardScryfallId: "6", typeLine: "Instant"),
            TestGroupableCard(cardName: "Llanowar Elves", cardScryfallId: "7", typeLine: "Creature — Elf"),
            TestGroupableCard(cardName: "Jace, the Mind Sculptor", cardScryfallId: "8", typeLine: "Legendary Planeswalker — Jace"),
        ]

        let sections = groupCardsByType(cards)
        let keys = sections.map(\.key)
        #expect(keys == [
            .planeswalkers,
            .creatures,
            .instants,
            .sorceries,
            .enchantments,
            .artifacts,
            .battles,
            .lands
        ])
    }

    @Test func preservesCmcAscendingOrderWithinGroups() {
        let creatureCards = [
            DeckCardWithOwnership(
                id: "1",
                deckId: "d1",
                cardScryfallId: "c1",
                cardName: "Colossal Dreadmaw",
                quantity: 1,
                assignedQuantity: 0,
                isSideboard: false,
                isCommander: false,
                manaCost: "{4}{G}{G}",
                typeLine: "Creature — Dinosaur",
                imageUri: nil,
                setCode: "M21",
                ownedInCollection: 1,
                availableToAssign: 1,
                assignedInOtherDecks: [],
                missingCount: 0
            ),
            DeckCardWithOwnership(
                id: "2",
                deckId: "d1",
                cardScryfallId: "c2",
                cardName: "Llanowar Elves",
                quantity: 1,
                assignedQuantity: 0,
                isSideboard: false,
                isCommander: false,
                manaCost: "{G}",
                typeLine: "Creature — Elf Druid",
                imageUri: nil,
                setCode: "DOM",
                ownedInCollection: 1,
                availableToAssign: 1,
                assignedInOtherDecks: [],
                missingCount: 0
            ),
            DeckCardWithOwnership(
                id: "3",
                deckId: "d1",
                cardScryfallId: "c3",
                cardName: "Dryad Arbor",
                quantity: 1,
                assignedQuantity: 0,
                isSideboard: false,
                isCommander: false,
                manaCost: "",
                typeLine: "Land Creature — Forest Dryad",
                imageUri: nil,
                setCode: "FUT",
                ownedInCollection: 1,
                availableToAssign: 1,
                assignedInOtherDecks: [],
                missingCount: 0
            ),
        ]

        // When sorted by CMC ascending (0, 1, 6)
        let sorted = sortCards(creatureCards, by: .cmc, direction: .ascending)
        let sections = groupCardsByType(sorted)
        #expect(sections.count == 1)
        #expect(sections[0].key == .creatures)
        #expect(sections[0].cards.map(\.cardName) == ["Dryad Arbor", "Llanowar Elves", "Colossal Dreadmaw"])
    }
}