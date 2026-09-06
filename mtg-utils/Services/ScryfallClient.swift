import Foundation

// MARK: - Scryfall live client

/// Thin client over the public Scryfall API. No API key required.
/// See https://scryfall.com/docs/api
final class ScryfallClient {
    static let shared = ScryfallClient()

    private let baseURL = URL(string: "https://api.scryfall.com")!
    private let session: URLSession

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

    /// Resolves card names to precise card metadata using exact-name search.
    /// Returns only matches (a failed lookup for one name is skipped), and includes
    /// `pending:<name>` placeholders when a name can't be resolved so the caller
    /// can fall back gracefully.
    func resolveCards(named names: [String]) async throws -> [ResolvedCardData] {
        var results: [ResolvedCardData] = []
        for name in names {
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            var components = URLComponents(url: baseURL.appendingPathComponent("cards/search"), resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "q", value: "!\"\(trimmed)\"")]

            do {
                let (data, response) = try await session.data(from: components.url!)
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