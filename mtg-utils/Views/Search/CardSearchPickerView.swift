import SwiftUI

// MARK: - Reusable card picker backed by live Scryfall search

struct CardSearchPickerView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = CardSearchViewModelMine()

    let title: String
    let onPick: (ScryfallCard) -> Void

    var body: some View {
        List {
            if let names = viewModel.suggestions, !names.isEmpty, !viewModel.searchText.isEmpty {
                Section("Sugerencias") {
                    ForEach(names.prefix(6), id: \.self) { name in
                        Button(name) {
                            viewModel.query = name
                        }
                        .foregroundStyle(.mtgText)
                    }
                }
            }

            if viewModel.isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }

            if !viewModel.error.isNil {
                Section {
                    Label(viewModel.error!, systemImage: "exclamationmark.triangle")
                }
            } else if !viewModel.results.isEmpty {
                Section("Resultados") {
                    ForEach(viewModel.results) { card in
                        Button {
                            onPick(card)
                            dismiss()
                        } label: {
                            HStack {
                                CardImageView(url: card.displayImageSmallUrl, placeholderText: nil, targetSize: 96)
                                    .frame(width: 34, height: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(card.name)
                                        .font(.subheadline)
                                        .foregroundStyle(.mtgText)
                                    HStack {
                                        ManaCostView(cost: card.displayManaCost)
                                        Text(card.displayTypeLine ?? "")
                                            .font(.caption2)
                                            .foregroundStyle(.mtgTextSecondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Buscar carta…")
        .onChange(of: viewModel.searchText) {
            viewModel.searched()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
        }
    }
}

@Observable
@MainActor
final class CardSearchViewModelMine {
    var searchText = ""
    var query = ""
    var results: [ScryfallCard] = []
    var suggestions: [String]?
    var isLoading = false
    var error: String?

    private var task: Task<Void, Never>?

    func searched() {
        task?.cancel()
        let query = searchText
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            results = []
            suggestions = nil
            return
        }
        task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await self?.perform(query: trimmed)
        }
    }

    private func perform(query: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        let catalog = ScryfallClient.shared
        if let suggestions = try? await catalog.autocomplete(query) {
            self.suggestions = suggestions
        }
        do {
            let result = try await catalog.search(query: query)
            results = result.data
        } catch {
            self.error = "No se encontraron resultados o hay un problema de red."
            results = []
        }
    }
}

extension Optional where Wrapped == String {
    var isNil: Bool {
        switch self {
        case .some(let value):
            return value.isEmpty
        case .none:
            return true
        }
    }
}
