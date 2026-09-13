import SwiftUI

// MARK: - Collection view

struct CollectionView: View {
    @Environment(AppStore.self) private var appStore
    @State private var viewModel: CollectionViewModel?
    @State private var showingImport = false
    @State private var showingSortSheet = false
    @State private var selectedCard: CollectionCard?
    @State private var cardEditingEdition: CollectionCard?
    @State private var cardEditingQuantity: CollectionCard?
    @State private var cardToDelete: CollectionCard?

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
            let vm = CollectionViewModel(store: appStore.store, priceProvider: appStore.settings.priceProvider)
            viewModel = vm
            await vm.load()
        }
        .sheet(isPresented: $showingImport) {
            CollectionImportView(onImport: { cards in
                viewModel?.importCardsLocally(cards)
            })
            .environment(appStore)
        }
        .sheet(item: $selectedCard) { card in
            if let viewModel {
                CardDetailView(
                    card: detailCard(from: card),
                    unitPrice: viewModel.price(for: card),
                    currencySymbol: viewModel.currencySymbol,
                    provider: appStore.settings.priceProvider,
                    client: appStore.client
                )
            }
        }
        .sheet(item: $cardEditingEdition) { card in
            if let viewModel {
                CardEditionEditorSheet(cardName: card.cardName, setCode: card.setCode) { setCode in
                    await viewModel.updateEdition(id: card.id, setCode: setCode)
                }
            }
        }
        .sheet(item: $cardEditingQuantity) { card in
            if let viewModel {
                CardQuantityEditorSheet(cardName: card.cardName, quantity: card.quantity) { quantity in
                    await viewModel.updateQuantity(id: card.id, quantity: quantity)
                }
            }
        }
        .alert(item: $cardToDelete) { card in
            Alert(
                title: Text("¿Eliminar \(card.cardName)?"),
                message: Text("Se eliminará únicamente de tu colección."),
                primaryButton: .destructive(Text("Eliminar")) {
                    Task { await viewModel?.removeCard(id: card.id) }
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showingSortSheet) {
            if let vm = viewModel {
                SortAndGroupSheet(
                    isGrouped: Bindable(vm).isGrouped,
                    sortField: Bindable(vm).sortField,
                    sortDirection: Bindable(vm).sortDirection
                )
            }
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
                ZStack(alignment: .bottom) {
                    List {
                        Section {
                            KPIStripView(stats: [
                                KPIStat(id: "unique", label: "Cartas únicas", value: "\(vm.stats.uniqueCards)", systemImage: "square.grid.2x2", tint: .mtgAmber),
                                KPIStat(id: "total", label: "Total cartas", value: "\(vm.stats.totalCards)", systemImage: "shippingbox", tint: .mtgGreen),
                                KPIStat(id: "value", label: "Valor est.", value: (vm.priceSummary?.totalNetValue ?? 0).formattedPrice(symbol: vm.currencySymbol), systemImage: "eurosign.circle", tint: .mtgAmber),
                            ])
                            if vm.isCollectionSyncing {
                                Text("Sincronizando importación…")
                                    .font(.caption2)
                                    .foregroundStyle(.mtgTextSecondary)
                            }
                        }

                        if vm.isGrouped {
                            if vm.groups.isEmpty && !vm.searchText.isEmpty {
                                Section {
                                    Text("No se encontraron cartas que coincidan con \"\(vm.searchText)\".")
                                        .font(.subheadline)
                                        .foregroundStyle(.mtgTextSecondary)
                                        .padding(.vertical, 8)
                                }
                            } else {
                                ForEach(vm.groups, id: \.key) { section in
                                    Section {
                                        ForEach(section.cards) { card in
                                            Button { selectedCard = card } label: {
                                                CollectionCardRow(
                                                    card: card,
                                                    unitPrice: vm.price(for: card),
                                                    currencySymbol: vm.currencySymbol
                                                )
                                            }
                                            .buttonStyle(.plain)
                                            .contextMenu { collectionCardMenu(card) }
                                        }
                                    } header: {
                                        HStack {
                                            Text(section.label)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.mtgText)
                                            Spacer()
                                            Text("\(section.totalCards) cartas")
                                                .font(.caption)
                                                .foregroundStyle(.mtgTextSecondary)
                                            if section.sectionTotalPrice > 0 {
                                                Text("•")
                                                    .font(.caption2)
                                                    .foregroundStyle(.mtgTextSecondary.opacity(0.6))
                                                Text(section.sectionTotalPrice.formattedPrice(symbol: section.currencySymbol))
                                                    .font(.caption2.monospacedDigit())
                                                    .foregroundStyle(.mtgTextSecondary)
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            if vm.sorted.isEmpty && !vm.searchText.isEmpty {
                                Section {
                                    Text("No se encontraron cartas que coincidan con \"\(vm.searchText)\".")
                                        .font(.subheadline)
                                        .foregroundStyle(.mtgTextSecondary)
                                        .padding(.vertical, 8)
                                }
                            } else {
                                Section("Todas las cartas · \(vm.sorted.reduce(0) { $0 + $1.quantity })") {
                                    ForEach(vm.sorted) { card in
                                        Button { selectedCard = card } label: {
                                            CollectionCardRow(
                                                card: card,
                                                unitPrice: vm.price(for: card),
                                                currencySymbol: vm.currencySymbol
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu { collectionCardMenu(card) }
                                    }
                                }
                            }
                        }

                        // Bottom spacer to ensure rows aren't covered by floating button
                        Section {
                            Color.clear
                                .frame(height: 52)
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .searchable(text: $vm.searchText, prompt: "Buscar por nombre, tipo o edición…")

                    floatingSortButton(vm)
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    @MainActor
    private func floatingSortButton(_ vm: CollectionViewModel) -> some View {
        @Bindable var vm = vm

        return Button {
            showingSortSheet = true
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .bold))

                Text(vm.isGrouped ? "Agrupado" : "Sin agrupar")
                    .font(.subheadline.weight(.semibold))

                Text("•")
                    .font(.caption2)
                    .opacity(0.6)

                Text(vm.sortField.displayName)
                    .font(.subheadline.weight(.medium))

                Image(systemName: vm.sortDirection == .ascending ? "arrow.up" : "arrow.down")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color.mtgAmber, Color.mtgAmberDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
        }
        .contextMenu {
            Toggle(isOn: $vm.isGrouped) {
                Label(vm.isGrouped ? "Desagrupar" : "Agrupar por tipo", systemImage: "rectangle.3.group")
            }

            Divider()

            Menu("Ordenar por") {
                ForEach(SortField.allCases) { field in
                    Button {
                        vm.sortField = field
                    } label: {
                        if vm.sortField == field {
                            Label(field.displayName, systemImage: "checkmark")
                        } else {
                            Text(field.displayName)
                        }
                    }
                }
            }

            Menu("Dirección") {
                ForEach(SortDirection.allCases) { dir in
                    Button {
                        vm.sortDirection = dir
                    } label: {
                        if vm.sortDirection == dir {
                            Label(dir.displayName, systemImage: "checkmark")
                        } else {
                            Text(dir.displayName)
                        }
                    }
                }
            }
        }
    }

    private func detailCard(from card: CollectionCard) -> DeckCardWithOwnership {
        DeckCardWithOwnership(
            id: card.id,
            deckId: "collection",
            cardScryfallId: card.cardScryfallId,
            cardName: card.cardName,
            quantity: card.quantity,
            assignedQuantity: 0,
            isSideboard: false,
            isCommander: false,
            manaCost: card.manaCost,
            typeLine: card.typeLine,
            imageUri: card.imageUri,
            setCode: card.setCode,
            ownedInCollection: card.quantity,
            availableToAssign: card.quantity,
            assignedInOtherDecks: [],
            missingCount: 0
        )
    }

    @ViewBuilder
    private func collectionCardMenu(_ card: CollectionCard) -> some View {
        Button {
            selectedCard = card
        } label: {
            Label("Ver detalles", systemImage: "info.circle")
        }
        Button {
            cardEditingEdition = card
        } label: {
            Label("Editar edición", systemImage: "rectangle.and.pencil.and.ellipsis")
        }
        Button {
            cardEditingQuantity = card
        } label: {
            Label("Editar cantidad", systemImage: "number")
        }
        Divider()
        Button(role: .destructive) {
            cardToDelete = card
        } label: {
            Label("Eliminar de la colección", systemImage: "trash")
        }
    }
}

// MARK: - Collection card row

struct CollectionCardRow: View {
    let card: CollectionCard
    /// Always the price of one copy; it must never be the row subtotal.
    var unitPrice: Double = 0
    var currencySymbol: String = "€"

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Preview de la carta a la izquierda
            ZStack {
                if let url = AppConfiguration.imageURL(from: card.imageUri) {
                    CardImageView(url: url, placeholderText: nil)
                } else {
                    CardBackPlaceholder.view
                }
            }
            .frame(width: 38, height: 53)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.12), lineWidth: 0.5))

            VStack(alignment: .leading, spacing: 4) {
                // Fila 1: Cantidad + Nombre + Mana Cost
                HStack(alignment: .center, spacing: 6) {
                    Text("×\(card.quantity)")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(.mtgAmber)

                    Text(card.cardName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.mtgText)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    ManaCostView(cost: card.manaCost)
                }

                // Fila 2: Tipo + Insignia de Expansión + Precio
                HStack(alignment: .center, spacing: 6) {
                    if let typeLine = card.typeLine, !typeLine.isEmpty {
                        Text(typeLine)
                            .font(.caption2)
                            .foregroundStyle(.mtgTextSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    SetExpansionBadge(setCode: card.setCode)

                    if unitPrice > 0 {
                        Text(unitPrice.formattedPrice(symbol: currencySymbol))
                            .font(.caption2.weight(.medium).monospacedDigit())
                            .foregroundStyle(.mtgTextSecondary)
                            .accessibilityLabel("Precio unitario")
                    }
                }

                // Fila 3: Indicador de posesión en colección
                HStack(spacing: 5) {
                    OwnershipStatusChip(
                        text: "En colección: \(card.quantity)",
                        systemImage: "checkmark.circle.fill",
                        tint: .mtgGreen
                    )
                }
                .padding(.top, 1)
            }
        }
        .padding(.vertical, 3)
    }
}

#Preview("Colección") {
    NavigationStack {
        CollectionView()
            .environment(AppStore.demo)
    }
    .preferredColorScheme(.dark)
}
