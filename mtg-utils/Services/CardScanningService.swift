import Foundation

// MARK: - Backend card-scan models (`POST /api/cards/from-image`)

struct CardScanCatalogInfo: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let normalizedName: String
    let manaCost: String?
    let typeLine: String?
    let imageUri: String?
}

struct CardScanPrintingInfo: Codable, Hashable, Sendable {
    let id: String
    let catalogId: String?
    let setCode: String?
    let collectorNumber: String?
    let imageUri: String?
    let priceEur: Double?
    let priceCardmarketTrend: Double?
}

struct CardScanAlternativeInfo: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let matchScore: Int
    let setCode: String?
    let collectorNumber: String?
    let imageUri: String?
}

/// Match returned by the MTG Utils backend after OCR + catalog resolve.
struct CardScanMatch: Codable, Hashable, Sendable {
    let ocrTitle: String
    let matchScore: Int
    let catalog: CardScanCatalogInfo
    let printing: CardScanPrintingInfo?
    let alternatives: [CardScanAlternativeInfo]

    var resolvedId: String { printing?.id ?? catalog.id }
    var name: String { catalog.name }
    var setCode: String? { printing?.setCode }
    var collectorNumber: String? { printing?.collectorNumber ?? nil }
    var manaCost: String? { catalog.manaCost }
    var typeLine: String? { catalog.typeLine }
    var imageUri: String? { printing?.imageUri ?? catalog.imageUri }
    var imageUrl: URL? { AppConfiguration.imageURL(from: imageUri) }
}

/// UI-facing wrapper around a backend card-scan match.
struct ScannedCard: Identifiable, Hashable {
    let match: CardScanMatch

    var id: String { match.resolvedId }
    var name: String { match.name }
    var setCode: String? { match.setCode }
    var collectorNumber: String? { match.collectorNumber }
    var manaCost: String? { match.manaCost }
    var typeLine: String? { match.typeLine }
    var imageUri: String? { match.imageUri }
    var imageUrl: URL? { match.imageUrl }
}

// MARK: - Resolver protocol

/// Uploads a card photo and resolves it through the general API (OCR home + catalog).
protocol CardScanResolving: Sendable {
    func resolve(imageJPEG: Data) async throws -> CardScanMatch
}

struct BackendCardScanResolver: CardScanResolving {
    let client: BackendClient
    var accessToken: String?
    var userId: String?

    func resolve(imageJPEG: Data) async throws -> CardScanMatch {
        try await client.scanCardFromImage(
            imageJPEG: imageJPEG,
            userId: userId,
            accessToken: accessToken
        )
    }
}

/// Returns a canned match for previews and unit tests.
struct StubCardScanResolver: CardScanResolving {
    var match: CardScanMatch?
    var error: Error?

    func resolve(imageJPEG: Data) async throws -> CardScanMatch {
        if let error { throw error }
        guard let match else {
            throw BackendClientError.invalidResponse
        }
        return match
    }
}
