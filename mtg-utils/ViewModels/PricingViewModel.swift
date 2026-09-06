import Foundation
import Observation

// MARK: - Pricing view model

@Observable
@MainActor
final class PricingViewModel {
    var selectedProvider: PriceProvider = .cardmarket
    private(set) var summary: PriceSummary?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// Marks the selected provider; quotes are recomputed when `load` runs.
    func selectProvider(_ provider: PriceProvider) {
        guard provider != selectedProvider else { return }
        selectedProvider = provider
    }

    func load(for deck: DeckDetail, collection: [CollectionCard]) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let ownedByNorm = Dictionary(grouping: collection, by: { normalizeCardName($0.cardName) })
            .mapValues { $0.reduce(0) { $0 + $1.quantity } }

        var quotes: [String: CardPriceQuote] = [:]
        for card in deck.cards {
            let trend = mockPrice(for: card)
            let quote = CardPriceQuote(
                cardName: card.cardName,
                scryfallId: card.cardScryfallId,
                provider: selectedProvider,
                currency: selectedProvider.currency,
                currencySymbol: selectedProvider.currencySymbol,
                unitPrice: UnitPriceBreakdown(trend: trend, min: trend * 0.85, max: trend * 1.15),
                quantity: card.quantity,
                subtotal: trend * Double(card.quantity),
                purchaseUrl: mockPurchaseURL(card: card, provider: selectedProvider),
                lastUpdated: Date()
            )
            quotes[card.cardScryfallId] = quote
        }

        var totalNet = 0.0
        var ownedValue = 0.0
        var missingValue = 0.0
        let ownedCount = ownedByNorm

        for card in deck.cards {
            guard let quote = quotes[card.cardScryfallId] else { continue }
            let norm = normalizeCardName(card.cardName)
            let owned = min(ownedCount[norm] ?? 0, card.quantity)
            let missing = max(0, card.quantity - owned)
            totalNet += quote.subtotal
            ownedValue += quote.unitPrice.trend * Double(owned)
            missingValue += quote.unitPrice.trend * Double(missing)
        }

        summary = PriceSummary(
            provider: selectedProvider,
            currency: selectedProvider.currency,
            currencySymbol: selectedProvider.currencySymbol,
            totalCards: deck.totalCards,
            totalNetValue: totalNet.rounded2(),
            totalOwnedValue: ownedValue.rounded2(),
            totalMissingValue: missingValue.rounded2(),
            quotes: quotes
        )
    }

    func selectProvider(_ provider: PriceProvider) async {
        guard provider != selectedProvider else { return }
        selectedProvider = provider
        if let summary, summary.totalCards > 0 {
            // Recompute currency labels for the new provider.
            var quotes: [String: CardPriceQuote] = [:]
            for (key, quote) in summary.quotes {
                var updated = quote
                updated.provider = provider
                updated.currency = provider.currency
                updated.currencySymbol = provider.currencySymbol
                quotes[key] = updated
            }
            self.summary = PriceSummary(
                provider: provider,
                currency: provider.currency,
                currencySymbol: provider.currencySymbol,
                totalCards: summary.totalCards,
                totalNetValue: summary.totalNetValue.rounded2(),
                totalOwnedValue: summary.totalOwnedValue?.rounded2(),
                totalMissingValue: summary.totalMissingValue?.rounded2(),
                quotes: quotes
            )
        }
    }

    // MARK: Demo pricing (Phase 3 replaces this with Cardmarket / Card Trader / MTGGoldfish).

    private func mockPrice(for card: DeckCardWithOwnership) -> Double {
        let rarityScore = representativePrice(card.cardName, card.typeLine)
        let foilBoost = 1.0
        return (rarityScore * foilBoost).rounded2()
    }

    private func mockPurchaseURL(card: DeckCardWithOwnership, provider: PriceProvider) -> String? {
        let slug = card.cardName.lowercased().replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression)
        switch provider {
        case .cardmarket:
            return "https://www.cardmarket.com/en/Magic/Products/Singles/\(slug)"
        case .cardtrader:
            return "https://www.cardtrader.com/magic/\(slug)"
        case .mtggoldfish:
            return "https://www.mtggoldfish.com/price/\(slug)#online"
        }
    }

    /// Deterministic pseudo-prices so the demo shows believable numbers.
    private func representativePrice(_ name: String, _ typeLine: String?) -> Double {
        let hash = abs(name.unicodeScalars.reduce(1) { ($0 &* 31 &+ Int($1.value)) &* 7 })
        let base = Double(hash % 45) / 10 + 0.20
        if name.localizedCaseInsensitiveContains("Snapcaster") { return 29.99 }
        if name.localizedCaseInsensitiveContains("Scalding Tarn") { return 24.50 }
        if name.localizedCaseInsensitiveContains("Cyclonic Rift") { return 3.99 }
        if name.localizedCaseInsensitiveContains("Chulane") { return 8.49 }
        if name.localizedCaseInsensitiveContains("Birds of Paradise") { return 7.90 }
        if let typeLine, typeLine.localizedCaseInsensitiveContains("Basic Land") { return 0.15 }
        if let typeLine, typeLine.localizedCaseInsensitiveContains("Land") { return 1.20 }
        return base
    }
}