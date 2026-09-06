import Foundation
import Observation

// MARK: - Card search view model (Scryfall live)

@Observable
@MainActor
final class CardSearchViewModel {
    private(set) var results: [ScryfallCard] = []
    private(set) var suggestionNames: [String] = []
    private(set) var isLoading = false
    private(set) var hasSearched = false
    private(set) var errorMessage: String?

    var searchText = ""
    private let catalog: ScryfallClient
    private var searchTask: Task<Void, Never>?

    init(catalog: ScryfallClient) {
        self.catalog = catalog
    }

    /// Debounced live search (≈350ms).
    func startedSearching() {
        searchTask?.cancel()
        let query = searchText
        hasSearched = false
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            suggestionNames = []
            return
        }
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await self?.runSearch(query)
        }
    }

    private func runSearch(_ query: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await catalog.search(query: query)
            results = result.data
            hasSearched = true
        } catch {
            errorMessage = "Búsqueda sin resultados o error de red."
            results = []
            hasSearched = true
        }
    }

    func runAutocompleteIfNeeded() async {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard query.count >= 2 else { return }
        if let names = try? await catalog.autocomplete(query) {
            suggestionNames = names
        }
    }

    func clear() {
        searchText = ""
        results = []
        suggestionNames = []
        hasSearched = false
        errorMessage = nil
    }
}