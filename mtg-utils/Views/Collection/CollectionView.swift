import SwiftUI

// MARK: - Collection view

struct CollectionView: View {
    @Environment(AppStore.self) private var appStore
    @State private var viewModel: CollectionViewModel?
    @State private var showingImport = false

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Colección")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingImport = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .accessibilityLabel("Importar colección")
            }
        }
        .task {
            let vm = CollectionViewModel(store: appStore.store)
            viewModel = vm
            await vm.load()
        }
        .sheet(isPresented: $showingImport) {
            CollectionImportView(onImport: { cards in
                try await importCards(cards)
            })
            .environment(appStore)
        }
    }

    @MainActor
    private func content(_ vm: CollectionViewModel) -> some View {
        @Bindable var vm = vm

        return Group {
            if vm.isLoading && vm.cards.isEmpty {
                ProgressView("Cargando colección…")
            } else if vm.cards.isEmpty {
                EmptyStateView(
                    title: "Colección vacía",
                    message: "Importa tus cartas para verlas agrupadas y relacionadas con tus mazos.",
                    systemImage: "square.grid.2x2",
                    actionTitle: "Importar colección",
                    action: { showingImport = true }
                )
            } else {
                List {
                    Section {
                        KPIStripView(stats: [
                            KPIStat(id: "unique", label: "Cartas únicas", value: "\(vm.stats.uniqueCards)", systemImage: "square.grid.2x2", tint: .mtgAmber),
                            KPIStat(id: "total", label: "Total", value: "\(vm.stats.totalCards)", systemImage: "shippingbox", tint: .mtgGreen),
                            KPIStat(id: "decks", label: "Mazos", value: "\(0)", systemImage: "rectangle.stack", tint: .mtgTextSecondary),
                        ])
                    }

                    Section {
                        CardSortingBar(field: $vm.sortField, direction: $vm.sortDirection)
                    }

                    if vm.searchText.isEmpty {
                        ForEach(vm.groups, id: \.key) { section in
                            Section {
                                ForEach(section.cards) { card in
                                    CollectionCardRow(card: card)
                                }
                            } header: {
                                HStack {
                                    Text(section.label)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text("\(section.totalCards)")
                                        .font(.caption)
                                        .foregroundStyle(.mtgTextSecondary)
                                }
                            }
                        }
                    } else {
                        Section {
                            ForEach(vm.sorted) { card in
                                CollectionCardRow(card: card)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .searchable(text: $vm.searchText, prompt: "Buscar en tu colección…")
            }
        }
    }

    @MainActor
    private func importCards(_ cards: [CollectionCard]) async throws {
        try await viewModel?.addCards(cards)
    }
}

// MARK: - Collection card row

struct CollectionCardRow: View {
    let card: CollectionCard

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                if let uri = card.imageUri, let url = URL(string: uri) {
                    CardImageView(url: url, placeholderText: nil)
                } else {
                    CardBackPlaceholder.view
                }
            }
            .frame(width: 30, height: 42)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.white.opacity(0.1), lineWidth: 0.5))

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(card.cardName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.mtgText)
                        .lineLimit(1)
                    ManaCostView(cost: card.manaCost)
                }
                Text(card.typeLine ?? "")
                    .font(.caption2)
                    .foregroundStyle(.mtgTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("×\(card.quantity)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.mtgText)
        }
        .padding(.vertical, 2)
    }
}

#Preview("Colección") {
    NavigationStack {
        CollectionView()
            .environment(AppStore.demo)
    }
    .preferredColorScheme(.dark)
}