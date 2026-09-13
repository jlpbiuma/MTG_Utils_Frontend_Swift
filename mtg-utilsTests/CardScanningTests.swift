import CoreGraphics
import Foundation
import Testing
@testable import mtg_utils

// Tests for the camera card scanner: name normalization, stability voting,
// OCR → resolution pipeline, and collection merge persistence.

// MARK: - Fixtures

private let boltCard = ScryfallCard(
    id: "uuid-bolt",
    name: "Lightning Bolt",
    manaCost: "{R}",
    cmc: 1,
    typeLine: "Instant",
    oracleText: nil,
    set: "sta",
    setName: "Starter 2022",
    collectorNumber: "9",
    rarity: "common",
    imageUris: nil,
    cardFaces: nil,
    colorIdentity: ["R"]
)

private let counterspellCard = ScryfallCard(
    id: "uuid-counterspell",
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

private func makeImage() -> CGImage {
    let context = CGContext(
        data: nil,
        width: 2,
        height: 2,
        bitsPerComponent: 8,
        bytesPerRow: 2 * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    return context.makeImage()!
}

private func makeScanner(_ card: ScryfallCard? = boltCard) -> StubCardScanService {
    let candidates = [CardScanCandidate(confidence: 0.9, text: "  Lightning  Bolt ")]
    return StubCardScanService(candidates: candidates, resolvedCard: card)
}

private func makeViewModel(
    scanner: CardScanning = makeScanner(),
    store: AppDataStoring = MockDataStore(seed: false),
    minimumStableFrames: Int = 3,
    scanThrottle: TimeInterval = 0
) -> CardScannerViewModel {
    CardScannerViewModel(
        scanner: scanner,
        store: store,
        minimumStableFrames: minimumStableFrames,
        scanThrottle: scanThrottle
    )
}

// MARK: - Name normalization

@Suite("Scan Name Normalization")
struct ScanNameNormalizationTests {
    @Test func normalizesWhitespaceCaseAndSplitFaces() {
        #expect(normalizeCardName("  OPPOSITION  AGENT // Trickster ") == "opposition agent")
        #expect(normalizeCardName("lightning bolt") == "lightning bolt")
        #expect(normalizeCardName("") == "")
    }

    @Test func candidateNormalizedNameMirrorsNormalization() {
        let candidate = CardScanCandidate(confidence: 0.8, text: "  Black   Lotus ")
        #expect(candidate.normalizedName == "black lotus")
    }
}

// MARK: - Stability voting

@Suite("Scan Stability Voting")
struct ScanStabilityTests {
    @Test func requiresThreeConsecutiveFrames() {
        let vm = makeViewModel()
        let candidates = [CardScanCandidate(confidence: 0.9, text: "Lightning Bolt")]

        #expect(vm.stableBest(from: candidates) == nil)
        #expect(vm.stableBest(from: candidates) == nil)
        #expect(vm.stableBest(from: candidates)?.normalizedName == "lightning bolt")
    }

    @Test func nameChangeResetsVote() {
        let vm = makeViewModel(minimumStableFrames: 3)
        let bolt = [CardScanCandidate(confidence: 0.9, text: "Lightning Bolt")]
        let counterspell = [CardScanCandidate(confidence: 0.9, text: "Counterspell")]

        vm.stableBest(from: bolt)
        vm.stableBest(from: bolt)
        vm.stableBest(from: bolt)

        vm.stableBest(from: counterspell)
        #expect(vm.stableFrames == 1)
        #expect(vm.stableBest(from: counterspell) == nil)
        #expect(vm.stableBest(from: counterspell)?.normalizedName == "counterspell")
    }

    @Test func emptyFrameResetsVote() {
        let vm = makeViewModel(minimumStableFrames: 2)
        let bolt = [CardScanCandidate(confidence: 0.9, text: "Lightning Bolt")]

        vm.stableBest(from: bolt)
        vm.stableBest(from: [])

        #expect(vm.stableName == nil)
        #expect(vm.stableFrames == 0)

        // The vote needs to be rebuilt from scratch after the empty frame.
        vm.stableBest(from: bolt)
        #expect(vm.stableBest(from: bolt)?.normalizedName == "lightning bolt")
    }
}

// MARK: - Detection pipeline

@Suite("Scan Detection Pipeline", .serialized)
struct CardScanningPipelineTests {
    @Test func detectsCardAfterStableFramesAndResolves() async {
        let vm = makeViewModel(scanner: makeScanner(boltCard))
        vm.enterScanningForTesting()

        vm.processFrame(makeImage())
        vm.processFrame(makeImage())
        vm.processFrame(makeImage())

        await vm.resolutionTask?.value

        #expect(vm.phase == .detected(ScannedCard(card: boltCard)))
        #expect(vm.quantity == 1)
    }

    @Test func keepsScanningWhenResolutionReturnsNoCard() async {
        let vm = makeViewModel(scanner: makeScanner(nil))
        vm.enterScanningForTesting()

        vm.processFrame(makeImage())
        vm.processFrame(makeImage())
        vm.processFrame(makeImage())

        await vm.resolutionTask?.value

        #expect(vm.phase == .scanning)
    }

    @Test func ignoresFramesWithinThrottleWindow() {
        let vm = makeViewModel(minimumStableFrames: 1, scanThrottle: 1000)
        vm.enterScanningForTesting()

        vm.processFrame(makeImage())
        #expect(vm.stableFrames == 1)

        vm.processFrame(makeImage())
        #expect(vm.stableFrames == 1)
    }
}

// MARK: - Collection persistence

@Suite("Scan Collection Persistence")
struct CardScanningPersistenceTests {
    @Test func addsResolvedCardToCollection() async throws {
        let store = MockDataStore(seed: false)
        let vm = makeViewModel(scanner: makeScanner(boltCard), store: store)
        vm.enterScanningForTesting()

        vm.processFrame(makeImage())
        vm.processFrame(makeImage())
        vm.processFrame(makeImage())
        await vm.resolutionTask?.value

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
        let vm = makeViewModel(scanner: makeScanner(boltCard), store: store)
        vm.enterScanningForTesting()

        vm.processFrame(makeImage())
        vm.processFrame(makeImage())
        vm.processFrame(makeImage())
        await vm.resolutionTask?.value
        vm.quantity = 1
        await vm.addToCollection()

        vm.processFrame(makeImage())
        vm.processFrame(makeImage())
        vm.processFrame(makeImage())
        await vm.resolutionTask?.value
        vm.quantity = 2
        await vm.addToCollection()

        let saved = try await store.allCollection()
        #expect(saved.count == 1)
        #expect(saved[0].quantity == 3)
    }

    @Test func keepsDistinctCardsSeparate() async throws {
        let store = MockDataStore(seed: false)

        let vmStock = makeViewModel(scanner: makeScanner(boltCard), store: store)
        vmStock.enterScanningForTesting()
        vmStock.processFrame(makeImage())
        vmStock.processFrame(makeImage())
        vmStock.processFrame(makeImage())
        await vmStock.resolutionTask?.value
        await vmStock.addToCollection()

        let vmCounterspell = makeViewModel(scanner: makeScanner(counterspellCard), store: store)
        vmCounterspell.enterScanningForTesting()
        vmCounterspell.processFrame(makeImage())
        vmCounterspell.processFrame(makeImage())
        vmCounterspell.processFrame(makeImage())
        await vmCounterspell.resolutionTask?.value
        await vmCounterspell.addToCollection()

        let saved = try await store.allCollection()
        #expect(saved.count == 2)
        #expect(Set(saved.map(\.cardName)) == Set(["Lightning Bolt", "Counterspell"]))
    }

    @Test func retryAfterFailedSaveRestoresDetectedCard() async {
        let store = FailingMockDataStore()
        let vm = makeViewModel(scanner: makeScanner(boltCard), store: store)
        vm.enterScanningForTesting()

        vm.processFrame(makeImage())
        vm.processFrame(makeImage())
        vm.processFrame(makeImage())
        await vm.resolutionTask?.value

        await vm.addToCollection()

        var isError = false
        if case .error = vm.phase { isError = true }
        #expect(isError)

        vm.retry()
        #expect(vm.phase == .detected(ScannedCard(card: boltCard)))
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