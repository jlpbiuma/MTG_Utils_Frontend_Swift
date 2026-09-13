import Foundation
import Observation

// MARK: - Deck detail view model

@Observable
@MainActor
final class DeckDetailViewModel {
    private(set) var detail: DeckDetail?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    let deckId: String

    private let store: AppDataStoring
    private let catalog: ScryfallClient?
    private let priceProvider: PriceProvider
    private(set) var deck: Deck

    // MARK: sorting + filters

    var sortField: SortField = .cmc
    var sortDirection: SortDirection = .ascending
    var filterMissingOnly = false
    var isGrouped = true
    var deckSearchText = ""

    private(set) var priceSummary: PriceSummary?

    /// Commander's color identity (WUBRG order) resolved from Scryfall when available,
    /// falling back to the colors of the commander's mana cost.
    private(set) var commanderColorIdentity: [String] = []

    var currencySymbol: String {
        priceSummary?.currencySymbol ?? "€"
    }

    func price(for card: DeckCardWithOwnership) -> Double {
        if let quote = priceSummary?.quote(forCardScryfallId: card.cardScryfallId, normalizedName: normalizeCardName(card.cardName)) {
            return quote.unitPrice.trend
        }
        return representativePrice(card.cardName, card.typeLine)
    }

    init(deck: Deck, store: AppDataStoring, catalog: ScryfallClient? = nil, priceProvider: PriceProvider = .cardmarket) {
        self.deck = deck
        self.deckId = deck.id
        self.store = store
        self.catalog = catalog
        self.priceProvider = priceProvider
    }

    var commander: DeckCardWithOwnership? {
        guard let detail else { return nil }

        // Older imports do not always persist `isCommander`, but they do retain
        // the commander's name on the deck. Resolve both representations so the
        // header never falls back to an incorrect colour identity.
        return detail.cards.first { $0.isCommander }
            ?? detail.commander.flatMap { commanderName in
                detail.cards.first {
                    normalizeCardName($0.cardName) == normalizeCardName(commanderName)
                }
            }
    }

    var mainboardSorted: [DeckCardWithOwnership] {
        guard let detail else { return [] }
        var cards = detail.mainboardCards
        if filterMissingOnly {
            cards = cards.filter { $0.missingCount > 0 }
        }
        if !matchingSearchText.isEmpty {
            cards = cards.filter { matchesSearch($0) }
        }
        return sortCards(cards, by: sortField, direction: sortDirection)
    }

    var sideboardSorted: [DeckCardWithOwnership] {
        guard let detail else { return [] }
        var cards = detail.sideboardCards
        if filterMissingOnly {
            cards = cards.filter { $0.missingCount > 0 }
        }
        if !matchingSearchText.isEmpty {
            cards = cards.filter { matchesSearch($0) }
        }
        return sortCards(cards, by: sortField, direction: sortDirection)
    }

    var matchingSearchText: String {
        deckSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    }

    private func matchesSearch(_ card: DeckCardWithOwnership) -> Bool {
        guard !matchingSearchText.isEmpty else { return true }
        return card.cardName.localizedLowercase.contains(matchingSearchText)
            || (card.typeLine?.localizedLowercase.contains(matchingSearchText) ?? false)
    }

    var groupsMainboard: [GroupedCardSection<DeckCardWithOwnership>] {
        groupCardsByType(mainboardSorted, priceSummary: priceSummary)
    }

    var groupsSideboard: [GroupedCardSection<DeckCardWithOwnership>] {
        groupCardsByType(sideboardSorted, priceSummary: priceSummary)
    }

    var groupsFull: [GroupedCardSection<DeckCardWithOwnership>] {
        guard let detail else { return [] }
        return groupCardsByType(detail.cards, priceSummary: priceSummary)
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        commanderColorIdentity = []
        defer { isLoading = false }

        do {
            let collection = try await store.allCollection()
            let allDecks = try await store.allDecks()
            if let latestDeck = allDecks.first(where: { $0.id == deckId }) {
                self.deck = latestDeck
            }
            let ownershipIndex = buildOwnershipIndex(collection)
            let otherAssignments = buildOtherDeckAssignments(allDecks)

            var collectionSetByNorm: [String: String] = [:]
            for col in collection {
                if let set = col.setCode, !set.isEmpty {
                    let norm = normalizeCardName(col.cardName)
                    if collectionSetByNorm[norm] == nil {
                        collectionSetByNorm[norm] = set
                    }
                }
            }

            var ownedByCardId: [String: Int] = [:]

            let detailCards: [DeckCardWithOwnership] = deck.cards.map { card in
                let result = deckCardOwnershipResult(
                    card: card,
                    ownershipIndex: ownershipIndex,
                    otherDecksAssignments: otherAssignments
                )
                ownedByCardId[card.id] = result.ownedInCollection
                let norm = normalizeCardName(card.cardName)
                let resolvedSet = card.setCode ?? collectionSetByNorm[norm]

                return DeckCardWithOwnership(
                    id: card.id,
                    deckId: card.deckId,
                    cardScryfallId: card.cardScryfallId,
                    cardName: card.cardName,
                    quantity: card.quantity,
                    assignedQuantity: card.assignedQuantity,
                    isSideboard: card.isSideboard,
                    isCommander: card.isCommander,
                    manaCost: card.manaCost,
                    typeLine: card.typeLine,
                    imageUri: card.imageUri,
                    setCode: resolvedSet,
                    ownedInCollection: result.ownedInCollection,
                    availableToAssign: result.availableToAssign,
                    assignedInOtherDecks: result.assignedInOtherDecks,
                    missingCount: result.missingCount
                )
            }

            var total = 0
            var ownedTotal = 0
            var unique = 0
            var missingTotal = 0
            for card in detailCards where !card.isCommander {
                total += card.quantity
                ownedTotal += card.ownedInCollection
                missingTotal += card.missingCount
                unique += 1
            }

            let percentage = total > 0 ? (Double(ownedTotal) / Double(total)) * 100 : 0

            // Pre-calculate price summary for display across the deck and sections
            var quotes: [String: CardPriceQuote] = [:]
            var totalNet = 0.0
            var ownedValue = 0.0
            var missingValue = 0.0

            for card in detailCards {
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

                let effectiveOwned = min(card.ownedInCollection, card.quantity)
                totalNet += quote.subtotal
                ownedValue += trend * Double(effectiveOwned)
                missingValue += trend * Double(card.missingCount)
            }

            self.priceSummary = PriceSummary(
                provider: priceProvider,
                currency: priceProvider.currency,
                currencySymbol: priceProvider.currencySymbol,
                totalCards: total,
                totalNetValue: totalNet.rounded2(),
                totalOwnedValue: ownedValue.rounded2(),
                totalMissingValue: missingValue.rounded2(),
                quotes: quotes
            )

            detail = DeckDetail(
                id: deck.id,
                userId: deck.userId,
                name: deck.name,
                format: deck.format,
                description: deck.description,
                commander: deck.commander,
                commanderScryfallId: deck.commanderScryfallId,
                commanderImageUri: deck.commanderImageUri,
                createdAt: deck.createdAt,
                updatedAt: deck.updatedAt,
                totalCards: total,
                uniqueCards: unique,
                ownedCards: ownedTotal,
                missingCardsCount: missingTotal,
                completionPercentage: percentage,
                cards: detailCards
            )
            if let backend = store as? BackendDataStore,
               let serverSummary = try? await backend.priceSummary(forDeckId: deck.id, provider: priceProvider) {
                priceSummary = serverSummary
            }
            await resolveCommanderColorIdentity()
        } catch {
            errorMessage = "No se pudo cargar el mazo: \(error.localizedDescription)"
        }
    }

    /// Resolves the commander's color identity from Scryfall (`color_identity`),
    /// falling back to the colors in the commander's mana cost when offline.
    private func resolveCommanderColorIdentity() async {
        guard let commander = commander, commanderColorIdentity.isEmpty else { return }

        let fallback = extractColors(from: commander.manaCost)
        guard !commander.cardScryfallId.hasPrefix("pending:") else {
            commanderColorIdentity = fallback
            return
        }

        if let card = try? await catalog?.namedCard(name: commander.cardName, exact: true),
           !card.displayColorIdentity.isEmpty {
            commanderColorIdentity = card.displayColorIdentity
            return
        }
        commanderColorIdentity = fallback
    }

    // MARK: - Añadir carta

    /// Adds a card (from a Scryfall search) to the deck, merging with an existing
    /// copy in the same board, then persists and reloads.
    func addCard(_ card: ScryfallCard, quantity: Int = 1, isSideboard: Bool = false) async throws {
        guard quantity > 0 else { return }

        var all = try await store.allDecks()
        guard let index = all.firstIndex(where: { $0.id == deckId }) else { return }
        var target = all[index]

        let newCard = DeckCard(
            cardScryfallId: card.id,
            cardName: card.name,
            quantity: quantity,
            isSideboard: isSideboard,
            isCommander: false,
            manaCost: card.displayManaCost,
            typeLine: card.displayTypeLine,
            imageUri: card.displayImageUri
        )

        if let existing = target.cards.firstIndex(where: {
            $0.cardScryfallId == card.id && $0.isSideboard == isSideboard
        }) {
            target.cards[existing].quantity += quantity
        } else {
            target.cards.append(newCard)
        }

        all[index] = target
        try await store.saveDecks(all)
        await load()
    }

    func removeCard(id: String) async {
        await updateCard(id: id) { _ in nil }
    }

    func updateEdition(id: String, setCode: String?) async {
        let cleanedSetCode = setCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        await updateCard(id: id) { card in
            var updated = card
            updated.setCode = cleanedSetCode?.isEmpty == true ? nil : cleanedSetCode
            return updated
        }
    }

    func updateQuantity(id: String, quantity: Int) async {
        guard quantity >= 1 else { return }
        await updateCard(id: id) { card in
            var updated = card
            updated.quantity = quantity
            updated.assignedQuantity = min(updated.assignedQuantity, quantity)
            return updated
        }
    }

    private func updateCard(id: String, transform: (DeckCard) -> DeckCard?) async {
        do {
            var all = try await store.allDecks()
            guard let deckIndex = all.firstIndex(where: { $0.id == deckId }) else { return }
            all[deckIndex].cards = all[deckIndex].cards.compactMap { card in
                card.id == id ? transform(card) : card
            }
            try await store.saveDecks(all)
            await load()
        } catch {
            errorMessage = "No se pudo actualizar el mazo: \(error.localizedDescription)"
        }
    }
}
