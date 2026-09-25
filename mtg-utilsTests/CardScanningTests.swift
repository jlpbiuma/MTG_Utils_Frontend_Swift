import Foundation
import Testing
@testable import mtg_utils

// Tests for the camera card scanner: backend OCR resolve + collection merge.

// MARK: - Fixtures

private let boltMatch = CardScanMatch(
    ocrTitle: "Lightning Bolt",
    matchScore: 0,
    catalog: CardScanCatalogInfo(
        id: "cat-bolt",
        name: "Lightning Bolt",
        normalizedName: "lightning bolt",
        manaCost: "{R}",
        typeLine: "Instant",
        imageUri: nil
    ),
    printing: CardScanPrintingInfo(
        id: "uuid-bolt",
        catalogId: "cat-bolt",
        setCode: "sta",
        collectorNumber: "9",
        imageUri: nil,
        priceEur: 0.5,
        priceCardmarketTrend: 0.45
    ),
    alternatives: []
)

private let counterspellMatch = CardScanMatch(
    ocrTitle: "Counterspell",
    matchScore: 0,
    catalog: CardScanCatalogInfo(
        id: "cat-counterspell",
        name: "Counterspell",
        normalizedName: "counterspell",
        manaCost: "{U}{U}",
        typeLine: "Instant",
        imageUri: nil
    ),
    printing: CardScanPrintingInfo(
        id: "uuid-counterspell",
        catalogId: "cat-counterspell",
        setCode: "frf",
        collectorNumber: "3",
        imageUri: nil,
        priceEur: 1.0,
        priceCardmarketTrend: 0.9
    ),
    alternatives: []
)

private func makeResolver(_ match: CardScanMatch? = boltMatch) -> StubCardScanResolver {
    StubCardScanResolver(match: match)
}

private func makeViewModel(
    resolver: CardScanResolving = makeResolver(),
    store: AppDataStoring = MockDataStore(seed: false)
) -> CardScannerViewModel {
    CardScannerViewModel(resolver: resolver, store: store)
}

// MARK: - Name normalization

@Suite("Scan Name Normalization")
struct ScanNameNormalizationTests {
    @Test func normalizesWhitespaceCaseAndSplitFaces() {
        #expect(normalizeCardName("  OPPOSITION  AGENT // Trickster ") == "opposition agent")
        #expect(normalizeCardName("lightning bolt") == "lightning bolt")
        #expect(normalizeCardName("") == "")
    }
}

// MARK: - Detection pipeline

@Suite("Scan Detection Pipeline", .serialized)
struct CardScanningPipelineTests {
    @Test func detectsCardAfterBackendResolve() async {
        let vm = makeViewModel(resolver: makeResolver(boltMatch))
        vm.enterScanningForTesting()

        vm.scan(imageJPEG: Data([0xFF, 0xD8, 0xFF]))
        await vm.recognitionTask?.value

        #expect(vm.phase == .detected(ScannedCard(match: boltMatch)))
        #expect(vm.quantity == 1)
    }

    @Test func surfacesErrorWhenResolverFails() async {
        struct Boom: LocalizedError {
            var errorDescription: String? { "fallo OCR" }
        }
        let vm = makeViewModel(resolver: StubCardScanResolver(error: Boom()))
        vm.enterScanningForTesting()

        vm.scan(imageJPEG: Data([0xFF, 0xD8, 0xFF]))
        await vm.recognitionTask?.value

        guard case .error(let message) = vm.phase else {
            Issue.record("Expected error phase")
            return
        }
        #expect(message.contains("fallo OCR"))
    }
}

// MARK: - Collection persistence

@Suite("Scan Collection Persistence")
struct CardScanningPersistenceTests {
    @Test func addsResolvedCardToCollection() async throws {
        let store = MockDataStore(seed: false)
        let vm = makeViewModel(resolver: makeResolver(boltMatch), store: store)
        vm.enterScanningForTesting()

        vm.scan(imageJPEG: Data([0xFF, 0xD8, 0xFF]))
        await vm.recognitionTask?.value

        vm.quantity = 3
        await vm.addToCollection()

        let saved = try await store.allCollection()
        #expect(saved.count == 1)
        #expect(saved[0].cardName == "Lightning Bolt")
        #expect(saved[0].quantity == 3)
        #expect(saved[0].cardScryfallId == "uuid-bolt")
        #expect(saved[0].setCode == "sta")
        #expect(vm.phase == .scanning)
    }

    @Test func mergingSameCardIncrementsQuantity() async throws {
        let store = MockDataStore(seed: false)
        let vm = makeViewModel(resolver: makeResolver(boltMatch), store: store)
        vm.enterScanningForTesting()

        vm.scan(imageJPEG: Data([0xFF, 0xD8, 0xFF]))
        await vm.recognitionTask?.value
        vm.quantity = 1
        await vm.addToCollection()

        vm.scan(imageJPEG: Data([0xFF, 0xD8, 0xFF]))
        await vm.recognitionTask?.value
        vm.quantity = 2
        await vm.addToCollection()

        let saved = try await store.allCollection()
        #expect(saved.count == 1)
        #expect(saved[0].quantity == 3)
    }

    @Test func keepsDistinctCardsSeparate() async throws {
        let store = MockDataStore(seed: false)

        let vmBolt = makeViewModel(resolver: makeResolver(boltMatch), store: store)
        vmBolt.enterScanningForTesting()
        vmBolt.scan(imageJPEG: Data([0xFF, 0xD8, 0xFF]))
        await vmBolt.recognitionTask?.value
        await vmBolt.addToCollection()

        let vmCounterspell = makeViewModel(resolver: makeResolver(counterspellMatch), store: store)
        vmCounterspell.enterScanningForTesting()
        vmCounterspell.scan(imageJPEG: Data([0xFF, 0xD8, 0xFF]))
        await vmCounterspell.recognitionTask?.value
        await vmCounterspell.addToCollection()

        let saved = try await store.allCollection()
        #expect(saved.count == 2)
        #expect(Set(saved.map(\.cardName)) == Set(["Lightning Bolt", "Counterspell"]))
    }

    @Test func retryAfterFailedSaveRestoresDetectedCard() async {
        let store = FailingMockDataStore()
        let vm = makeViewModel(resolver: makeResolver(boltMatch), store: store)
        vm.enterScanningForTesting()

        vm.scan(imageJPEG: Data([0xFF, 0xD8, 0xFF]))
        await vm.recognitionTask?.value

        await vm.addToCollection()

        var isError = false
        if case .error = vm.phase { isError = true }
        #expect(isError)

        vm.retry()
        #expect(vm.phase == .detected(ScannedCard(match: boltMatch)))
    }
}

// MARK: - Failing store

private final class FailingMockDataStore: AppDataStoring {
    func allDecks() async throws -> [Deck] { [] }
    func allDeckSummaries() async throws -> [DeckSummary] { [] }
    func deckDetail(id: String) async throws -> DeckDetail? { nil }
    func saveDecks(_ decks: [Deck]) async throws {}
    func allCollection() async throws -> [CollectionCard] { [] }
    func saveCollection(_ cards: [CollectionCard]) async throws {
        throw TestStoreError.failed
    }
}

private enum TestStoreError: Error {
    case failed
}
