import Foundation

private actor ScryfallRequestGate {
    private var inFlight = false

    func acquire() async {
        while inFlight {
            try? await Task.sleep(for: .milliseconds(50))
        }
        inFlight = true
    }

    func release() { inFlight = false }
}

// MARK: - Scryfall live client

/// Thin client over the public Scryfall API. No API key required.
/// See https://scryfall.com/docs/api
final class ScryfallClient {
    static let shared = ScryfallClient()

    private let baseURL = URL(string: "https://api.scryfall.com")!
    private let session: URLSession
    private let requestGate = ScryfallRequestGate()

    private let maxRateLimitRetries = 3

    /// SwiftUI views and view models use `shared`; tests inject a URLSession backed
    /// by a `URLProtocol` mock to exercise request/response handling offline.
    init(session: URLSession = ScryfallClient.makeDefaultSession()) {
        self.session = session
    }

    static func makeDefaultSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.urlCache = URLCache.shared
        return URLSession(configuration: config)
    }

    // Very light throttling + small wait for robots.txt friendliness.
    func search(query: String, page: Int = 1, order: String? = nil) async throws -> ScryfallSearchResult {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return ScryfallSearchResult(totalCards: 0, hasMore: false, data: []) }

        var components = URLComponents(url: baseURL.appendingPathComponent("cards/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "page", value: String(page)),
        ]
        if let order {
            components.queryItems?.append(URLQueryItem(name: "order", value: order))
        }

        let (data, response) = try await session.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, http.statusCode < 400 else {
            return ScryfallSearchResult(totalCards: 0, hasMore: false, data: [])
        }
        guard !data.isEmpty else { return ScryfallSearchResult(totalCards: 0, hasMore: false, data: []) }

        let scryfallResponse = try JSONDecoder().decode(ScryfallSearchResponse.self, from: data)
        return ScryfallSearchResult(
            totalCards: scryfallResponse.totalCards,
            hasMore: scryfallResponse.hasMore,
            data: scryfallResponse.data
        )
    }

    func autocomplete(_ prefix: String) async throws -> [String] {
        let trimmed = prefix.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        var components = URLComponents(url: baseURL.appendingPathComponent("cards/autocomplete"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "q", value: trimmed)]

        let (data, _) = try await session.data(from: components.url!)
        let response = try JSONDecoder().decode(ScryfallAutocompleteResponse.self, from: data)
        return response.data
    }

    /// Fetches a single card by (fuzzy or exact) name, including `color_identity`.
    func namedCard(name: String, exact: Bool = false) async throws -> ScryfallCard? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        var components = URLComponents(url: baseURL.appendingPathComponent("cards/named"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: exact ? "exact" : "fuzzy", value: trimmed)]

        let (data, response) = try await requestWithRateLimitRetry(url: components.url!)
        guard let http = response as? HTTPURLResponse, http.statusCode < 400, !data.isEmpty else { return nil }
        return try JSONDecoder().decode(ScryfallCard.self, from: data)
    }

    /// Resolves card names to precise card metadata using exact-name search.
    /// Returns only matches (a failed lookup for one name is skipped), and includes
    /// `pending:<name>` placeholders when a name can't be resolved so the caller
    /// can fall back gracefully.
    func resolveCards(named names: [String]) async throws -> [ResolvedCardData] {
        var results: [ResolvedCardData] = []
        // A deck often contains the same card in multiple sections/quantities.
        // Resolve each distinct name once to avoid needless Scryfall requests.
        var seen = Set<String>()
        for name in names {
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let key = normalizeCardName(trimmed)
            guard seen.insert(key).inserted else { continue }

            var components = URLComponents(url: baseURL.appendingPathComponent("cards/search"), resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "q", value: "!\"\(trimmed)\"")]

            do {
                let (data, response) = try await requestWithRateLimitRetry(url: components.url!)
                guard let http = response as? HTTPURLResponse, http.statusCode < 400, !data.isEmpty else {
                    results.append(placeholder(named: trimmed))
                    continue
                }
                let scryfallResponse = try JSONDecoder().decode(ScryfallSearchResponse.self, from: data)
                if let card = scryfallResponse.data.first {
                    results.append(
                        ResolvedCardData(
                            scryfallId: card.id,
                            name: card.name,
                            manaCost: card.displayManaCost,
                            typeLine: card.displayTypeLine,
                            imageUri: card.displayImageUri,
                            set: card.set,
                            collectorNumber: card.collectorNumber
                        )
                    )
                } else {
                    results.append(placeholder(named: trimmed))
                }
            } catch {
                results.append(placeholder(named: trimmed))
            }
        }
        return results
    }

    private func requestWithRateLimitRetry(url: URL) async throws -> (Data, URLResponse) {
        var attempt = 0
        while true {
            await requestGate.acquire()
            let result: (Data, URLResponse)
            do {
                result = try await session.data(from: url)
            } catch {
                await requestGate.release()
                throw error
            }
            await requestGate.release()
            guard let http = result.1 as? HTTPURLResponse, http.statusCode == 429 else { return result }
            guard attempt < maxRateLimitRetries else { return result }

            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init)
            let delay = retryAfter ?? pow(2.0, Double(attempt + 1))
            attempt += 1
            try await Task.sleep(for: .seconds(delay))
        }
    }

    private func placeholder(named name: String) -> ResolvedCardData {
        ResolvedCardData(
            scryfallId: "pending:\(normalizeCardName(name))",
            name: name,
            manaCost: nil,
            typeLine: nil,
            imageUri: nil,
            set: nil,
            collectorNumber: nil
        )
    }
}
