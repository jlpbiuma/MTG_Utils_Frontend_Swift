import Foundation
@testable import mtg_utils

// MARK: - Fixture loader

enum Fixtures {
    /// The running xctest bundle (resources were copied as bundle resources).
    private static var testBundle: Bundle {
        Bundle.allBundles.first { $0.bundleURL.pathExtension == "xctest" } ?? .main
    }

    static func load(_ name: String) throws -> String {
        guard let url = testBundle.url(forResource: name, withExtension: "txt") else {
            throw FixtureError.missing(name)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

enum FixtureError: Error, CustomStringConvertible {
    case missing(String)

    var description: String {
        switch self {
        case let .missing(name): return "Missing fixture \(name).txt in test bundle resources"
        }
    }
}

// MARK: - GroupableCard dummy (for groupCardsByType tests)

/// Minimal GroupableCard so grouping/stats tests don't depend on full models.
struct TestGroupableCard: GroupableCard {
    var cardName: String
    var cardScryfallId: String
    var typeLine: String?
    var quantity: Int
    var ownedInCollection: Int
    var missingCount: Int

    init(
        cardName: String,
        cardScryfallId: String,
        typeLine: String? = nil,
        quantity: Int,
        ownedInCollection: Int,
        missingCount: Int
    ) {
        self.cardName = cardName
        self.cardScryfallId = cardScryfallId
        self.typeLine = typeLine
        self.quantity = quantity
        self.ownedInCollection = ownedInCollection
        self.missingCount = missingCount
    }
}

// MARK: - SortableCard dummy (for sortCards tests)

struct TestSortableCard: SortableCard {
    var name: String
    var manaCost: String?
    var cmc: Double?
    var typeLine: String?
    var price: Double
    var colors: [String]
    var category: CardTypeCategory

    init(
        name: String,
        manaCost: String? = nil,
        cmc: Double? = nil,
        typeLine: String? = nil,
        price: Double = 0,
        colors: [String] = [],
        category: CardTypeCategory = .other
    ) {
        self.name = name
        self.manaCost = manaCost
        self.cmc = cmc
        self.typeLine = typeLine
        self.price = price
        self.colors = colors
        self.category = category
    }
}

// MARK: - Price summary builder

func makePriceSummary(
    trending: [String: Double],
    symbol: String = "€",
    totalCards: Int = 10,
    totalNetValue: Double = 100
) -> PriceSummary {
    var quotes: [String: CardPriceQuote] = [:]
    for (scryfallId, trend) in trending {
        quotes[scryfallId] = CardPriceQuote(
            cardName: scryfallId,
            scryfallId: scryfallId,
            provider: .cardmarket,
            currency: "EUR",
            currencySymbol: symbol,
            unitPrice: UnitPriceBreakdown(trend: trend, min: trend * 0.8, max: trend * 1.5),
            quantity: 1,
            subtotal: trend,
            purchaseUrl: nil,
            lastUpdated: Date()
        )
    }
    return PriceSummary(
        provider: .cardmarket,
        currency: "EUR",
        currencySymbol: symbol,
        totalCards: totalCards,
        totalNetValue: totalNetValue,
        totalOwnedValue: nil,
        totalMissingValue: nil,
        quotes: quotes
    )
}