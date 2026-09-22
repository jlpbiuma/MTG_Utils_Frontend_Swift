import Foundation
import Testing
@testable import mtg_utils

@Suite("Backend loading and web parity", .serialized)
@MainActor
struct BackendLoadingTests {
    private func store() -> BackendDataStore {
        LoadingURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LoadingURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return BackendDataStore(
            client: BackendClient(baseURL: URL(string: "https://mtg.test")!, session: session),
            session: session
        )
    }

    @Test func deckListUsesOneRequestAndPreservesServerMetrics() async throws {
        let vm = DecksListViewModel(store: store(), userId: "u1")
        await vm.load()
        let deck = try #require(vm.decks.first)
        #expect(vm.errorMessage == nil)
        #expect(LoadingURLProtocol.paths == ["/api/decks"])
        #expect(deck.totalCards == 100)
        #expect(deck.ownedCards == 75)
        #expect(deck.missingCardsCount == 25)
        #expect(deck.completionPercentage == 75)
        #expect(deck.estimatedPrice == 123.45)
        #expect(deck.colors == ["U", "R"])
        vm.selectedColors = ["U"]
        #expect(vm.filteredAndSortedDecks.count == 1)
    }

    @Test func detailUsesOneLocalViewRequestIncludingPricesAndCommanderIdentity() async throws {
        let vm = DeckDetailViewModel(deck: Deck(id: "d1", name: "Placeholder"), store: store())
        await vm.load()
        let detail = try #require(vm.detail)
        #expect(vm.errorMessage == nil)
        #expect(vm.isLoading == false)
        #expect(detail.name == "Server deck")
        #expect(detail.completionPercentage == 75)
        #expect(detail.cards.first?.availableToAssign == 2)
        #expect(detail.cards.first?.assignedInOtherDecks.first?.deckName == "Other deck")
        #expect(vm.deck.cards.first?.setCode == "MH3")
        #expect(vm.priceSummary?.totalNetValue == 8)
        #expect(vm.commanderColorIdentity == ["U", "R"])
        #expect(LoadingURLProtocol.paths == ["/api/decks/d1/view"])
    }

    @Test func collectionLoadsCardsAndLocalPricesWithOneRequest() async throws {
        let vm = CollectionViewModel(store: store())
        await vm.load()
        #expect(vm.errorMessage == nil)
        #expect(vm.cards.count == 1)
        #expect(vm.stats.totalCards == 4)
        #expect(vm.priceSummary?.totalNetValue == 8)
        #expect(LoadingURLProtocol.paths == ["/api/collection/view"])
    }

    @Test func editingOneDeckDoesNotDownloadOtherDecks() async throws {
        let vm = DecksListViewModel(store: store(), userId: "u1")
        let deck = try await vm.deck(id: "d1")
        #expect(deck?.name == "Server deck")
        #expect(LoadingURLProtocol.paths == ["/api/decks/d1/view"])
    }

    @Test func failedDetailShowsAnErrorAndStopsLoading() async {
        let vm = DeckDetailViewModel(deck: Deck(id: "unavailable", name: "Missing"), store: store())
        await vm.load()
        #expect(vm.detail == nil)
        #expect(vm.errorMessage != nil)
        #expect(vm.isLoading == false)
        #expect(LoadingURLProtocol.paths == ["/api/decks/unavailable/view"])
    }

    @Test func cacheRefreshesForSameCountReplacementAndEditionSearch() async throws {
        let store = MockDataStore(seed: false)
        let original = CollectionCard(id: "c1", userId: "u1", cardScryfallId: "s1", cardName: "Sol Ring", quantity: 1, setCode: "C21")
        try await store.saveCollection([original])
        let vm = CollectionViewModel(store: store)
        await vm.load()
        #expect(vm.sorted.first?.setCode == "C21")
        vm.searchText = "MH3"
        #expect(vm.sorted.isEmpty)
        await vm.updateEdition(id: "c1", setCode: "MH3")
        #expect(vm.sorted.first?.setCode == "MH3")
        await vm.updateQuantity(id: "c1", quantity: 7)
        #expect(vm.groups.first?.totalCards == 7)
        var replacement = original
        replacement.cardName = "Lightning Bolt"
        try await store.saveCollection([replacement])
        vm.searchText = ""
        await vm.load()
        #expect(vm.sorted.map(\.cardName) == ["Lightning Bolt"])
    }

    @Test func addingCardToDeckUsesSingleEndpointAndReloadsSnapshot() async throws {
        let store = store()
        let vm = DeckDetailViewModel(deck: Deck(id: "d1", name: "Placeholder"), store: store)
        await vm.load()
        LoadingURLProtocol.reset()

        let card = ScryfallCard(
            id: "s2",
            name: "Counterspell",
            manaCost: "{U}{U}",
            cmc: 2,
            typeLine: "Instant",
            oracleText: nil,
            set: "frf",
            setName: "Fate Reforged",
            collectorNumber: "3",
            rarity: "uncommon",
            imageUris: nil,
            cardFaces: nil,
            colorIdentity: ["U"]
        )
        try await vm.addCard(card, quantity: 1, isSideboard: false)
        #expect(LoadingURLProtocol.paths == ["/api/decks/d1/cards", "/api/decks/d1/view"])
    }

    @Test func updatingDeckCardUsesSinglePatchAndReloadsSnapshot() async throws {
        let store = store()
        let vm = DeckDetailViewModel(deck: Deck(id: "d1", name: "Placeholder"), store: store)
        await vm.load()
        LoadingURLProtocol.reset()

        await vm.updateQuantity(id: "c1", quantity: 2)
        #expect(LoadingURLProtocol.paths == ["/api/decks/cards/c1", "/api/decks/d1/view"])

        LoadingURLProtocol.reset()
        await vm.updateEdition(id: "c1", setCode: "MH2")
        #expect(LoadingURLProtocol.paths == ["/api/decks/cards/c1", "/api/decks/d1/view"])
    }

    @Test func removingDeckCardUsesSingleDeleteAndReloadsSnapshot() async throws {
        let store = store()
        let vm = DeckDetailViewModel(deck: Deck(id: "d1", name: "Placeholder"), store: store)
        await vm.load()
        LoadingURLProtocol.reset()

        await vm.removeCard(id: "c1")
        #expect(LoadingURLProtocol.paths == ["/api/decks/cards/c1", "/api/decks/d1/view"])
    }

    @Test func deletingDeckUsesSingleDeleteRequest() async throws {
        let store = store()
        let vm = DecksListViewModel(store: store, userId: "u1")
        LoadingURLProtocol.reset()

        try await vm.deleteDeck(id: "d1")
        #expect(LoadingURLProtocol.paths == ["/api/decks/d1"])
    }

    @Test func updatingAndRemovingCollectionCardsUsesGranularEndpoints() async throws {
        let store = store()
        let vm = CollectionViewModel(store: store)
        await vm.load()
        LoadingURLProtocol.reset()

        await vm.updateQuantity(id: "c1", quantity: 5)
        #expect(LoadingURLProtocol.paths == ["/api/collection/c1"])
        #expect(vm.cards.first?.quantity == 5)

        LoadingURLProtocol.reset()
        await vm.updateEdition(id: "c1", setCode: "EMA")
        #expect(LoadingURLProtocol.paths == ["/api/collection/c1"])
        #expect(vm.cards.first?.setCode == "EMA")

        LoadingURLProtocol.reset()
        await vm.removeCard(id: "c1")
        #expect(LoadingURLProtocol.paths == ["/api/collection/c1"])
        #expect(vm.cards.isEmpty)
    }
}

// A separate protocol prevents interference with the Scryfall suite running in parallel.
nonisolated private final class LoadingURLProtocol: URLProtocol {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var recordedPaths: [String] = []
    static var paths: [String] { lock.withLock { recordedPaths } }
    static func reset() { lock.withLock { recordedPaths = [] } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    override func startLoading() {
        let url = request.url!
        Self.lock.withLock { Self.recordedPaths.append(url.path) }
        let summary = #"{"id":"d1","userId":"u1","name":"Server deck","format":"Commander","createdAt":"2026-09-01T00:00:00Z","updatedAt":"2026-09-01T00:00:00Z","totalCards":100,"uniqueCards":80,"ownedCards":75,"missingCards":25,"completionPercentage":75,"colors":["U","R"],"totalValue":123.45}"#
        let card = #"{"id":"c1","deckId":"d1","cardScryfallId":"s1","cardName":"Sol Ring","quantity":4,"assignedQuantity":1,"isSideboard":false,"isCommander":false,"setCode":"MH3","ownedInCollection":3,"availableToAssign":2,"assignedInOtherDecks":[{"deckId":"d2","deckName":"Other deck","quantity":1}],"missingCount":1}"#
        let body: String
        let status: Int
        switch url.path {
        case "/api/decks": body = "[\(summary)]"; status = 200
        case "/api/decks/d1/view":
            let prices = #"{"provider":"cardmarket","currency":"EUR","currencySymbol":"€","totalCards":100,"totalNetValue":8,"totalOwnedValue":6,"totalMissingValue":2,"quotes":{}}"#
            body = String(summary.dropLast()) + ",\"cards\":[\(card)],\"priceSummary\":\(prices),\"commanderColorIdentity\":[\"U\",\"R\"]}"
            status = 200
        case "/api/collection/view":
            let collectionCard = #"{"id":"c1","userId":"u1","cardScryfallId":"s1","cardName":"Sol Ring","quantity":4,"updatedAt":"2026-09-01T00:00:00Z"}"#
            let prices = #"{"provider":"cardmarket","currency":"EUR","currencySymbol":"€","totalCards":4,"totalNetValue":8,"totalOwnedValue":8,"totalMissingValue":0,"quotes":{}}"#
            body = "{\"cards\":[\(collectionCard)],\"priceSummary\":\(prices)}"
            status = 200
        case "/api/decks/d1/cards", "/api/decks/cards/c1", "/api/decks/d1", "/api/collection/c1":
            body = #"{"status":"success"}"#
            status = 200
        case "/api/collection/add-or-increment":
            body = #"{"id":"c2","userId":"u1","cardScryfallId":"s2","cardName":"Counterspell","quantity":1,"updatedAt":"2026-09-01T00:00:00Z"}"#
            status = 200
        default: body = "{}"; status = 503
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}
