import SwiftUI

// MARK: - Deck list

struct DecksListView: View {
    @Environment(AppStore.self) private var appStore
    @State private var viewModel: DecksListViewModel?
    @State private var showingNewDeck = false
    @State private var showingImport = false

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Mazos")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showingImport = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .accessibilityLabel("Importar mazo")

                Button {
                    showingNewDeck = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Nuevo mazo")
            }
        }
        .task {
            let vm = DecksListViewModel(store: appStore.store, userId: appStore.userId)
            viewModel = vm
            await vm.load()
        }
        .sheet(isPresented: $showingNewDeck) {
            DeckEditorView(onSave: { deck in
                try? await saveNewDeck(deck)
            })
            .environment(appStore)
        }
        .sheet(isPresented: $showingImport) {
            DeckImportView(username: appStore.session.user?.displayName ?? "Jugador Demo")
        }
    }

    @MainActor
    private func content(_ viewModel: DecksListViewModel) -> some View {
        Group {
            if viewModel.isLoading && viewModel.decks.isEmpty {
                ProgressView("Cargando mazos…")
            } else if viewModel.decks.isEmpty {
                EmptyStateView(
                    title: viewModel.emptyStateTitle,
                    message: viewModel.emptyStateMessage,
                    systemImage: "rectangle.stack.badge.plus",
                    actionTitle: "Crear primer mazo",
                    action: { showingNewDeck = true }
                )
            } else {
                List {
                    ForEach(viewModel.decks) { deck in
                        NavigationLink(value: deck) {
                            DeckCardItemView(deck: deck)
                        }
                    }
                    .onDelete { indexSet in
                        Task {
                            for index in indexSet {
                                let deck = viewModel.decks[index]
                                try? await viewModel.deleteDeck(id: deck.id)
                            }
                            await viewModel.load()
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationDestination(for: DeckSummary.self) { deck in
            DeckDetailView(deckSummary: deck)
                .environment(appStore)
        }
    }

    @MainActor
    private func saveNewDeck(_ deck: Deck) async throws {
        guard let viewModel else { return }
        guard let commander = deck.cards.first(where: { $0.isCommander }) else {
            try await viewModel.createDeck(deck: deck)
            return
        }
        let enriched = try await appStore.catalog.resolveCards(named: [commander.cardName])
        var updated = deck
        if let resolved = enriched.first {
            updated.commanderScryfallId = resolved.scryfallId
            updated.commanderImageUri = resolved.imageUri
        }
        try await viewModel.createDeck(deck: updated)
        await viewModel.load()
    }
}

// MARK: - Deck card item

struct DeckCardItemView: View {
    let deck: DeckSummary

    var body: some View {
        HStack(spacing: 12) {
            artwork

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(deck.name)
                        .font(.headline)
                        .foregroundStyle(.mtgText)
                        .lineLimit(1)
                    Spacer()
                    Text(deck.format)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.mtgAmber)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.mtgAmber.opacity(0.14), in: Capsule())
                }

                if let commander = deck.commander {
                    Text(commander)
                        .font(.caption)
                        .foregroundStyle(.mtgTextSecondary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    CompletionBar(progress: deck.completionPercentage)
                        .frame(width: 90)
                    Text(deck.completionPercentage.percentFormatted())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(
                            deck.isComplete ? Color.mtgGreen : Color.mtgAmber
                        )
                    Spacer()
                    Text("\(deck.ownedCards)/\(deck.totalCards) cartas")
                        .font(.caption)
                        .foregroundStyle(.mtgTextSecondary)
                }

                if deck.missingCardsCount > 0 {
                    Text("Faltan \(deck.missingCardsCount) cartas")
                        .font(.caption2)
                        .foregroundStyle(Color.mtgRed)
                } else {
                    Text("Completo")
                        .font(.caption2)
                        .foregroundStyle(Color.mtgGreen)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var artwork: some View {
        ZStack {
            if let imageUri = deck.commanderImageUri, let url = URL(string: imageUri) {
                CardImageView(url: url, placeholderText: nil)
            } else {
                CardBackPlaceholder.view
            }
        }
        .frame(width: 56, height: 78)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
}

// MARK: - Previews

#Preview("Mazos") {
    NavigationStack {
        DecksListView()
            .environment(AppStore.demo)
    }
    .preferredColorScheme(.dark)
}