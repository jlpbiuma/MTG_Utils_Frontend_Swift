import Foundation
import Observation

// MARK: - EDHREC recommendations view model

@Observable
@MainActor
final class EdhrecViewModel {
    private(set) var result: EdhrecRecommendationsResult?
    private(set) var isLoading = false
    private(set) var selectedCategory: String?

    private let client: EdhrecClient
    private let deckCards: [DeckCard]
    var collection: [CollectionCard]
    private let commanderName: String

    init(
        client: EdhrecClient,
        commanderName: String,
        deckCards: [DeckCard],
        collection: [CollectionCard]
    ) {
        self.client = client
        self.commanderName = commanderName
        self.deckCards = deckCards
        self.collection = collection
    }

    var categories: [String] {
        result?.categories ?? []
    }

    /// Recommendations filtered by the selected EDHREC section, enriched with
    /// deck/collection ownership.
    var recommendations: [EdhrecCardRecommendation] {
        guard let result else { return [] }
        let inDeck = Set(
            deckCards.map { normalizeCardName($0.cardName) } + (result.commanderName.map { [normalizeCardName($0)] } ?? [])
        )
        let inCollection = Dictionary(
            grouping: collection,
            by: { normalizeCardName($0.cardName) }
        )
        .mapValues { lines in lines.reduce(0) { $0 + $1.quantity } }

        return result.recommendations
            .filter { recommendation in
                guard let selectedCategory else { return true }
                return recommendation.category == selectedCategory
            }
            .map { rec in
                let collectionQty = inCollection[rec.normalizedName] ?? 0
                return EdhrecCardRecommendation(
                    id: rec.id,
                    name: rec.name,
                    normalizedName: rec.normalizedName,
                    sanitized: rec.sanitized,
                    category: rec.category,
                    numDecks: rec.numDecks,
                    potentialDecks: rec.potentialDecks,
                    inclusionPct: rec.inclusionPct,
                    synergy: rec.synergy,
                    imageUri: rec.imageUri,
                    isInDeck: inDeck.contains(rec.normalizedName),
                    isInCollection: collectionQty > 0,
                    collectionQuantity: collectionQty
                )
            }
    }

    func load(commanderName: String) async {
        guard !commanderName.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await client.recommendations(for: commanderName)
            result = EdhrecRecommendationsResult(
                hasCommander: response.commander != nil,
                commanderName: response.commander?.name,
                commanderImageUri: response.commander?.imageUri,
                commanderScryfallId: nil,
                numDecks: response.commander?.numDecks,
                colorIdentity: response.commander?.colorIdentity,
                categories: response.categories,
                recommendations: response.cards.map { rec in
                    EdhrecCardRecommendation(
                        id: rec.id,
                        name: rec.name,
                        normalizedName: rec.normalizedName,
                        sanitized: rec.sanitized,
                        category: rec.category,
                        numDecks: rec.numDecks,
                        potentialDecks: rec.potentialDecks,
                        inclusionPct: rec.inclusionPct,
                        synergy: rec.synergy,
                        imageUri: rec.imageUri,
                        isInDeck: false,
                        isInCollection: false,
                        collectionQuantity: 0
                    )
                },
                error: nil
            )
        } catch {
            result = EdhrecRecommendationsResult(
                hasCommander: true,
                commanderName: commanderName,
                commanderImageUri: nil,
                commanderScryfallId: nil,
                numDecks: nil,
                colorIdentity: nil,
                categories: [],
                recommendations: [],
                error: "No se pudo conectar con EDHREC: \(error.localizedDescription)"
            )
        }
    }
}