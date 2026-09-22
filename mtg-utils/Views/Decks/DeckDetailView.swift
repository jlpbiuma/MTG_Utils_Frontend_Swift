import SwiftUI

enum DeckSubView: String, CaseIterable, Identifiable {
    case cards = "Cartas"
    case editor = "Editor"
    case analytics = "Analíticas"
    case mulligan = "Mulligan"
    case overlap = "Solapamiento"

    var id: String { rawValue }
}

struct DeckDetailView: View {
    @Environment(AppStore.self) private var appStore
    let deckSummary: DeckSummary

    @State private var viewModel: DeckDetailViewModel?
    @State private var selectedSubView: DeckSubView = .cards
    @State private var showingEdhrec = false
    @State private var showingPricing = false
    @State private var showingEdit = false
    @State private var showingSortSheet = false
    @State private var showingAddCard = false
    @State private var selectedCard: DeckCardWithOwnership?
    @State private var cardEditingEdition: DeckCardWithOwnership?
    @State private var cardEditingQuantity: DeckCardWithOwnership?
    @State private var cardToDelete: DeckCardWithOwnership?
    @State private var isAddingMissingToCollection = false
    @State private var isAddingMissingToWants = false
    @State private var bannerFeedback: String?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(viewModel?.detail?.name ?? deckSummary.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showingAddCard = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Añadir carta")

                if deckSummary.commander != nil || viewModel?.detail?.commander != nil {
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

                Button {
                    showingEdit = true
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Editar mazo")
            }
        }
        .task {
            let vm = viewModel ?? DeckDetailViewModel(
                deck: Deck(id: deckSummary.id, name: deckSummary.name),
                store: appStore.store, catalog: appStore.catalog,
                priceProvider: appStore.settings.priceProvider
            )
            viewModel = vm
            await vm.load()
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
        .sheet(item: $selectedCard) { card in
            if let viewModel {
                CardDetailView(
                    card: card,
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
                message: Text("Se eliminará únicamente de este mazo."),
                primaryButton: .destructive(Text("Eliminar")) {
                    Task { await viewModel?.removeCard(id: card.id) }
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showingAddCard) {
            AddCardSheet(title: "Añadir carta") { card, quantity, isSideboard in
                try await viewModel?.addCard(card, quantity: quantity, isSideboard: isSideboard)
            }
        }
        .sheet(isPresented: $showingEdit) {
            if let viewModel {
                DeckEditorView(deck: viewModel.deck) { updatedDeck in
                    try await appStore.store.updateDeck(updatedDeck)
                    await viewModel.load()
                }
            }
        }
        .sheet(isPresented: $showingSortSheet) {
            if let viewModel {
                SortAndGroupSheet(
                    isGrouped: Bindable(viewModel).isGrouped,
                    sortField: Bindable(viewModel).sortField,
                    sortDirection: Bindable(viewModel).sortDirection,
                    filterMissingOnly: Bindable(viewModel).filterMissingOnly
                )
            }
        }
    }

    @MainActor
    private func content(_ vm: DeckDetailViewModel) -> some View {
        VStack(spacing: 0) {
            // Sub-view picker
            Picker("Vista", selection: $selectedSubView) {
                ForEach(DeckSubView.allCases) { subView in
                    Text(subView.rawValue).tag(subView)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 6)
            .padding(.bottom, 4)
            .background(Color.mtgSurface)

            Group {
                switch selectedSubView {
                case .cards:
                    cardsListView(vm)
                case .editor:
                    MoxfieldDeckEditorView(cards: vm.detail?.cards ?? []) { _ in
                        await vm.load()
                    }
                case .analytics:
                    DeckAnalyticsView(cards: vm.detail?.cards ?? [], colors: vm.commanderColorIdentity)
                case .mulligan:
                    DeckMulliganSimulatorView(cards: vm.detail?.cards ?? [], commanderName: vm.detail?.commander)
                case .overlap:
                    DeckOverlapView(cards: vm.detail?.cards ?? [], deckName: vm.detail?.name ?? "")
                }
            }
        }
    }

    @MainActor
    private func cardsListView(_ vm: DeckDetailViewModel) -> some View {
        @Bindable var vm = vm

        return VStack(spacing: 0) {
            List {
                if let detail = vm.detail {
                    header(detail, vm: vm)

                    if vm.isGrouped {
                        if !vm.groupsMainboard.isEmpty {
                            ForEach(vm.groupsMainboard, id: \.key) { section in
                                Section {
                                    ForEach(section.cards) { card in
                                        cardRow(card, isSideboard: false, vm: vm)
                                    }
                                } header: {
                                    HStack {
                                        Text("\(section.label) (\(section.totalCards))")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.mtgText)

                                        Spacer()

                                        if section.missingCards > 0 {
                                            Text("Faltan \(section.missingCards)")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(Color.mtgRed)
                                        }

                                        if section.sectionTotalPrice > 0 {
                                            Text(section.sectionTotalPrice.formattedPrice(symbol: section.currencySymbol))
                                                .font(.caption2.monospacedDigit())
                                                .foregroundStyle(.mtgTextSecondary)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        if !vm.mainboardSorted.isEmpty {
                            Section("Mazo principal · \(vm.mainboardSorted.reduce(0) { $0 + $1.quantity }) cartas") {
                                ForEach(vm.mainboardSorted) { card in
                                    cardRow(card, isSideboard: false, vm: vm)
                                }
                            }
                        }
                    }

                    if !vm.sideboardSorted.isEmpty {
                        Section("Reservas · \(vm.sideboardSorted.reduce(0) { $0 + $1.quantity }) cartas") {
                            ForEach(vm.sideboardSorted) { card in
                                cardRow(card, isSideboard: true, vm: vm)
                            }
                        }
                    }

                    if !vm.matchingSearchText.isEmpty, vm.mainboardSorted.isEmpty, vm.sideboardSorted.isEmpty {
                        Section {
                            Text("No se encontraron cartas que coincidan con \"\(vm.deckSearchText)\".")
                                .font(.subheadline)
                                .foregroundStyle(.mtgTextSecondary)
                                .padding(.vertical, 8)
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
            .searchable(text: $vm.deckSearchText, prompt: "Buscar carta en el mazo…")

            if vm.detail != nil {
                floatingSortButton(vm)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color.mtgSurface)
            }
        }
    }

    @MainActor
    private func cardRow(_ card: DeckCardWithOwnership, isSideboard: Bool, vm: DeckDetailViewModel) -> some View {
        Button {
            selectedCard = card
        } label: {
            DeckCardRow(
                card: card,
                isSideboard: isSideboard
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
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
                Label("Eliminar del mazo", systemImage: "trash")
            }
        }
    }

    @MainActor
    private func floatingSortButton(_ vm: DeckDetailViewModel) -> some View {
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

            Divider()

            Toggle(isOn: $vm.filterMissingOnly) {
                Label("Solo faltantes", systemImage: "exclamationmark.circle")
            }
        }
    }

    // MARK: Header (commander info + compact completion metrics)

    @MainActor
    private func header(_ detail: DeckDetail, vm: DeckDetailViewModel) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    if detail.commander != nil {
                        ZStack {
                            if let url = AppConfiguration.imageURL(from: detail.commanderImageUri) {
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
                        } else if detail.format == "Commander" {
                            Button {
                                showingEdit = true
                            } label: {
                                Label("Asignar comandante", systemImage: "person.crop.circle.badge.plus")
                                    .font(.caption)
                                    .foregroundStyle(.mtgAmber)
                            }
                            .buttonStyle(.plain)
                        }

                        HStack(spacing: 6) {
                            if vm.commanderColorIdentity.isEmpty {
                                if detail.commander != nil {
                                    ManaPill(symbol: "C", style: .small)
                                }
                            } else {
                                ForEach(vm.commanderColorIdentity, id: \.self) { sym in
                                    ManaPill(symbol: sym, style: .small)
                                }
                            }

                            Spacer()

                            if let net = vm.priceSummary?.totalNetValue {
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(net.formattedPrice(symbol: vm.currencySymbol))
                                        .font(.subheadline.weight(.semibold).monospacedDigit())
                                        .foregroundStyle(.mtgText)
                                    Text("Precio neto")
                                        .font(.caption2)
                                        .foregroundStyle(.mtgTextSecondary)
                                }
                            }
                        }
                    }
                }

                if let description = detail.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.mtgTextSecondary)
                }

                Divider()

                // Compact completion metrics (no icons)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 0) {
                        compactMetric(value: "\(detail.totalCards)", label: "Cartas")
                        compactMetric(
                            value: (vm.priceSummary?.totalMissingValue ?? 0).formattedPrice(symbol: vm.currencySymbol),
                            label: "Precio restante",
                            valueColor: Color.mtgRed
                        )
                        compactMetric(value: "\(detail.missingCardsCount)", label: "Faltan", valueColor: Color.mtgRed)
                        compactMetric(
                            value: detail.completionPercentage.percentFormatted(),
                            label: "Completitud",
                            valueColor: detail.isComplete ? Color.mtgGreen : Color.mtgAmber
                        )
                    }

                    CompletionBar(progress: detail.completionPercentage)
                        .frame(height: 8)

                    if detail.missingCardsCount > 0 {
                        HStack(spacing: 8) {
                            Button {
                                isAddingMissingToCollection = true
                                Task {
                                    _ = try? await appStore.client.addMissingCardsToCollection(deckId: detail.id, userId: appStore.userId, accessToken: appStore.accessToken)
                                    await vm.load()
                                    isAddingMissingToCollection = false
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    if isAddingMissingToCollection {
                                        ProgressView().tint(.black)
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Tengo faltantes")
                                    }
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.mtgGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                            .disabled(isAddingMissingToCollection)

                            Button {
                                isAddingMissingToWants = true
                                Task {
                                    _ = try? await appStore.client.addDeckMissingToWants(deckId: detail.id, userId: appStore.userId, accessToken: appStore.accessToken)
                                    isAddingMissingToWants = false
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    if isAddingMissingToWants {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: "heart.fill")
                                        Text("+ A Wants")
                                    }
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.mtgText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.mtgSurfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                            .disabled(isAddingMissingToWants)

                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func compactMetric(value: String, label: String, valueColor: Color = .mtgText) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(valueColor)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.mtgTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Deck card row

struct DeckCardRow: View {
    let card: DeckCardWithOwnership
    var isSideboard = false

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

                // Fila 2: Tipo + Insignia de Expansión. Los valores económicos
                // se consultan juntos desde el botón de precios del mazo.
                HStack(alignment: .center, spacing: 6) {
                    if let typeLine = card.typeLine, !typeLine.isEmpty {
                        Text(typeLine)
                            .font(.caption2)
                            .foregroundStyle(.mtgTextSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    SetExpansionBadge(setCode: card.setCode)
                }

                // Fila 3: Indicadores de posesión (falta, en colección, en otro mazo)
                HStack(spacing: 5) {
                    if card.missingCount > 0 {
                        OwnershipStatusChip(
                            text: "Falta \(card.missingCount)",
                            systemImage: "exclamationmark.circle.fill",
                            tint: .mtgRed
                        )
                    }

                    if card.ownedInCollection > 0 {
                        OwnershipStatusChip(
                            text: "En colección: \(card.ownedInCollection)",
                            systemImage: "checkmark.circle.fill",
                            tint: .mtgGreen
                        )
                    }

                    let otherCount = card.assignedInOtherDecks.reduce(0) { $0 + $1.quantity }
                    if otherCount > 0 {
                        OwnershipStatusChip(
                            text: "En otro mazo (\(otherCount))",
                            systemImage: "arrow.triangle.swap",
                            tint: .mtgAmber
                        )
                    }
                }
                .padding(.top, 1)
            }
        }
        .padding(.vertical, 3)
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
