import Foundation
import Testing
@testable import mtg_utils

// Port of frontend/tests/unit/pricing.test.ts + pricing-cache-ttl.test.ts
// (provider configuration, 3-day cache policy, quote math). The DeckUpdateSchema
// (Zod) portion has no Swift equivalent and is intentionally omitted.

@Suite("Pricing Engine & 3-Day Cache Policy")
struct PricingTests {

    @Test func supportsProviderConfigurations() {
        #expect(PriceProvider.allCases.count == 3)

        #expect(PriceProvider.cardmarket.displayName.contains("Cardmarket"))
        #expect(PriceProvider.cardmarket.currencySymbol == "€")
        #expect(PriceProvider.cardmarket.currency == "EUR")

        #expect(PriceProvider.cardtrader.displayName.contains("Card Trader"))
        #expect(PriceProvider.cardtrader.currencySymbol == "€")
        #expect(PriceProvider.cardtrader.currency == "EUR")

        #expect(PriceProvider.mtggoldfish.displayName.contains("MTGGoldfish"))
        #expect(PriceProvider.mtggoldfish.currencySymbol == "$")
        #expect(PriceProvider.mtggoldfish.currency == "USD")

        for provider in PriceProvider.allCases {
            #expect(!provider.description.isEmpty)
            #expect(!provider.logoText.isEmpty)
        }
    }

    @Test func cacheTTLIsExactlyThreeDays() {
        let threeDaysInMs: Double = 3 * 24 * 60 * 60 * 1000
        #expect(PricingCache.ttlMilliseconds == threeDaysInMs)
        #expect(PricingCache.ttlMilliseconds == 259_200_000.0)
    }

    @Test func evaluatesTimestampAgeAgainstThreeDayThreshold() {
        let now = Date().timeIntervalSince1970 * 1000
        let hourMs: Double = 60 * 60 * 1000

        #expect(PricingCache.isValidTimestamp(now - 1 * hourMs, now: now))
        #expect(PricingCache.isValidTimestamp(now - 24 * hourMs, now: now))
        #expect(PricingCache.isValidTimestamp(now - 2 * 24 * hourMs, now: now))

        #expect(PricingCache.isValidTimestamp(now - (3 * 24 + 1) * hourMs, now: now) == false)
        #expect(PricingCache.isValidTimestamp(now - 7 * 24 * hourMs, now: now) == false)
    }

    @Test func buildsCardmarketStyleQuoteInEuros() {
        let quantity = 3
        let trend = 1.5

        let quote = CardPriceQuote(
            cardName: "Sol Ring",
            scryfallId: "id",
            provider: .cardmarket,
            currency: PriceProvider.cardmarket.currency,
            currencySymbol: PriceProvider.cardmarket.currencySymbol,
            unitPrice: UnitPriceBreakdown(trend: trend, min: 0.8, max: 4.2),
            quantity: quantity,
            subtotal: (trend * Double(quantity)).rounded2(),
            purchaseUrl: "https://www.cardmarket.com/en/Magic/Products/Singles/Sol-Ring",
            lastUpdated: Date()
        )

        #expect(quote.provider == .cardmarket)
        #expect(quote.currency == "EUR")
        #expect(quote.currencySymbol == "€")
        #expect(quote.unitPrice.trend == 1.5)
        #expect(quote.unitPrice.min <= 1.5)
        #expect(quote.unitPrice.max == 4.2)
        #expect(quote.subtotal == 4.5)
        #expect(quote.purchaseUrl?.contains("cardmarket.com") == true)
    }

    @Test func buildsMTGGoldfishStyleQuoteInUsd() {
        let quantity = 4
        let trend = 1.8

        let quote = CardPriceQuote(
            cardName: "Sol Ring",
            scryfallId: "id",
            provider: .mtggoldfish,
            currency: PriceProvider.mtggoldfish.currency,
            currencySymbol: PriceProvider.mtggoldfish.currencySymbol,
            unitPrice: UnitPriceBreakdown(trend: trend, min: 1.0, max: 5.1),
            quantity: quantity,
            subtotal: (trend * Double(quantity)).rounded2(),
            purchaseUrl: "https://www.mtggoldfish.com/price/Sol-Ring#online",
            lastUpdated: Date()
        )

        #expect(quote.provider == .mtggoldfish)
        #expect(quote.currency == "USD")
        #expect(quote.currencySymbol == "$")
        #expect(quote.unitPrice.trend == 1.8)
        #expect(quote.unitPrice.min <= 1.8)
        #expect(quote.unitPrice.max == 5.1)
        #expect(quote.subtotal == 7.2)
        #expect(quote.purchaseUrl?.contains("mtggoldfish.com") == true)
    }

    @Test func priceSummarySplitsOwnedAndMissingValue() {
        let owned = CardPriceQuote(
            cardName: "Sol Ring",
            provider: .cardmarket,
            currency: "EUR",
            currencySymbol: "€",
            unitPrice: UnitPriceBreakdown(trend: 1.5, min: 1.0, max: 4.0),
            quantity: 1,
            subtotal: 1.5,
            purchaseUrl: nil,
            lastUpdated: Date()
        )
        let missing = CardPriceQuote(
            cardName: "Lightning Bolt",
            provider: .cardmarket,
            currency: "EUR",
            currencySymbol: "€",
            unitPrice: UnitPriceBreakdown(trend: 2.0, min: 1.2, max: 5.0),
            quantity: 4,
            subtotal: 8.0,
            purchaseUrl: nil,
            lastUpdated: Date()
        )

        let summary = PriceSummary(
            provider: .cardmarket,
            currency: "EUR",
            currencySymbol: "€",
            totalCards: 5,
            totalNetValue: 9.5,
            totalOwnedValue: 1.5,
            totalMissingValue: 8.0,
            quotes: [
                "id-sol-ring": owned,
                "id-bolt": missing,
            ]
        )

        #expect(summary.provider == .cardmarket)
        #expect(summary.currency == "EUR")
        #expect(summary.totalCards == 5)
        #expect(summary.quote(forCardScryfallId: "id-sol-ring", normalizedName: "sol ring")?.unitPrice.trend == 1.5)
        #expect(summary.totalNetValue == (summary.totalOwnedValue! + summary.totalMissingValue!).rounded2())
    }
}