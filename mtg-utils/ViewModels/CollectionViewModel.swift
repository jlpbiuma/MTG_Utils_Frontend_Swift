import Foundation
import Observation

// MARK: - Collection view model

@Observable
@MainActor
final class CollectionViewModel {
    private(set) var cards: [CollectionCard] = []
    private(set) var stats: CollectionStats = CollectionStats(uniqueCards: 0, totalCards: 0)
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var isCollectionSyncing = false

    var sortField: SortField = .cmc
    var sortDirection: SortDirection = .ascending
    var isGrouped = true
    var searchText = ""
    private(set) var priceSummary: PriceSummary?

    var currencySymbol: String {
        priceSummary?.currencySymbol ?? "€"
    }

    func price(for card: CollectionCard) -> Double {
        if let quote = priceSummary?.quote(forCardScryfallId: card.cardScryfallId, normalizedName: normalizeCardName(card.cardName)) {
            return quote.unitPrice.trend
        }
        return representativePrice(card.cardName, card.typeLine)
    }

    private let store: AppDataStoring
    private let priceProvider: PriceProvider
    private var collectionSyncTask: Task<Void, Never>?

    init(store: AppDataStoring, priceProvider: PriceProvider = .cardmarket) {
        self.store = store
        self.priceProvider = priceProvider
    }

    private var lastCardsCount: Int = -1
    private var lastSortField: SortField?
    private var lastSortDirection: SortDirection?
    private var lastSearchText: String?
    private var lastPriceSummary: PriceSummary?

    private var _cachedSorted: [CollectionCard] = []
    private var _cachedGroups: [GroupedCardSection<CollectionCard>] = []

    private func invalidateCacheIfNeeded() {
        if lastCardsCount != cards.count ||
           lastSortField != sortField ||
           lastSortDirection != sortDirection ||
           lastSearchText != searchText ||
           lastPriceSummary != priceSummary {

            var result = cards
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty {
                result = result.filter {
                    $0.cardName.localizedCaseInsensitiveContains(query) ||
                    ($0.typeLine?.localizedCaseInsensitiveContains(query) ?? false) ||
                    ($0.setCode?.localizedCaseInsensitiveContains(query) ?? false)
                }
            }
            _cachedSorted = sortCards(result, by: sortField, direction: sortDirection)
            _cachedGroups = groupCardsByType(_cachedSorted, priceSummary: priceSummary)

            lastCardsCount = cards.count
            lastSortField = sortField
            lastSortDirection = sortDirection
            lastSearchText = searchText
            lastPriceSummary = priceSummary
        }
    }

    var filtered: [CollectionCard] {
        invalidateCacheIfNeeded()
        return _cachedSorted
    }

    var sorted: [CollectionCard] {
        invalidateCacheIfNeeded()
        return _cachedSorted
    }

    var groups: [GroupedCardSection<CollectionCard>] {
        invalidateCacheIfNeeded()
        return _cachedGroups
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            cards = try await store.allCollection()
            rebuildDerivedValues()
            if let backend = store as? BackendDataStore {
                let requestCards = cards.map {
                    PricingCardInput(name: $0.cardName, scryfallId: $0.cardScryfallId, quantity: $0.quantity)
                }
                if let serverSummary = try? await backend.priceSummary(forCards: requestCards, provider: priceProvider) {
                    priceSummary = serverSummary
                }
            }
        } catch {
            errorMessage = "No se pudo cargar la colección: \(error.localizedDescription)"
        }
    }

    func addCards(_ newCards: [CollectionCard]) async throws {
        importCardsLocally(newCards)
    }

    func removeCard(id: String) async {
        let updatedCards = cards.filter { $0.id != id }
        await persist(updatedCards)
    }

    func updateEdition(id: String, setCode: String?) async {
        let cleanedSetCode = setCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let updatedCards = cards.map { card -> CollectionCard in
            guard card.id == id else { return card }
            var updated = card
            updated.setCode = cleanedSetCode?.isEmpty == true ? nil : cleanedSetCode
            return updated
        }
        await persist(updatedCards)
    }

    func updateQuantity(id: String, quantity: Int) async {
        guard quantity >= 1 else { return }
        let updatedCards = cards.map { card -> CollectionCard in
            guard card.id == id else { return card }
            var updated = card
            updated.quantity = quantity
            return updated
        }
        await persist(updatedCards)
    }

    private func persist(_ updatedCards: [CollectionCard]) async {
        do {
            try await store.saveCollection(updatedCards)
            cards = updatedCards
            rebuildDerivedValues()
        } catch {
            errorMessage = "No se pudo guardar la colección: \(error.localizedDescription)"
        }
    }

    /// Optimistic bulk import. This method never waits for the backend: it updates
    /// the visible collection and KPIs synchronously, then persists the snapshot
    /// in the background so the sheet can dismiss immediately.
    func importCardsLocally(_ newCards: [CollectionCard]) {
        var byKey: [String: CollectionCard] = [:]
        for card in cards {
            byKey["\(normalizeCardName(card.cardName))|\(card.setCode ?? "")"] = card
        }
        for card in newCards {
            let key = "\(normalizeCardName(card.cardName))|\(card.setCode ?? "")"
            if var existing = byKey[key] {
                existing.quantity += card.quantity
                byKey[key] = existing
            } else {
                byKey[key] = card
            }
        }
        cards = Array(byKey.values)
        rebuildDerivedValues()

        let snapshot = cards
        collectionSyncTask?.cancel()
        isCollectionSyncing = true
        collectionSyncTask = Task { [weak self, store] in
            do {
                try await store.saveCollection(snapshot)
                guard !Task.isCancelled else { return }
                self?.isCollectionSyncing = false
            } catch {
                guard !Task.isCancelled else { return }
                self?.isCollectionSyncing = false
                self?.errorMessage = "Las cartas se añadieron localmente, pero aún no se han sincronizado: \(error.localizedDescription)"
            }
        }
    }

    private func rebuildDerivedValues() {
        stats = CollectionStats(
            uniqueCards: cards.count,
            totalCards: cards.reduce(0) { $0 + $1.quantity }
        )

        var quotes: [String: CardPriceQuote] = [:]
        var totalVal = 0.0
        for card in cards {
            let trend = representativePrice(card.cardName, card.typeLine)
            let quote = CardPriceQuote(
                cardName: card.cardName,
                scryfallId: card.cardScryfallId,
                provider: priceProvider,
                currency: priceProvider.currency,
                currencySymbol: priceProvider.currencySymbol,
                unitPrice: UnitPriceBreakdown(trend: trend, min: trend * 0.85, max: trend * 1.15),
                quantity: card.quantity,
                subtotal: (trend * Double(card.quantity)).rounded2(),
                purchaseUrl: nil,
                lastUpdated: Date()
            )
            quotes[card.cardScryfallId] = quote
            quotes[normalizeCardName(card.cardName)] = quote
            totalVal += quote.subtotal
        }

        priceSummary = PriceSummary(
            provider: priceProvider,
            currency: priceProvider.currency,
            currencySymbol: priceProvider.currencySymbol,
            totalCards: stats.totalCards,
            totalNetValue: totalVal.rounded2(),
            quotes: quotes
        )
    }
}
