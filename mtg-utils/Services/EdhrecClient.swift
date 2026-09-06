import Foundation

// MARK: - EDHREC live client

/// Fetches commander recommendations from json.edhrec.com.
/// Response JSON is nested and inconsistent between card types, so we decode
/// leniently and fall back to empty results on failure.
actor EdhrecClient {
    static let shared = EdhrecClient()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .useProtocolCachePolicy
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config)
    }()

    private var cache: [String: EdhrecCommanderResponse] = [:]
    private let cacheTTL: TimeInterval = 24 * 60 * 60 // 24h

    /// Returns recommendations for a commander, using a warmed 24h in-memory cache.
    func recommendations(for commander: String) async throws -> EdhrecCommanderResponse {
        let key = normalizeCardName(commander)
        if let cached = cache[key] { return cached }

        let url = edhrecJsonUrl(for: commander)
        guard let url else {
            return EdhrecCommanderResponse(commander: nil, categories: [], cards: [])
        }

        // Load raw JSON dict for flexibility.
        let (data, _) = try await session.data(from: url)

        let commanderInfo = try await parseCommander(from: data, commander: commander, key: key)
        let categories = try Self.sectionHeaders(from: data)
        let cards = try Self.parseCards(from: data)

        let response = EdhrecCommanderResponse(
            commander: commanderInfo,
            categories: categories,
            cards: cards
        )
        cache[key] = response
        return response
    }

    private func parseCommander(
        from data: Data,
        commander: String,
        key: String
    ) async throws -> EdhrecCommanderInfo? {
        let payload = try? JSONDecoder().decode(EdhrecPayload.self, from: data)
        let raw = payload?.container?.jsonDict?.card

        return EdhrecCommanderInfo(
            name: raw?.name ?? commander,
            id: raw?.id ?? key,
            imageUri: raw?.imageUris?.first?.normal,
            numDecks: raw?.numDecks ?? 0,
            colorIdentity: raw?.colorIdentity ?? [],
            typeLine: raw?.typeLine ?? "Legendary Creature"
        )
    }

    private static func sectionHeaders(from data: Data) -> [String] {
        guard let top = try? JSONSerialization.jsonObject(with: data),
              let dict = top as? [String: Any],
              let container = dict["container"] as? [String: Any],
              let jsonDict = container["json_dict"] as? [String: Any],
              let cardlists = jsonDict["cardlists"] as? [[String: Any]] else {
            return []
        }
        return cardlists.compactMap { $0["header"] as? String }
    }

    private static func parseCards(from data: Data) -> [EdhrecParsedCard] {
        guard let top = try? JSONSerialization.jsonObject(with: data),
              let dict = top as? [String: Any],
              let container = dict["container"] as? [String: Any],
              let jsonDict = container["json_dict"] as? [String: Any],
              let cardlists = jsonDict["cardlists"] as? [[String: Any]] else {
            return []
        }

        var results: [EdhrecParsedCard] = []
        var seen: Set<String> = []

        for cardlist in cardlists {
            let category = (cardlist["header"] as? String) ?? (cardlist["tag"] as? String) ?? "Otros"
            guard let cardviews = cardlist["cardviews"] as? [[String: Any]] else { continue }

            for view in cardviews {
                guard let name = view["name"] as? String else { continue }
                let normalized = normalizeCardName(name)
                guard !seen.contains(normalized) else { continue }
                seen.insert(normalized)

                let sanitized = (view["sanitized"] as? String) ?? normalized
                let numDecks = view["num_decks"] as? Int ?? 0
                let potentialDecks = view["potential_decks"] as? Int ?? 0
                let inclusionPct = potentialDecks > 0 ? (Double(numDecks) / Double(potentialDecks)) * 100 : 0
                var synergy = view["synergy"] as? Double ?? 0
                if synergy == 0, let synergyString = view["synergy"] as? String {
                    synergy = Double(synergyString) ?? 0
                }

                results.append(
                    EdhrecParsedCard(
                        id: (view["id"] as? String) ?? normalized,
                        name: name,
                        normalizedName: normalized,
                        sanitized: sanitized,
                        category: category,
                        categories: [category],
                        numDecks: numDecks,
                        potentialDecks: potentialDecks,
                        inclusionPct: inclusionPct,
                        synergy: synergy,
                        imageUri: nil
                    )
                )
            }
        }

        return results
    }
}