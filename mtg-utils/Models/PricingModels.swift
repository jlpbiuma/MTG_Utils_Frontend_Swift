import Foundation

// MARK: - Pricing cache policy

/// Pricing quotes are considered fresh for exactly 3 days (259,200,000 ms),
/// matching the web app's `CACHE_TTL_MS`. Applied by the pricing worker in Phase 3.
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

    func quote(forCardScryfallId scryfallId: String, normalizedName: String) -> CardPriceQuote? {
        quotes[scryfallId] ?? quotes[normalizedName]
    }
}