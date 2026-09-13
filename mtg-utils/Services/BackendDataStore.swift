import Foundation

// MARK: - MTG Utils backend data store (FastAPI on localhost:8000)

// The FastAPI backend owns the decks/collection persistence; the app no longer
// keeps a local in-memory copy (MockDataStore is only used for previews/tests).

// MARK: - Backend response payloads (camelCase keys, as Pydantic serializes)

struct BackendDeckSummary: Decodable {
    let id: String
    let userId: String
    let name: String
    let format: String
    let description: String?
    let commander: String?
    let commanderScryfallId: String?
    let commanderImageUri: String?
    let createdAt: Date
    let updatedAt: Date
    let totalCards: Int
    let uniqueCards: Int
    let ownedCards: Int
    let missingCards: Int
    let completionPercentage: Double
}

struct BackendOtherDeckAssignment: Decodable {
    let deckId: String
    let deckName: String
    let quantity: Int
}

struct BackendDeckCard: Decodable {
    let id: String
    let deckId: String
    let cardScryfallId: String
    let cardName: String
    let quantity: Int
    let assignedQuantity: Int
    let isSideboard: Bool
    let isCommander: Bool
    let manaCost: String?
    let typeLine: String?
    let imageUri: String?
    let setCode: String?
    let ownedInCollection: Int
    let availableToAssign: Int
    let assignedInOtherDecks: [BackendOtherDeckAssignment]
    let missingCount: Int
}

struct BackendDeckDetail: Decodable {
    let id: String
    let userId: String
    let name: String
    let format: String
    let description: String?
    let commander: String?
    let commanderScryfallId: String?
    let commanderImageUri: String?
    let createdAt: Date
    let updatedAt: Date
    let totalCards: Int
    let uniqueCards: Int
    let ownedCards: Int
    let missingCards: Int
    let completionPercentage: Double
    let cards: [BackendDeckCard]
}

struct BackendCollectionCard: Decodable {
    let id: String
    let userId: String
    let cardScryfallId: String
    let cardName: String
    let quantity: Int
    let setCode: String?
    let collectorNumber: String?
    let manaCost: String?
    let typeLine: String?
    let imageUri: String?
    let updatedAt: Date
}

// MARK: - Backend request payloads

private struct BackendDeckCreateRequest: Encodable {
    let name: String
    let format: String
    let description: String?
    let commander: String?
    let commanderScryfallId: String?
    let commanderImageUri: String?
}

private struct BackendDeckUpdateRequest: Encodable {
    var name: String?
    var format: String?
    var description: String?
    var commander: String?
    var commanderScryfallId: String?
    var commanderImageUri: String?
}

private struct BackendDeckCardRequest: Encodable {
    let cardScryfallId: String
    let cardName: String
    let quantity: Int
    let isSideboard: Bool
    let isCommander: Bool
    let manaCost: String?
    let typeLine: String?
    let imageUri: String?
    let setCode: String?

    init(from card: DeckCard) {
        cardScryfallId = card.cardScryfallId
        cardName = card.cardName
        quantity = card.quantity
        isSideboard = card.isSideboard
        isCommander = card.isCommander
        manaCost = card.manaCost
        typeLine = card.typeLine
        imageUri = card.imageUri
        setCode = card.setCode
    }
}

private struct BackendCollectionCardRequest: Encodable {
    let cardScryfallId: String
    let cardName: String
    let quantity: Int
    let setCode: String?
    let collectorNumber: String?
    let manaCost: String?
    let typeLine: String?
    let imageUri: String?

    init(from card: CollectionCard) {
        cardScryfallId = card.cardScryfallId
        cardName = card.cardName
        quantity = card.quantity
        setCode = card.setCode
        collectorNumber = card.collectorNumber
        manaCost = card.manaCost
        typeLine = card.typeLine
        imageUri = card.imageUri
    }
}

private struct BackendQuantityRequest: Encodable {
    let quantity: Int
}

private struct BackendCardUpdateRequest: Encodable {
    let quantity: Int
    let setCode: String?
}

private struct BackendStatusResponse: Decodable {
    let status: String
}

// MARK: - Store

enum BackendStoreError: LocalizedError {
    case badResponse(status: Int)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .badResponse(let status): return "El backend respondió con el estado HTTP \(status)."
        case .emptyResponse: return "El backend devolvió una respuesta vacía."
        }
    }
}

/// Persistence backed by the MTG Utils FastAPI backend. Deck/collection cards are
/// matched by (cardScryfallId, isSideboard) so client-created rows map cleanly onto
/// server rows even when the server generates its own primary keys.
final class BackendDataStore: AppDataStoring {
    /// Matches the backend's `DEMO_USER_ID` fallback.
    static let demoUserId = "00000000-0000-0000-0000-000000000000"

    private let client: BackendClient
    private let session: URLSession
    private var deckIDMap: [String: String] = [:]
    private var decksCache: (value: [Deck], date: Date)?
    private var collectionCache: (value: [CollectionCard], date: Date)?
    private let cacheLifetime: TimeInterval = 5

    /// User scope for `X-User-Id`; assigned when the user signs in.
    var userId: String

    /// Access token for `Authorization: Bearer`; assigned when the user signs in.
    var accessToken: String?

    init(
        client: BackendClient = .shared,
        session: URLSession = BackendDataStore.makeDefaultSession(),
        userId: String = BackendDataStore.demoUserId
    ) {
        self.client = client
        self.session = session
        self.userId = userId
    }

    /// Reads prices from the FastAPI pricing contract instead of calculating
    /// client-side estimates. The provider is always sent explicitly.
    func priceSummary(forDeckId deckId: String, provider: PriceProvider = .cardmarket, forceRefresh: Bool = false) async throws -> PriceSummary {
        try await sendJSON(
            PriceSummary.self,
            method: "POST",
            path: "api/pricing/decks/\(deckId)?provider=\(provider.rawValue)&forceRefresh=\(forceRefresh)",
            body: EmptyPricingRequest()
        )
    }

    func priceSummary(forCards cards: [PricingCardInput], provider: PriceProvider = .cardmarket, forceRefresh: Bool = false) async throws -> PriceSummary {
        try await sendJSON(
            PriceSummary.self,
            method: "POST",
            path: "api/pricing/cards",
            body: CardsPricingRequest(cards: cards, provider: provider.rawValue, forceRefresh: forceRefresh)
        )
    }

    static func makeDefaultSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config)
    }

    // MARK: AppDataStoring

    func allDecks() async throws -> [Deck] {
        if let cache = decksCache, Date().timeIntervalSince(cache.date) < cacheLifetime {
            return cache.value
        }
        let summaries = try await self.getJSON([BackendDeckSummary].self, at: "api/decks")
        var decks: [Deck] = []
        for summary in summaries {
            if let detail = try? await self.getJSON(BackendDeckDetail.self, at: "api/decks/\(summary.id)") {
                decks.append(Self.deck(from: detail))
            }
        }
        decksCache = (decks, Date())
        return decks
    }

    func allDeckSummaries() async throws -> [DeckSummary] {
        if let cache = decksCache, Date().timeIntervalSince(cache.date) < cacheLifetime {
            return cache.value.map { deck in
                DeckSummary(id: deck.id, userId: deck.userId, name: deck.name, format: deck.format, commander: deck.commander,
                            totalCards: deck.cards.filter { !$0.isCommander }.reduce(0) { $0 + $1.quantity },
                            uniqueCards: deck.cards.filter { !$0.isCommander }.count,
                            estimatedPrice: estimateDeckPrice(cards: deck.cards), colors: extractDeckColors(cards: deck.cards))
            }
        }
        let summaries = try await self.getJSON([BackendDeckSummary].self, at: "api/decks")
        return summaries.map(Self.deckSummary(from:))
    }

    func deckDetail(id: String) async throws -> DeckDetail? {
        guard let detail = try? await self.getJSON(BackendDeckDetail.self, at: "api/decks/\(id)") else {
            return nil
        }
        return Self.deckDetail(from: detail)
    }

    func saveDecks(_ decks: [Deck]) async throws {
        var remaining = try await fetchAllDeckDetails()
        for deck in decks {
            let mappedID = deckIDMap[deck.id] ?? deck.id
            if let index = remaining.firstIndex(where: { $0.id == mappedID }) {
                let existing = remaining.remove(at: index)
                try await updateDeck(server: existing, with: deck)
            } else {
                try await createDeckLocal(deck)
            }
        }
        for orphan in remaining {
            _ = try await sendStatus(method: "DELETE", path: "api/decks/\(orphan.id)")
            deckIDMap[orphan.id] = nil
        }
        decksCache = (decks, Date())
    }

    func allCollection() async throws -> [CollectionCard] {
        if let cache = collectionCache, Date().timeIntervalSince(cache.date) < cacheLifetime {
            return cache.value
        }
        let cards = try await self.getJSON([BackendCollectionCard].self, at: "api/collection")
        let result = cards.map(Self.collectionCard(from:))
        collectionCache = (result, Date())
        return result
    }

    func saveCollection(_ cards: [CollectionCard]) async throws {
        let server = try await self.getJSON([BackendCollectionCard].self, at: "api/collection")
        var keep: Set<String> = []

        for card in cards {
            if let existing = server.first(where: { $0.id == card.id }) {
                keep.insert(existing.id)
                if card.quantity <= 0 {
                    _ = try await sendStatus(method: "DELETE", path: "api/collection/\(existing.id)")
                } else if existing.quantity != card.quantity || existing.setCode != card.setCode {
                    _ = try await sendStatus(
                        method: "PATCH",
                        path: "api/collection/\(existing.id)",
                        body: BackendCardUpdateRequest(quantity: card.quantity, setCode: card.setCode)
                    )
                }
            } else {
                let created = try await self.sendJSON(
                    BackendCollectionCard.self,
                    method: "POST",
                    path: "api/collection/add-or-increment",
                    body: BackendCollectionCardRequest(from: card)
                )
                keep.insert(created.id)
            }
        }
        collectionCache = (cards, Date())

        for card in server where !keep.contains(card.id) {
            _ = try await sendStatus(method: "DELETE", path: "api/collection/\(card.id)")
        }
    }

    // MARK: Deck sync helpers

    private func fetchAllDeckDetails() async throws -> [BackendDeckDetail] {
        let summaries = try await self.getJSON([BackendDeckSummary].self, at: "api/decks")
        var details: [BackendDeckDetail] = []
        for summary in summaries {
            if let detail = try? await self.getJSON(BackendDeckDetail.self, at: "api/decks/\(summary.id)") {
                details.append(detail)
            }
        }
        return details
    }

    private func createDeckLocal(_ deck: Deck) async throws {
        let created = try await self.sendJSON(
            BackendDeckSummary.self,
            method: "POST",
            path: "api/decks",
            body: BackendDeckCreateRequest(
                name: deck.name,
                format: deck.format,
                description: deck.description,
                commander: deck.commander,
                commanderScryfallId: deck.commanderScryfallId,
                commanderImageUri: deck.commanderImageUri
            )
        )
        deckIDMap[deck.id] = created.id
        // The backend auto-creates the commander card; refetch to sync against reality.
        let detail = try? await self.getJSON(BackendDeckDetail.self, at: "api/decks/\(created.id)")
        if let detail {
            try await syncCards(localDeck: deck, server: detail, removeOmitted: false)
        }
    }

    private func updateDeck(server: BackendDeckDetail, with deck: Deck) async throws {
        var payload = BackendDeckUpdateRequest()
        var changed = false
        if deck.name != server.name { payload.name = deck.name; changed = true }
        if deck.format != server.format { payload.format = deck.format; changed = true }
        if deck.description != server.description { payload.description = deck.description ?? ""; changed = true }
        if deck.commander != server.commander {
            payload.commander = deck.commander ?? ""
            payload.commanderScryfallId = deck.commanderScryfallId ?? ""
            payload.commanderImageUri = deck.commanderImageUri ?? ""
            changed = true
        } else {
            if deck.commanderScryfallId != server.commanderScryfallId {
                payload.commanderScryfallId = deck.commanderScryfallId ?? ""; changed = true
            }
            if deck.commanderImageUri != server.commanderImageUri {
                payload.commanderImageUri = deck.commanderImageUri ?? ""; changed = true
            }
        }
        if changed {
            _ = try await sendStatus(method: "PUT", path: "api/decks/\(server.id)", body: payload)
        }
        try await syncCards(localDeck: deck, server: server, removeOmitted: true)
    }

    /// Matches deck cards to server rows by `(cardScryfallId, isSideboard)`; updates
    /// quantities, creates missing rows and (optionally) removes server rows dropped
    /// from the local deck.
    private func syncCards(localDeck: Deck, server: BackendDeckDetail, removeOmitted: Bool) async throws {
        let localCards = localDeck.cards
        let serverCards = server.cards
        var keepIDs: Set<String> = []

        for local in localCards {
            if let existing = serverCards.first(where: {
                $0.cardScryfallId == local.cardScryfallId && $0.isSideboard == local.isSideboard
            }) {
                keepIDs.insert(existing.id)
                if existing.quantity != local.quantity || existing.setCode != local.setCode {
                    _ = try await sendStatus(
                        method: "PATCH",
                        path: "api/decks/cards/\(existing.id)",
                        body: BackendCardUpdateRequest(quantity: local.quantity, setCode: local.setCode)
                    )
                }
            } else {
                _ = try await sendStatus(
                    method: "POST",
                    path: "api/decks/\(server.id)/cards",
                    body: BackendDeckCardRequest(from: local)
                )
            }
        }

        if removeOmitted {
            for card in serverCards where !keepIDs.contains(card.id) {
                _ = try await sendStatus(method: "DELETE", path: "api/decks/cards/\(card.id)")
            }
        }
    }

    // MARK: Mapping

    private static func deckSummary(from s: BackendDeckSummary) -> DeckSummary {
        DeckSummary(
            id: s.id,
            userId: s.userId,
            name: s.name,
            format: s.format,
            description: s.description,
            commander: s.commander,
            commanderScryfallId: s.commanderScryfallId,
            commanderImageUri: s.commanderImageUri,
            createdAt: s.createdAt,
            updatedAt: s.updatedAt,
            totalCards: s.totalCards,
            uniqueCards: s.uniqueCards,
            ownedCards: s.ownedCards,
            missingCardsCount: s.missingCards,
            completionPercentage: s.completionPercentage
        )
    }

    private static func deckDetail(from detail: BackendDeckDetail) -> DeckDetail {
        DeckDetail(
            id: detail.id,
            userId: detail.userId,
            name: detail.name,
            format: detail.format,
            description: detail.description,
            commander: detail.commander,
            commanderScryfallId: detail.commanderScryfallId,
            commanderImageUri: detail.commanderImageUri,
            createdAt: detail.createdAt,
            updatedAt: detail.updatedAt,
            totalCards: detail.totalCards,
            uniqueCards: detail.uniqueCards,
            ownedCards: detail.ownedCards,
            missingCardsCount: detail.missingCards,
            completionPercentage: detail.completionPercentage,
            cards: detail.cards.map { card in
                DeckCardWithOwnership(
                    id: card.id,
                    deckId: card.deckId,
                    cardScryfallId: card.cardScryfallId,
                    cardName: card.cardName,
                    quantity: card.quantity,
                    assignedQuantity: card.assignedQuantity,
                    isSideboard: card.isSideboard,
                    isCommander: card.isCommander,
                    manaCost: card.manaCost,
                    typeLine: card.typeLine,
                    imageUri: card.imageUri,
                    setCode: card.setCode,
                    ownedInCollection: card.ownedInCollection,
                    availableToAssign: card.availableToAssign,
                    assignedInOtherDecks: card.assignedInOtherDecks.map {
                        OtherDeckAssignment(deckId: $0.deckId, deckName: $0.deckName, quantity: $0.quantity)
                    },
                    missingCount: card.missingCount
                )
            }
        )
    }

    private static func deck(from detail: BackendDeckDetail) -> Deck {
        Deck(
            id: detail.id,
            userId: detail.userId,
            name: detail.name,
            format: detail.format,
            description: detail.description,
            commander: detail.commander,
            commanderScryfallId: detail.commanderScryfallId,
            commanderImageUri: detail.commanderImageUri,
            createdAt: detail.createdAt,
            updatedAt: detail.updatedAt,
            cards: detail.cards.map { card in
                DeckCard(
                    id: card.id,
                    deckId: card.deckId,
                    cardScryfallId: card.cardScryfallId,
                    cardName: card.cardName,
                    quantity: card.quantity,
                    assignedQuantity: card.assignedQuantity,
                    isSideboard: card.isSideboard,
                    isCommander: card.isCommander,
                    manaCost: card.manaCost,
                    typeLine: card.typeLine,
                    imageUri: card.imageUri,
                    setCode: card.setCode
                )
            }
        )
    }

    private static func collectionCard(from card: BackendCollectionCard) -> CollectionCard {
        CollectionCard(
            id: card.id,
            userId: card.userId,
            cardScryfallId: card.cardScryfallId,
            cardName: card.cardName,
            quantity: card.quantity,
            setCode: card.setCode,
            collectorNumber: card.collectorNumber,
            manaCost: card.manaCost,
            typeLine: card.typeLine,
            imageUri: card.imageUri
        )
    }

    // MARK: HTTP plumbing

    private struct EmptyPricingRequest: Encodable {}
    private struct CardsPricingRequest: Encodable {
        let cards: [PricingCardInput]
        let provider: String
        let forceRefresh: Bool
    }

    private func url(_ path: String) -> URL {
        // Preserve query strings (pricing deck endpoint uses provider and
        // forceRefresh) instead of percent-encoding them as path components.
        URL(string: "\(client.baseURL.absoluteString)/\(path)")!
    }

    private func makeRequest(method: String, path: String) -> URLRequest {
        var request = URLRequest(url: url(path))
        request.httpMethod = method
        request.setValue(userId, forHTTPHeaderField: "X-User-Id")
        if let accessToken, !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func getJSON<T: Decodable>(_ type: T.Type, at path: String) async throws -> T {
        let request = makeRequest(method: "GET", path: path)
        return try await performRequest(type, request: request)
    }

    private func sendJSON<T: Decodable>(_ type: T.Type, method: String, path: String, body: Encodable) async throws -> T {
        var request = makeRequest(method: method, path: path)
        request.httpBody = try JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await performRequest(type, request: request)
    }

    private func performRequest<T: Decodable>(_ type: T.Type, request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BackendStoreError.badResponse(status: -1)
        }
        guard (200..<400).contains(http.statusCode) else {
            throw BackendStoreError.badResponse(status: http.statusCode)
        }
        guard !data.isEmpty else {
            throw BackendStoreError.emptyResponse
        }
        return try Self.decoder.decode(T.self, from: data)
    }

    @discardableResult
    private func sendStatus(method: String, path: String, body: Encodable? = nil) async throws -> String {
        var request = makeRequest(method: method, path: path)
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) else {
            throw BackendStoreError.badResponse(status: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        guard !data.isEmpty else { return "" }
        return (try? Self.decoder.decode(BackendStatusResponse.self, from: data))?.status ?? ""
    }

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = isoDateFormatter.date(from: string) { return date }
            if let date = isoDateFormatterFractional.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "ISO8601 date inválida: \(string)"
            )
        }
        return decoder
    }()

    static let isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        return formatter
    }()

    static let isoDateFormatterFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
