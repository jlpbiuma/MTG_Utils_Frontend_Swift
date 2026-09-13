import Foundation
import Observation

// MARK: - Decks list view model

@Observable
@MainActor
final class DecksListViewModel {
    private(set) var decks: [DeckSummary] = []
    private(set) var isLoading = false
    private(set) var isDeckSyncing = false
    private(set) var errorMessage: String?

    var searchText = ""
    var sortField: DeckSortField = .completion
    var sortDirection: SortDirection = .descending
    var selectedColors: Set<String> = []

    private let store: AppDataStoring
    private let userId: String
    private var deckSyncTask: Task<Void, Never>?

    init(store: AppDataStoring, userId: String) {
        self.store = store
        self.userId = userId
    }

    var emptyStateTitle: String { "Aún no tienes mazos" }
    var emptyStateMessage: String { "Crea tu primer mazo para ver su porcentaje de completitud." }

    var hasActiveFilters: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !selectedColors.isEmpty ||
        sortField != .completion ||
        sortDirection != .descending
    }

    func resetFilters() {
        searchText = ""
        selectedColors.removeAll()
        sortField = .completion
        sortDirection = .descending
    }

    var filteredAndSortedDecks: [DeckSummary] {
        var result = decks

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            result = result.filter { deck in
                deck.name.localizedCaseInsensitiveContains(query) ||
                (deck.commander?.localizedCaseInsensitiveContains(query) ?? false) ||
                deck.format.localizedCaseInsensitiveContains(query)
            }
        }

        if !selectedColors.isEmpty {
            result = result.filter { deck in
                if selectedColors.contains("C") && deck.colors.isEmpty {
                    return true
                }
                let activeColors = selectedColors.filter { $0 != "C" }
                if activeColors.isEmpty {
                    return deck.colors.isEmpty
                }
                return activeColors.isSubset(of: Set(deck.colors))
            }
        }

        result.sort { a, b in
            let comp: ComparisonResult
            switch sortField {
            case .completion:
                comp = a.completionPercentage.compareValue(to: b.completionPercentage)
            case .price:
                comp = a.estimatedPrice.compareValue(to: b.estimatedPrice)
            case .name:
                comp = a.name.localizedCaseInsensitiveCompare(b.name)
            case .date:
                let dateA = a.updatedAt
                let dateB = b.updatedAt
                comp = dateA.compare(dateB)
            }

            if comp == .orderedSame {
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
            return sortDirection == .ascending ? (comp == .orderedAscending) : (comp == .orderedDescending)
        }

        return result
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let rawDecks = try await store.allDecks()
            let collection = try await store.allCollection()
            let ownershipIndex = buildOwnershipIndex(collection)
            let summaries: [DeckSummary] = rawDecks.compactMap { deck in
                var ownedTotal = 0
                var unique = 0
                var total = 0
                for card in deck.cards {
                    if card.isCommander { continue }
                    unique += 1
                    total += card.quantity
                    ownedTotal += min(
                        ownershipIndex.ownedCount(scryfallId: card.cardScryfallId, name: card.cardName),
                        card.quantity
                    )
                }
                let missing = max(0, total - ownedTotal)
                let percentage = total > 0 ? (Double(ownedTotal) / Double(total)) * 100 : 0
                let colors = extractDeckColors(cards: deck.cards)
                let estimatedPrice = estimateDeckPrice(cards: deck.cards)

                return DeckSummary(
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
                    missingCardsCount: missing,
                    completionPercentage: percentage,
                    estimatedPrice: estimatedPrice,
                    colors: colors
                )
            }
            decks = summaries
        } catch {
            errorMessage = "No se pudieron cargar los mazos: \(error.localizedDescription)"
        }
    }

    func createDeck(deck: Deck) async throws {
        var all = try await store.allDecks()
        all.append(deck)
        try await store.saveDecks(all)
    }

    /// Adds an imported deck to the local list immediately and persists it in the background.
    /// This keeps the import sheet responsive even when the backend/catalog is slow.
    func importDeckLocally(_ deck: Deck) {
        let total = deck.cards.filter { !$0.isCommander }.reduce(0) { $0 + $1.quantity }
        let unique = deck.cards.filter { !$0.isCommander }.count
        let summary = DeckSummary(
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
            ownedCards: 0,
            missingCardsCount: total,
            completionPercentage: 0,
            estimatedPrice: estimateDeckPrice(cards: deck.cards),
            colors: extractDeckColors(cards: deck.cards)
        )
        if let index = decks.firstIndex(where: { $0.id == deck.id }) {
            decks[index] = summary
        } else {
            decks.append(summary)
        }

        deckSyncTask?.cancel()
        isDeckSyncing = true
        let store = self.store
        deckSyncTask = Task { [weak self] in
            do {
                var allDecks = try await store.allDecks()
                if let index = allDecks.firstIndex(where: { $0.id == deck.id }) {
                    allDecks[index] = deck
                } else {
                    allDecks.append(deck)
                }
                try await store.saveDecks(allDecks)
                await self?.load()
                self?.isDeckSyncing = false
            } catch is CancellationError {
                self?.isDeckSyncing = false
            } catch {
                self?.errorMessage = "El mazo se guardó localmente, pero no se pudo sincronizar: \(error.localizedDescription)"
                self?.isDeckSyncing = false
            }
        }
    }

    func deleteDeck(id: String) async throws {
        var all = try await store.allDecks()
        all.removeAll { $0.id == id }
        try await store.saveDecks(all)
    }

    func updateDeck(_ updated: Deck) async throws {
        var all = try await store.allDecks()
        if let idx = all.firstIndex(where: { $0.id == updated.id }) {
            all[idx] = updated
        }
        try await store.saveDecks(all)
    }

    func deck(id: String) async throws -> Deck? {
        try await store.allDecks().first { $0.id == id }
    }

    func duplicateDeck(id: String) async throws {
        var all = try await store.allDecks()
        guard var copy = all.first(where: { $0.id == id }) else { return }

        copy.id = UUID().uuidString
        copy.name = "\(copy.name) (Copia)"
        copy.createdAt = Date()
        copy.updatedAt = Date()
        copy.cards = copy.cards.map { card in
            var cloned = card
            cloned.id = UUID().uuidString
            cloned.deckId = copy.id
            return cloned
        }

        all.append(copy)
        try await store.saveDecks(all)
    }

    func decklistText(id: String) async throws -> String? {
        guard let deck = try await deck(id: id) else { return nil }

        func line(for card: DeckCard) -> String {
            "\(card.quantity) \(card.cardName)"
        }

        let commander = deck.cards.filter(\.isCommander)
        let mainboard = deck.cards
            .filter { !$0.isCommander && !$0.isSideboard }
            .sorted { $0.cardName.localizedCaseInsensitiveCompare($1.cardName) == .orderedAscending }
        let sideboard = deck.cards
            .filter { !$0.isCommander && $0.isSideboard }
            .sorted { $0.cardName.localizedCaseInsensitiveCompare($1.cardName) == .orderedAscending }

        var sections = ["// \(deck.name)", "// Formato: \(deck.format)"]
        if !commander.isEmpty {
            sections.append("\nCommander")
            sections.append(contentsOf: commander.map(line(for:)))
        }
        if !mainboard.isEmpty {
            sections.append("\nDeck")
            sections.append(contentsOf: mainboard.map(line(for:)))
        }
        if !sideboard.isEmpty {
            sections.append("\nSideboard")
            sections.append(contentsOf: sideboard.map(line(for:)))
        }
        return sections.joined(separator: "\n") + "\n"
    }
}
