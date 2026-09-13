import CoreGraphics
import Vision

// MARK: - Scan result models

/// Raw text observation produced by the OCR model for a single camera frame.
struct CardScanCandidate: Hashable, Sendable {
    let confidence: Float
    let text: String
    /// Normalized lowercased name ready for fuzzy matching against Scryfall.
    var normalizedName: String { normalizeCardName(text) }
}

/// A card recognized from a camera frame, resolved against Scryfall.
struct ScannedCard: Identifiable, Hashable {
    let card: ScryfallCard
    var id: String { card.id }
    var name: String { card.name }
    var setCode: String? { card.set }
    var collectorNumber: String? { card.collectorNumber }
    var manaCost: String? { card.displayManaCost }
    var typeLine: String? { card.displayTypeLine }
    var imageUri: String? { card.displayImageUri }
    var imageUrl: URL? { card.displayImageUrl }
}

// MARK: - Scanning protocol

/// Injectable card scanner. The default implementation uses Apple Vision's
/// on-device OCR (VNRecognizeTextRequest) + Scryfall fuzzy name resolution.
protocol CardScanning {
    /// Runs OCR on a camera frame and returns ranked text candidates.
    func recognizeCard(in image: CGImage) -> [CardScanCandidate]
    /// Resolves a scanned text candidate into a concrete Scryfall card.
    func resolve(_ candidate: CardScanCandidate) async throws -> ScryfallCard?
}

// MARK: - Vision implementation

struct VisionCardScanService: CardScanning {
    var minimumConfidence: Float = 0.45
    /// Candidates with fewer characters than this are too noisy to resolve.
    var minimumNameLength = 3
    var resolver: ScryfallClient = .shared

    func recognizeCard(in image: CGImage) -> [CardScanCandidate] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }

        let candidates = (request.results ?? []).compactMap { observation -> CardScanCandidate? in
            guard let top = observation.topCandidates(1).first else { return nil }
            let candidate = CardScanCandidate(confidence: observation.confidence, text: top.string)
            guard candidate.confidence >= minimumConfidence else { return nil }
            return candidate
        }

        // Rank by confidence so the most likely name appears first.
        return candidates.sorted { $0.confidence > $1.confidence }
    }

    func resolve(_ candidate: CardScanCandidate) async throws -> ScryfallCard? {
        let name = candidate.normalizedName
        guard name.count >= minimumNameLength else { return nil }
        return try await resolver.namedCard(name: name)
    }
}

// MARK: - Stub for previews / tests

/// Returns canned scan results, used by SwiftUI previews and unit tests.
struct StubCardScanService: CardScanning {
    var candidates: [CardScanCandidate] = []
    var resolvedCard: ScryfallCard?

    func recognizeCard(in image: CGImage) -> [CardScanCandidate] {
        candidates
    }

    func resolve(_ candidate: CardScanCandidate) async throws -> ScryfallCard? {
        resolvedCard
    }
}