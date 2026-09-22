import Foundation

// MARK: - MTG Utils Backend client (FastAPI, v2.0.0 on localhost:8000)

/// Status payload returned by `GET /api/health`.
private struct BackendHealthResponse: Decodable {
    let status: String
    let service: String
    let version: String
}

/// User payload returned by the auth endpoints (camelCase, as Pydantic serializes).
struct BackendUserInfo: Decodable {
    let id: String
    let email: String
    let name: String
    let isAuthenticated: Bool
}

/// Response shape of `/api/auth/login`, `/api/auth/signup` and `/api/auth/refresh`.
struct BackendAuthResponse: Decodable {
    let user: BackendUserInfo?
    let accessToken: String?
    let refreshToken: String?
    let needsConfirmation: Bool
    let error: String?
}

/// Thin client for the MTG Utils FastAPI backend running at `http://localhost:8000`.
/// The backend proxies Scryfall (and later decks/collection/pricing) under `/api`.
final class BackendClient {
    static let shared = BackendClient()

    /// Guarda base URL para el desarrollo local; inyectable en tests.
    let baseURL: URL
    private let session: URLSession

    init(
        baseURL: URL = BackendClient.defaultBaseURL(),
        session: URLSession = BackendClient.makeDefaultSession()
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    static func defaultBaseURL() -> URL {
        AppConfiguration.backendBaseURL()
    }

    static func makeDefaultSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }

    // MARK: - Connectivity

    /// Verifies the backend is reachable and healthy.
    /// Returns true only when `GET /api/health` answers `{"status": "ok", ...}`.
    func checkHealth() async throws -> Bool {
        let url = baseURL.appendingPathComponent("api/health")
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return false }
        let status = try JSONDecoder().decode(BackendHealthResponse.self, from: data)
        return status.status == "ok"
    }

    // MARK: - Scryfall proxied endpoints

    /// `GET /api/scryfall/search` — same response shape as the public Scryfall API.
    func searchCards(query: String, page: Int = 1) async throws -> ScryfallSearchResult {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return ScryfallSearchResult(totalCards: 0, hasMore: false, data: []) }

        var components = URLComponents(url: baseURL.appendingPathComponent("api/scryfall/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "page", value: String(page)),
        ]

        let (data, response) = try await session.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, http.statusCode < 400 else {
            return ScryfallSearchResult(totalCards: 0, hasMore: false, data: [])
        }
        guard !data.isEmpty else { return ScryfallSearchResult(totalCards: 0, hasMore: false, data: []) }

        let decoded = try JSONDecoder().decode(ScryfallSearchResponse.self, from: data)
        return ScryfallSearchResult(totalCards: decoded.totalCards, hasMore: decoded.hasMore, data: decoded.data)
    }

    /// `GET /api/scryfall/autocomplete` — list of card name suggestions.
    /// The backend flattens the Scryfall `{"data": [...]}` envelope into a bare list.
    func autocomplete(_ prefix: String) async throws -> [String] {
        let trimmed = prefix.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        var components = URLComponents(url: baseURL.appendingPathComponent("api/scryfall/autocomplete"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "q", value: trimmed)]

        let (data, _) = try await session.data(from: components.url!)
        return try JSONDecoder().decode([String].self, from: data)
    }

    /// `GET /api/scryfall/named` — resolves a card by (fuzzy or exact) name.
    func namedCard(name: String, exact: Bool = false) async throws -> ScryfallCard? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        var components = URLComponents(url: baseURL.appendingPathComponent("api/scryfall/named"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "name", value: trimmed),
            URLQueryItem(name: "exact", value: exact ? "true" : "false"),
        ]

        let (data, response) = try await session.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, http.statusCode < 400, !data.isEmpty else { return nil }
        return try JSONDecoder().decode(ScryfallCard.self, from: data)
    }

    /// `GET /api/scryfall/card` — Spanish-localized full card details (oracle text,
    /// legalities, prices, faces, set/rarity). Backed by the backend's Scryfall proxy.
    func cardDetails(id: String? = nil, name: String? = nil) async throws -> SpanishCardDetails? {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/scryfall/card"), resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = []
        if let id, !id.isEmpty {
            items.append(URLQueryItem(name: "id", value: id))
        }
        if let name, !name.isEmpty {
            items.append(URLQueryItem(name: "name", value: name))
        }
        components.queryItems = items.isEmpty ? nil : items
        guard components.queryItems != nil else { return nil }

        let (data, response) = try await session.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, http.statusCode < 400, !data.isEmpty else { return nil }
        return try JSONDecoder().decode(SpanishCardDetails.self, from: data)
    }

    // MARK: - Auth endpoints

    // MARK: - Pricing endpoints

    /// `POST /api/pricing/cards`. The provider is sent on every request;
    /// Cardmarket is the default used by both clients and the backend.
    func cardPriceSummary(
        cards: [PricingCardInput],
        provider: PriceProvider = .cardmarket,
        forceRefresh: Bool = false,
        userId: String? = nil,
        accessToken: String? = nil
    ) async throws -> PriceSummary {
        try await pricingRequest(
            path: "api/pricing/cards",
            body: CardsPricingRequest(cards: cards, provider: provider.rawValue, forceRefresh: forceRefresh),
            userId: userId,
            accessToken: accessToken
        )
    }

    /// `POST /api/pricing/decks/{deckId}`. Prices the complete card set in a deck.
    func deckPriceSummary(
        deckId: String,
        provider: PriceProvider = .cardmarket,
        forceRefresh: Bool = false,
        userId: String? = nil,
        accessToken: String? = nil
    ) async throws -> PriceSummary {
        try await pricingRequest(
            path: "api/pricing/decks/\(deckId)?provider=\(provider.rawValue)&forceRefresh=\(forceRefresh)",
            body: EmptyRequest(),
            userId: userId,
            accessToken: accessToken
        )
    }

    private struct EmptyRequest: Encodable {}
    private struct CardsPricingRequest: Encodable {
        let cards: [PricingCardInput]
        let provider: String
        let forceRefresh: Bool
    }

    private func pricingRequest<T: Encodable>(
        path: String,
        body: T,
        userId: String?,
        accessToken: String?
    ) async throws -> PriceSummary {
        guard let requestURL = URL(string: "\(baseURL.absoluteString)/\(path)") else {
            throw BackendClientError.invalidResponse
        }
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let userId, !userId.isEmpty { request.setValue(userId, forHTTPHeaderField: "X-User-Id") }
        if let accessToken, !accessToken.isEmpty { request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BackendClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw BackendClientError.httpStatus(http.statusCode) }
        return try BackendDataStore.decoder.decode(PriceSummary.self, from: data)
    }

    /// `POST /api/auth/login` — validates credentials, returns an access token.
    func authLogin(email: String, password: String) async throws -> BackendAuthResponse {
        try await postAuth("api/auth/login", body: ["email": email, "password": password])
    }

    /// `POST /api/auth/signup` — creates an account (may require email confirmation).
    func authSignup(email: String, password: String) async throws -> BackendAuthResponse {
        try await postAuth("api/auth/signup", body: ["email": email, "password": password])
    }

    /// `POST /api/auth/refresh` — exchanges a refresh token for a fresh session.
    func authRefresh(refreshToken: String) async throws -> BackendAuthResponse {
        try await postAuth("api/auth/refresh", body: ["refreshToken": refreshToken])
    }

    /// `GET /api/auth/me` — current user for a valid access token.
    func authMe(accessToken: String) async throws -> BackendUserInfo? {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/auth/me"))
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode < 400, !data.isEmpty else { return nil }
        return try JSONDecoder().decode(BackendUserInfo.self, from: data)
    }

    /// `POST /api/auth/logout` — best-effort server-side logout.
    func logout(accessToken: String?) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/auth/logout"))
        request.httpMethod = "POST"
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        _ = try? await session.data(for: request)
    }

    private func postAuth(_ path: String, body: [String: String]) async throws -> BackendAuthResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            return BackendAuthResponse(user: nil, accessToken: nil, refreshToken: nil, needsConfirmation: false, error: "No se pudo contactar con el backend.")
        }
        guard http.statusCode < 500 else {
            return BackendAuthResponse(user: nil, accessToken: nil, refreshToken: nil, needsConfirmation: false, error: "Servicio de autenticación no disponible (HTTP \(http.statusCode)).")
        }
        guard !data.isEmpty else {
            return BackendAuthResponse(user: nil, accessToken: nil, refreshToken: nil, needsConfirmation: false, error: "El backend no devolvió una respuesta de autenticación.")
        }
        return try JSONDecoder().decode(BackendAuthResponse.self, from: data)
    }

    // MARK: - Deck Actions

    func addMissingCardsToCollection(
        deckId: String,
        userId: String? = nil,
        accessToken: String? = nil
    ) async throws -> [String: AnyCodableValue] {
        try await executeRequest(
            path: "api/decks/\(deckId)/add-missing",
            method: "POST",
            userId: userId,
            accessToken: accessToken
        )
    }

    func addMissingCardToCollection(
        cardId: String,
        userId: String? = nil,
        accessToken: String? = nil
    ) async throws -> [String: AnyCodableValue] {
        try await executeRequest(
            path: "api/decks/cards/\(cardId)/add-missing",
            method: "POST",
            userId: userId,
            accessToken: accessToken
        )
    }

    func archiveDeck(
        deckId: String,
        archived: Bool,
        userId: String? = nil,
        accessToken: String? = nil
    ) async throws -> Bool {
        let queryItems = [URLQueryItem(name: "archived", value: String(archived))]
        let _: [String: AnyCodableValue] = try await executeRequest(
            path: "api/decks/\(deckId)/archive",
            method: "PATCH",
            queryItems: queryItems,
            userId: userId,
            accessToken: accessToken
        )
        return true
    }

    func moveCardSideboard(
        cardId: String,
        isSideboard: Bool,
        userId: String? = nil,
        accessToken: String? = nil
    ) async throws -> Bool {
        struct MoveSideboardReq: Encodable { let isSideboard: Bool }
        let _: [String: AnyCodableValue] = try await executeRequest(
            path: "api/decks/cards/\(cardId)/sideboard",
            method: "PATCH",
            body: MoveSideboardReq(isSideboard: isSideboard),
            userId: userId,
            accessToken: accessToken
        )
        return true
    }

    // MARK: - Priorities & Wants Endpoints

    func priorities(
        sort: String = "demand",
        reassignableOnly: Bool = false,
        hideOwned: Bool = false,
        cardType: String? = nil,
        page: Int = 1,
        limit: Int = 30,
        provider: PriceProvider = .cardmarket,
        userId: String? = nil,
        accessToken: String? = nil
    ) async throws -> PrioritiesResponse {
        var queryItems = [
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "reassignableOnly", value: String(reassignableOnly)),
            URLQueryItem(name: "hideOwned", value: String(hideOwned)),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "provider", value: provider.rawValue),
        ]
        if let cardType, cardType != "all" {
            queryItems.append(URLQueryItem(name: "cardType", value: cardType))
        }
        return try await executeRequest(
            path: "api/priorities",
            method: "GET",
            queryItems: queryItems,
            userId: userId,
            accessToken: accessToken
        )
    }

    func reassignCard(
        sourceDeckId: String,
        targetDeckId: String,
        cardScryfallId: String,
        quantity: Int = 1,
        userId: String? = nil,
        accessToken: String? = nil
    ) async throws -> Bool {
        let body = DeckReassignRequest(
            sourceDeckId: sourceDeckId,
            targetDeckId: targetDeckId,
            cardScryfallId: cardScryfallId,
            quantity: quantity
        )
        let _: [String: String] = try await executeRequest(
            path: "api/decks/reassign",
            method: "POST",
            body: body,
            userId: userId,
            accessToken: accessToken
        )
        return true
    }

    func wantsQuery(
        query: String? = nil,
        sort: String = "name",
        direction: String = "asc",
        grouped: Bool = true,
        priceProvider: PriceProvider = .cardmarket,
        userId: String? = nil,
        accessToken: String? = nil
    ) async throws -> WantQueryResponse {
        var queryItems = [
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "direction", value: direction),
            URLQueryItem(name: "grouped", value: String(grouped)),
            URLQueryItem(name: "priceProvider", value: priceProvider.rawValue),
        ]
        if let query, !query.isEmpty {
            queryItems.append(URLQueryItem(name: "query", value: query))
        }
        return try await executeRequest(
            path: "api/wants/query",
            method: "GET",
            queryItems: queryItems,
            userId: userId,
            accessToken: accessToken
        )
    }

    func addWant(
        data: WantCardCreate,
        userId: String? = nil,
        accessToken: String? = nil
    ) async throws -> WantCardResponse {
        try await executeRequest(
            path: "api/wants/add-or-increment",
            method: "POST",
            body: data,
            userId: userId,
            accessToken: accessToken
        )
    }

    func updateWantQuantity(
        cardId: String,
        quantity: Int,
        setCode: String? = nil,
        userId: String? = nil,
        accessToken: String? = nil
    ) async throws -> WantCardResponse? {
        let body = WantCardUpdate(quantity: quantity, setCode: setCode)
        return try await executeRequest(
            path: "api/wants/\(cardId)",
            method: "PATCH",
            body: body,
            userId: userId,
            accessToken: accessToken
        )
    }

    func deleteWant(
        cardId: String,
        userId: String? = nil,
        accessToken: String? = nil
    ) async throws -> Bool {
        let _: [String: String] = try await executeRequest(
            path: "api/wants/\(cardId)",
            method: "DELETE",
            userId: userId,
            accessToken: accessToken
        )
        return true
    }

    func addDeckMissingToWants(
        deckId: String,
        userId: String? = nil,
        accessToken: String? = nil
    ) async throws -> Bool {
        let _: [String: String] = try await executeRequest(
            path: "api/wants/add-deck-missing/\(deckId)",
            method: "POST",
            userId: userId,
            accessToken: accessToken
        )
        return true
    }

    // MARK: - Collection Dormant & Simulated Collections

    func dormantCards(
        minPrice: Double = 0.0,
        provider: PriceProvider = .cardmarket,
        userId: String? = nil,
        accessToken: String? = nil
    ) async throws -> DormantCardsResponse {
        let queryItems = [
            URLQueryItem(name: "minPrice", value: String(minPrice)),
            URLQueryItem(name: "provider", value: provider.rawValue),
        ]
        return try await executeRequest(
            path: "api/collection/dormant",
            method: "GET",
            queryItems: queryItems,
            userId: userId,
            accessToken: accessToken
        )
    }

    func collectionQuery(
        query: String? = nil,
        sort: String = "name",
        direction: String = "asc",
        grouped: Bool = true,
        priceProvider: PriceProvider = .cardmarket,
        userId: String? = nil,
        accessToken: String? = nil
    ) async throws -> CollectionQueryResponse {
        var queryItems = [
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "direction", value: direction),
            URLQueryItem(name: "grouped", value: String(grouped)),
            URLQueryItem(name: "priceProvider", value: priceProvider.rawValue),
        ]
        if let query, !query.isEmpty {
            queryItems.append(URLQueryItem(name: "query", value: query))
        }
        return try await executeRequest(
            path: "api/collection/query",
            method: "GET",
            queryItems: queryItems,
            userId: userId,
            accessToken: accessToken
        )
    }

    func simulatedCollections(
        provider: PriceProvider = .cardmarket,
        userId: String? = nil,
        accessToken: String? = nil
    ) async throws -> [SimulatedCollectionSummary] {
        let queryItems = [URLQueryItem(name: "provider", value: provider.rawValue)]
        return try await executeRequest(
            path: "api/simulated-collections",
            method: "GET",
            queryItems: queryItems,
            userId: userId,
            accessToken: accessToken
        )
    }

    func executeSimulatedCollectionDetail(
        id: String,
        provider: PriceProvider = .cardmarket,
        userId: String? = nil,
        accessToken: String? = nil
    ) async throws -> SimulatedCollectionAnalysisResponse {
        let queryItems = [URLQueryItem(name: "provider", value: provider.rawValue)]
        return try await executeRequest(
            path: "api/simulated-collections/\(id)",
            method: "GET",
            queryItems: queryItems,
            userId: userId,
            accessToken: accessToken
        )
    }

    func analyzeSimulatedRaw(
        text: String,
        provider: PriceProvider = .cardmarket,
        userId: String? = nil,
        accessToken: String? = nil
    ) async throws -> SimulatedCollectionAnalysisResponse {
        let body = SimulatedCollectionAnalyzeRequest(rawText: text, provider: provider.rawValue)
        return try await executeRequest(
            path: "api/simulated-collections/analyze-raw",
            method: "POST",
            body: body,
            userId: userId,
            accessToken: accessToken
        )
    }

    func createSimulatedCollection(
        name: String,
        description: String? = nil,
        rawText: String,
        provider: PriceProvider = .cardmarket,
        userId: String? = nil,
        accessToken: String? = nil
    ) async throws -> SimulatedCollectionAnalysisResponse {
        let body = SimulatedCollectionCreateRequest(name: name, description: description, rawText: rawText)
        let queryItems = [URLQueryItem(name: "provider", value: provider.rawValue)]
        return try await executeRequest(
            path: "api/simulated-collections",
            method: "POST",
            queryItems: queryItems,
            body: body,
            userId: userId,
            accessToken: accessToken
        )
    }

    func deleteSimulatedCollection(
        collectionId: String,
        userId: String? = nil,
        accessToken: String? = nil
    ) async throws -> Bool {
        let _: [String: String] = try await executeRequest(
            path: "api/simulated-collections/\(collectionId)",
            method: "DELETE",
            userId: userId,
            accessToken: accessToken
        )
        return true
    }

    // MARK: - Price Movers & History Endpoints

    func priceMovers(
        provider: PriceProvider = .cardmarket,
        windowDays: Int = 30,
        limit: Int = 20,
        scope: MoversScope = .global,
        userId: String? = nil,
        accessToken: String? = nil
    ) async throws -> PriceMoversResponse {
        let queryItems = [
            URLQueryItem(name: "provider", value: provider.rawValue),
            URLQueryItem(name: "windowDays", value: String(windowDays)),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "scope", value: scope.rawValue),
        ]
        return try await executeRequest(
            path: "api/pricing/movers",
            method: "GET",
            queryItems: queryItems,
            userId: userId,
            accessToken: accessToken
        )
    }

    func collectionValueHistory(
        provider: PriceProvider = .cardmarket,
        days: Int = 30,
        userId: String? = nil,
        accessToken: String? = nil
    ) async throws -> CollectionValueHistoryResponse {
        let queryItems = [
            URLQueryItem(name: "provider", value: provider.rawValue),
            URLQueryItem(name: "days", value: String(days)),
        ]
        return try await executeRequest(
            path: "api/pricing/collection/history",
            method: "GET",
            queryItems: queryItems,
            userId: userId,
            accessToken: accessToken
        )
    }

    // MARK: - Generic HTTP Executor

    private func executeRequest<T: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem]? = nil,
        body: Encodable? = nil,
        userId: String? = nil,
        accessToken: String? = nil
    ) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if let queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let requestURL = components.url else { throw BackendClientError.invalidResponse }
        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let userId, !userId.isEmpty { request.setValue(userId, forHTTPHeaderField: "X-User-Id") }
        if let accessToken, !accessToken.isEmpty { request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization") }
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BackendClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw BackendClientError.httpStatus(http.statusCode) }
        return try BackendDataStore.decoder.decode(T.self, from: data)
    }
}

enum BackendClientError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "El backend devolvió una respuesta inválida."
        case .httpStatus(let status): return "El backend respondió con HTTP \(status)."
        }
    }
}

enum AnyCodableValue: Codable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .bool(let b): try container.encode(b)
        case .null: try container.encodeNil()
        }
    }
}
