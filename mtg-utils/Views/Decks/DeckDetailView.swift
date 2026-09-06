import SwiftUI

// MARK: - Deck detail

struct DeckDetailView: View {
    @Environment(AppStore.self) private var appStore
    let deckSummary: DeckSummary

    @State private var viewModel: DeckDetailViewModel?
    @State private var showingEdhrec = false
    @State private var showingPricing = false

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(deckSummary.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if deckSummary.commander != nil {
                    Button {
                        showingEdhrec = true
                    } label: {
                        Image(systemName: "wand.and.stars")
                    }
                    .accessibilityLabel("Recomendaciones EDHREC")
                }
                Button {
                    showingPricing = true
                } label: {
                    Image(systemName: "eurosign.circle")
                }
                .accessibilityLabel("Precios")
            }
        }
        .task {
            if let deck = try? await appStore.store.allDecks().first(where: { $0.id == deckSummary.id }) {
                let vm = DeckDetailViewModel(deck: deck, store: appStore.store)
                viewModel = vm
                await vm.load()
            } else {
                let vm = DeckDetailViewModel(deck: Deck(id: deckSummary.id, name: deckSummary.name), store: appStore.store)
                viewModel = vm
            }
        }
        .sheet(isPresented: $showingEdhrec) {
            if let viewModel, let commander = viewModel.commander {
                EdhrecRecommendationsSheet(
                    commanderName: commander.cardName,
                    deckCards: viewModel.detail?.cards ?? []
                )
                .environment(appStore)
            }
        }
        .sheet(isPresented: $showingPricing) {
            if let viewModel, let detail = viewModel.detail {
                PricingSheet(detail: detail)
            }
        }
    }

    @MainActor
    private func content(_ vm: DeckDetailViewModel) -> some View {
        @Bindable var vm = vm

        return List {
            if let detail = vm.detail {
                header(detail)

                completionSection(detail)

                if vm.canTransferMissing {
                    Button {
                        Task { try? await vm.transferMissingToCollection() }
                    } label: {
                        Label("Tengo las faltantes (marcarlas como poseídas)", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.mtgGreen)
                    .listRowSeparator(.hidden)
                }

                Section {
                    CardSortingBar(field: $vm.sortField, direction: $vm.sortDirection)
                } header: {
                    Text("Ordenar")
                }

                if vm.filterMissingOnly {
                    Toggle("Solo faltantes", isOn: $vm.filterMissingOnly)
                        .listRowSeparatorTint(Color.mtgRed.opacity(0.4))
                } else {
                    Toggle("Solo faltantes", isOn: $vm.filterMissingOnly)
                        .listRowSeparator(.hidden)
                }

                if !vm.mainboardSorted.isEmpty {
                    Section("Mazo principal · \(detail.mainboardCount) cartas") {
                        ForEach(vm.mainboardSorted) { card in
                            DeckCardRow(card: card)
                        }
                    }
                }

                if !vm.sideboardSorted.isEmpty {
                    Section("Reservas · \(detail.sideboardCount) cartas") {
                        ForEach(vm.sideboardSorted) { card in
                            DeckCardRow(card: card, isSideboard: true)
                        }
                    }
                }
            } else if vm.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if let errorMessage = vm.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(Color.mtgRed)
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await vm.load() }
    }

    @MainActor
    private func header(_ detail: DeckDetail) -> some View {
        Section {
            HStack(spacing: 12) {
                if let commander = detail.commander {
                    ZStack {
                        if let uri = detail.commanderImageUri, let url = URL(string: uri) {
                            CardImageView(url: url, placeholderText: nil)
                        } else {
                            CardBackPlaceholder.view
                        }
                    }
                    .frame(width: 76, height: 104)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 6) {
                    LabeledContent("Formato", value: detail.format)
                    if let commander = detail.commander {
                        LabeledContent("Comandante", value: commander)
                            .lineLimit(2)
                    }
                    if let description = detail.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.mtgTextSecondary)
                    }
                }
            }
        }
    }

    @MainActor
    private func completionSection(_ detail: DeckDetail) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Completitud")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(detail.completionPercentage.percentFormatted())
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(detail.isComplete ? Color.mtgGreen : Color.mtgAmber)
                }

                CompletionBar(progress: detail.completionPercentage)
                    .frame(height: 12)

                KPIStripView(stats: [
                    KPIStat(id: "total", label: "Cartas", value: "\(detail.totalCards)", systemImage: "shippingbox", tint: .mtgAmber),
                    KPIStat(id: "owned", label: "Tienes", value: "\(detail.ownedCards)", systemImage: "checkmark.seal", tint: .mtgGreen),
                    KPIStat(id: "missing", label: "Faltan", value: "\(detail.missingCardsCount)", systemImage: "exclamationmark.circle", tint: .mtgRed),
                ])
            }
        }
    }
}

// MARK: - Deck card row

struct DeckCardRow: View {
    let card: DeckCardWithOwnership
    var isSideboard = false

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

                HStack(spacing: 6) {
                    Text("×\(card.quantity)")
                        .font(.caption.monospacedDigit())
                    Text(card.typeLine ?? "")
                        .font(.caption2)
                        .foregroundStyle(.mtgTextSecondary)
                        .lineLimit(1)
                    Spacer()
                    if card.missingCount > 0 {
                        Text("falta \(card.missingCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.mtgRed)
                    } else {
                        Text("completo")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.mtgGreen)
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .opacity(isSideboard ? 0.85 : 1)
    }
}

#Preview("Detalle") {
    NavigationStack {
        DeckDetailView(deckSummary: DeckSummary(
            id: "1",
            userId: MockDataStore.demoUserId,
            name: "Esper Control",
            format: "Modern",
            totalCards: 32,
            uniqueCards: 10,
            ownedCards: 24,
            missingCardsCount: 8,
            completionPercentage: 75
        ))
        .environment(AppStore.demo)
    }
    .preferredColorScheme(.dark)
}