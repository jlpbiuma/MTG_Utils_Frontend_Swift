import Foundation
import Testing
@testable import mtg_utils

@Suite("View Model Enhancements Tests")
@MainActor
struct ViewModelEnhancementTests {

    private func makeMockStore() -> MockDataStore {
        let store = MockDataStore(seed: false)
        return store
    }

    @Test func optimisticDeckImportUpdatesListBeforeBackgroundSync() async throws {
        let store = makeMockStore()
        let vm = DecksListViewModel(store: store, userId: "u1")
        await vm.load()

        let deck = Deck(
            id: "imported-deck",
            userId: "u1",
            name: "Importado",
            format: "Commander",
            cards: [
                DeckCard(cardScryfallId: "pending:sol ring", cardName: "Sol Ring", quantity: 1)
            ]
        )

        vm.importDeckLocally(deck)
        #expect(vm.decks.contains(where: { $0.id == deck.id }))
        #expect(vm.decks.first(where: { $0.id == deck.id })?.totalCards == 1)

        await Task.yield()
        await Task.yield()
        #expect(try await store.allDecks().contains(where: { $0.id == deck.id }))
    }

    // MARK: - CollectionViewModel Tests

    @Test func collectionViewModelSupportsGroupingAndSorting() async throws {
        let store = makeMockStore()
        let cards = [
            CollectionCard(id: "c1", userId: "u1", cardScryfallId: "s1", cardName: "Counterspell", quantity: 2, setCode: "EMA", manaCost: "{U}{U}", typeLine: "Instant"),
            CollectionCard(id: "c2", userId: "u1", cardScryfallId: "s2", cardName: "Sol Ring", quantity: 1, setCode: "C21", manaCost: "{1}", typeLine: "Artifact"),
            CollectionCard(id: "c3", userId: "u1", cardScryfallId: "s3", cardName: "Island", quantity: 10, setCode: "UNH", manaCost: nil, typeLine: "Basic Land - Island")
        ]
        try await store.saveCollection(cards)

        let vm = CollectionViewModel(store: store)
        await vm.load()

        // 1. Initial defaults
        #expect(vm.isGrouped == true)
        #expect(vm.sortField == .cmc)
        #expect(vm.cards.count == 3)
        #expect(vm.stats.totalCards == 13)
        #expect(vm.stats.uniqueCards == 3)
        #expect(vm.priceSummary != nil)
        #expect((vm.priceSummary?.totalNetValue ?? 0) > 0)

        // 2. Grouped sections
        let groups = vm.groups
        #expect(groups.count == 3) // Instants, Artifacts, Lands
        let labels = groups.map(\.label)
        #expect(labels.contains("Instantáneos"))
        #expect(labels.contains("Artefactos"))
        #expect(labels.contains("Tierras"))

        // 3. Flat sorted mode
        vm.isGrouped = false
        vm.sortField = .name
        vm.sortDirection = .ascending
        let namesAsc = vm.sorted.map(\.cardName)
        #expect(namesAsc == ["Counterspell", "Island", "Sol Ring"])

        vm.sortDirection = .descending
        let namesDesc = vm.sorted.map(\.cardName)
        #expect(namesDesc == ["Sol Ring", "Island", "Counterspell"])

        // 4. Search text filter
        vm.searchText = "artifact"
        #expect(vm.sorted.count == 1)
        #expect(vm.sorted.first?.cardName == "Sol Ring")

        vm.searchText = "UNH" // By set code
        #expect(vm.sorted.count == 1)
        #expect(vm.sorted.first?.cardName == "Island")

        vm.searchText = ""
        #expect(vm.sorted.count == 3)
    }

    @Test func optimisticCollectionImportUpdatesMetricsBeforeBackgroundSync() async throws {
        let store = makeMockStore()
        let existing = CollectionCard(
            id: "existing",
            userId: "u1",
            cardScryfallId: "bolt",
            cardName: "Lightning Bolt",
            quantity: 1,
            setCode: "M10",
            manaCost: "{R}",
            typeLine: "Instant"
        )
        try await store.saveCollection([existing])

        let vm = CollectionViewModel(store: store)
        await vm.load()
        let valueBeforeImport = vm.priceSummary?.totalNetValue ?? 0

        vm.importCardsLocally([
            CollectionCard(
                id: "imported-bolt",
                userId: "u1",
                cardScryfallId: "pending:lightning-bolt",
                cardName: "Lightning Bolt",
                quantity: 3,
                setCode: "M10",
                manaCost: "{R}",
                typeLine: "Instant"
            ),
            CollectionCard(
                id: "imported-island",
                userId: "u1",
                cardScryfallId: "pending:island",
                cardName: "Island",
                quantity: 5,
                setCode: "UNH",
                typeLine: "Basic Land — Island"
            ),
        ])

        // These values change synchronously; a sheet can close without waiting for I/O.
        #expect(vm.stats.uniqueCards == 2)
        #expect(vm.stats.totalCards == 9)
        #expect(vm.cards.first(where: { $0.cardName == "Lightning Bolt" })?.quantity == 4)
        #expect((vm.priceSummary?.totalNetValue ?? 0) > valueBeforeImport)

        // The detached persistence operation eventually saves exactly the optimistic snapshot.
        await Task.yield()
        await Task.yield()
        let persisted = try await store.allCollection()
        #expect(persisted.reduce(0) { $0 + $1.quantity } == 9)
    }

    @Test func collectionCardContextActionsEditEditionAndRemoveOnlyTheCollectionRow() async throws {
        let store = makeMockStore()
        let card = CollectionCard(
            id: "collection-card",
            userId: "u1",
            cardScryfallId: "s1",
            cardName: "Counterspell",
            quantity: 2,
            setCode: "7ED"
        )
        try await store.saveCollection([card])
        let vm = CollectionViewModel(store: store)
        await vm.load()

        await vm.updateEdition(id: card.id, setCode: " mh2 ")
        #expect(vm.cards.first?.setCode == "MH2")
        #expect(try await store.allCollection().first?.setCode == "MH2")

        await vm.updateQuantity(id: card.id, quantity: 5)
        #expect(vm.cards.first?.quantity == 5)
        #expect(try await store.allCollection().first?.quantity == 5)

        await vm.removeCard(id: card.id)
        #expect(vm.cards.isEmpty)
        #expect(try await store.allCollection().isEmpty)
    }

    @Test func deckCardContextActionsEditEditionAndRemoveOnlyTheDeckRow() async throws {
        let store = makeMockStore()
        let card = DeckCard(
            id: "deck-card",
            deckId: "deck",
            cardScryfallId: "s1",
            cardName: "Counterspell",
            quantity: 2,
            setCode: "7ED"
        )
        let deck = Deck(id: "deck", userId: "u1", name: "Control", cards: [card])
        try await store.saveDecks([deck])
        let vm = DeckDetailViewModel(deck: deck, store: store)
        await vm.load()

        await vm.updateEdition(id: card.id, setCode: "mh2")
        #expect(try await store.allDecks().first?.cards.first?.setCode == "MH2")

        await vm.updateQuantity(id: card.id, quantity: 5)
        #expect(try await store.allDecks().first?.cards.first?.quantity == 5)

        await vm.removeCard(id: card.id)
        #expect(try await store.allDecks().first?.cards.isEmpty == true)
    }

    // MARK: - DecksListViewModel Tests

    @Test func decksListViewModelSortingAndFiltering() async throws {
        let store = makeMockStore()

        let deckA = Deck(
            id: "d1",
            userId: "u1",
            name: "Blue White Control",
            format: "Modern",
            description: nil,
            commander: "Teferi",
            commanderScryfallId: nil,
            commanderImageUri: nil,
            createdAt: Date(timeIntervalSince1970: 1000),
            updatedAt: Date(timeIntervalSince1970: 2000),
            cards: [
                DeckCard(id: "c1", deckId: "d1", cardScryfallId: "s1", cardName: "Counterspell", quantity: 4, manaCost: "{U}{U}", typeLine: "Instant"),
                DeckCard(id: "c2", deckId: "d1", cardScryfallId: "s2", cardName: "Plains", quantity: 10, manaCost: nil, typeLine: "Basic Land - Plains")
            ]
        )

        let deckB = Deck(
            id: "d2",
            userId: "u1",
            name: "Mono Red Aggro",
            format: "Standard",
            description: nil,
            commander: nil,
            commanderScryfallId: nil,
            commanderImageUri: nil,
            createdAt: Date(timeIntervalSince1970: 3000),
            updatedAt: Date(timeIntervalSince1970: 4000),
            cards: [
                DeckCard(id: "c3", deckId: "d2", cardScryfallId: "s3", cardName: "Lightning Bolt", quantity: 4, manaCost: "{R}", typeLine: "Instant")
            ]
        )

        let deckC = Deck(
            id: "d3",
            userId: "u1",
            name: "Colorless Eldrazi",
            format: "Legacy",
            description: nil,
            commander: "Kozilek",
            commanderScryfallId: nil,
            commanderImageUri: nil,
            createdAt: Date(timeIntervalSince1970: 5000),
            updatedAt: Date(timeIntervalSince1970: 6000),
            cards: [
                DeckCard(id: "c4", deckId: "d3", cardScryfallId: "s4", cardName: "Sol Ring", quantity: 4, manaCost: "{1}", typeLine: "Artifact")
            ]
        )

        try await store.saveDecks([deckA, deckB, deckC])

        let vm = DecksListViewModel(store: store, userId: "u1")
        await vm.load()

        #expect(vm.decks.count == 3)

        // 1. Deduces colors & prices
        let d1 = try #require(vm.decks.first(where: { $0.id == "d1" }))
        #expect(d1.colors == ["U"])
        #expect(d1.estimatedPrice > 0)

        let d2 = try #require(vm.decks.first(where: { $0.id == "d2" }))
        #expect(d2.colors == ["R"])

        let d3 = try #require(vm.decks.first(where: { $0.id == "d3" }))
        #expect(d3.colors.isEmpty)

        // 2. Sort by name
        vm.sortField = .name
        vm.sortDirection = .ascending
        let sortedNames = vm.filteredAndSortedDecks.map(\.name)
        #expect(sortedNames == ["Blue White Control", "Colorless Eldrazi", "Mono Red Aggro"])

        // 3. Filter by Colorless ("C")
        vm.selectedColors = ["C"]
        let colorlessDecks = vm.filteredAndSortedDecks.map(\.name)
        #expect(colorlessDecks == ["Colorless Eldrazi"])

        // 4. Filter by Red ("R")
        vm.selectedColors = ["R"]
        let redDecks = vm.filteredAndSortedDecks.map(\.name)
        #expect(redDecks == ["Mono Red Aggro"])

        // 5. Search by Commander Name
        vm.selectedColors = []
        vm.searchText = "Teferi"
        let searchedDecks = vm.filteredAndSortedDecks.map(\.name)
        #expect(searchedDecks == ["Blue White Control"])

        // 6. Reset filters
        #expect(vm.hasActiveFilters == true)
        vm.resetFilters()
        #expect(vm.hasActiveFilters == false)
        #expect(vm.filteredAndSortedDecks.count == 3)
    }
}
