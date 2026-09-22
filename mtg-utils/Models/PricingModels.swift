import Foundation

// MARK: - Pricing cache policy

/// Pricing quotes are considered fresh for exactly 3 days (259,200,000 ms),
/// matching the web app's `CACHE_TTL_MS`. Refreshed by the unified worker.
enum PricingCache {
    static let ttlMilliseconds: Double = 3 * 24 * 60 * 60 * 1000

    static func isValidTimestamp(_ timestamp: Double, now: Double = Date().timeIntervalSince1970 * 1000) -> Bool {
        let age = now - timestamp
        return age < ttlMilliseconds
    }
}

// MARK: - Pricing models

enum PriceProvider: String, CaseIterable, Identifiable, Hashable, Codable {
    case cardmarket
    case cardtrader
    case mtggoldfish

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cardmarket: return "Cardmarket (MKM)"
        case .cardtrader: return "Card Trader"
        case .mtggoldfish: return "MTGGoldfish"
        }
    }

    var logoText: String {
        switch self {
        case .cardmarket: return "MKM"
        case .cardtrader: return "CT"
        case .mtggoldfish: return "GF"
        }
    }

    var currency: String {
        switch self {
        case .cardmarket, .cardtrader: return "EUR"
        case .mtggoldfish: return "USD"
        }
    }

    var currencySymbol: String {
        switch self {
        case .cardmarket, .cardtrader: return "€"
        case .mtggoldfish: return "$"
        }
    }

    var description: String {
        switch self {
        case .cardmarket:
            return "Referencia europea líder con precios promedio, mínimo y máximo en Euros."
        case .cardtrader:
            return "Mercado global directo con cotizaciones de vendedores en tiempo real."
        case .mtggoldfish:
            return "Referencia de metajuego y mercado de papel estadounidense en Dólares."
        }
    }
}

struct UnitPriceBreakdown: Codable, Hashable {
    var trend: Double
    var min: Double
    var max: Double
}

struct CardPriceQuote: Codable, Hashable, Identifiable {
    var cardName: String
    var scryfallId: String?
    var provider: PriceProvider
    var currency: String
    var currencySymbol: String
    var unitPrice: UnitPriceBreakdown
    var quantity: Int
    var subtotal: Double
    var purchaseUrl: String?
    var lastUpdated: Date

    var id: String { scryfallId ?? cardName }
}

struct PriceSummary: Codable, Hashable {
    var provider: PriceProvider
    var currency: String
    var currencySymbol: String
    var totalCards: Int
    var totalNetValue: Double
    var totalOwnedValue: Double?
    var totalMissingValue: Double?
    var quotes: [String: CardPriceQuote]
    var lastUpdated: Date? = nil

    func quote(forCardScryfallId scryfallId: String, normalizedName: String) -> CardPriceQuote? {
        quotes[scryfallId] ?? quotes[normalizedName]
    }
}

/// Card payload accepted by `POST /api/pricing/cards`.
struct PricingCardInput: Codable, Hashable {
    let name: String
    let scryfallId: String?
    let quantity: Int
    let isMissing: Bool

    init(name: String, scryfallId: String? = nil, quantity: Int = 1, isMissing: Bool = false) {
        self.name = name
        self.scryfallId = scryfallId
        self.quantity = quantity
        self.isMissing = isMissing
    }
}

// MARK: - Price Movers

enum MoversScope: String, Codable, CaseIterable, Identifiable {
    case global
    case collection
    case wants

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .global: return "Mercado Global"
        case .collection: return "Mi Colección"
        case .wants: return "Mis Wants"
        }
    }
}

struct PriceMoverItem: Codable, Identifiable, Hashable {
    let printingId: String
    let catalogId: String?
    let cardName: String
    let setCode: String?
    let collectorNumber: String?
    let imageUri: String?
    let provider: PriceProvider
    let currency: String
    let currencySymbol: String
    let currentPrice: Double
    let baselinePrice: Double
    let changeAbs: Double
    let changePct: Double
    let baselineAt: Date
    let currentAt: Date

    var id: String { printingId }
}

struct PriceMoversResponse: Codable {
    let provider: PriceProvider
    let currency: String
    let currencySymbol: String
    let windowDays: Int
    let scope: MoversScope
    let gainers: [PriceMoverItem]
    let losers: [PriceMoverItem]
    let generatedAt: Date
}

// MARK: - Collection Value History

struct CollectionValueHistoryPoint: Codable, Identifiable, Hashable {
    let date: String
    let totalValue: Double
    let ownedCards: Int

    var id: String { date }
}

struct CollectionValueHistoryResponse: Codable {
    let provider: PriceProvider
    let currency: String
    let currencySymbol: String
    let currentValue: Double
    let points: [CollectionValueHistoryPoint]
}
