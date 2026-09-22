import SwiftUI

// MARK: - Priorities View

struct PrioritiesView: View {
    @Environment(AppStore.self) private var appStore

    @State private var data: PrioritiesResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?

    // Filters
    @State private var sortMode = "demand" // demand, impact, completion
    @State private var reassignableOnly = false
    @State private var hideOwned = true
    @State private var selectedCardType = "all"
    @State private var searchQuery = ""

    // Modal states
    @State private var itemToReassign: PriorityItem?
    @State private var selectedCardForDetail: PriorityItem?
    @State private var addedWants: Set<String> = []
    @State private var showingGoldenWants = false

    private let cardTypes = [
        ("all", "Todos"),
        ("creatures", "Criaturas"),
        ("lands", "Tierras"),
        ("instants", "Instantáneos"),
        ("sorceries", "Conjuros"),
        ("artifacts", "Artefactos"),
        ("enchantments", "Encantamientos"),
        ("planeswalkers", "Planeswalkers"),
    ]

    var body: some View {
        Group {
            if isLoading && data == nil {
                ProgressView("Calculando prioridades de compra…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                EmptyStateView(
                    title: "Error al cargar prioridades",
                    message: error,
                    systemImage: "exclamationmark.triangle",
                    actionTitle: "Reintentar",
                    action: { Task { await loadData() } }
                )
            } else if let data {
                content(data)
            }
        }
        .task { await loadData() }
        .sheet(item: $itemToReassign) { item in
            CardReassignSheet(item: item) { sourceDeckId, targetDeckId, cardScryfallId, quantity in
                await handleReassign(sourceDeckId: sourceDeckId, targetDeckId: targetDeckId, cardScryfallId: cardScryfallId, quantity: quantity)
            }
        }
        .sheet(isPresented: $showingGoldenWants) {
            GoldenWantsSheet(items: data?.items ?? [], currencySymbol: data?.currencySymbol ?? "€")
        }
    }

    // MARK: - Main Content

    private func content(_ data: PrioritiesResponse) -> some View {
        VStack(spacing: 0) {
            // Filter Bar
            filterHeader

            List {
                // KPI Strip
                Section {
                    KPIStripView(stats: [
                        KPIStat(
                            id: "unique",
                            label: "Cartas a comprar",
                            value: "\(data.totalUniqueCards)",
                            systemImage: "cart",
                            tint: .mtgAmber
                        ),
                        KPIStat(
                            id: "copies",
                            label: "Copias necesarias",
                            value: "\(data.totalDeficitCopies)",
                            systemImage: "rectangle.stack",
                            tint: .mtgGreen
                        ),
                        KPIStat(
                            id: "cost",
                            label: "Coste estimado",
                            value: data.totalDeficitCost.formattedPrice(symbol: data.currencySymbol),
                            systemImage: "eurosign.circle",
                            tint: .mtgAmber
                        )
                    ])

                    // Golden Wants Banner
                    Button {
                        showingGoldenWants = true
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(Color.mtgAmber)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Optimizador Golden Wants")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.mtgText)
                                Text("Calcula las mejores cartas a comprar para un presupuesto dado.")
                                    .font(.caption2)
                                    .foregroundStyle(Color.mtgTextSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Color.mtgTextSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Cards List
                Section {
                    let filteredItems = (data.items).filter { item in
                        searchQuery.isEmpty || item.cardName.localizedCaseInsensitiveContains(searchQuery)
                    }

                    if filteredItems.isEmpty {
                        Text("No se encontraron cartas con los filtros actuales.")
                            .font(.subheadline)
                            .foregroundStyle(Color.mtgTextSecondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(filteredItems) { item in
                            priorityRow(item: item, currencySymbol: data.currencySymbol)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchQuery, prompt: "Buscar carta en prioridades…")
        }
    }

    // MARK: - Filters

    private var filterHeader: some View {
        VStack(spacing: 8) {
            // Sort mode picker
            Picker("Ordenación", selection: $sortMode) {
                Text("Demanda").tag("demand")
                Text("Impacto").tag("impact")
                Text("Completitud").tag("completion")
            }
            .pickerStyle(.segmented)
            .onChange(of: sortMode) { _, _ in Task { await loadData() } }

            HStack {
                // Card type scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(cardTypes, id: \.0) { typeKey, typeLabel in
                            Button {
                                selectedCardType = typeKey
                                Task { await loadData() }
                            } label: {
                                Text(typeLabel)
                                    .font(.caption.weight(selectedCardType == typeKey ? .bold : .regular))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(selectedCardType == typeKey ? Color.mtgAmber : Color.mtgSurfaceElevated)
                                    .foregroundStyle(selectedCardType == typeKey ? Color.black : Color.mtgText)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer()

                // Reassignable toggle
                Toggle(isOn: $reassignableOnly) {
                    Image(systemName: "arrow.right.arrow.left")
                        .foregroundStyle(reassignableOnly ? Color.mtgAmber : Color.mtgTextSecondary)
                }
                .toggleStyle(.button)
                .tint(Color.mtgAmber)
                .onChange(of: reassignableOnly) { _, _ in Task { await loadData() } }
                .accessibilityLabel("Solo reasignables")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.mtgSurface)
    }

    // MARK: - Priority Row

    private func priorityRow(item: PriorityItem, currencySymbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                // Thumbnail
                if let uri = item.imageUri, let url = URL(string: uri) {
                    CardImageView(url: url, placeholderText: nil, targetSize: 120)
                        .frame(width: 44, height: 62)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                // Card info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.cardName)
                            .font(.headline)
                            .foregroundStyle(Color.mtgText)
                        Spacer()
                        Text(item.price.formattedPrice(symbol: currencySymbol))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.mtgAmber)
                    }

                    HStack(spacing: 6) {
                        ManaCostView(cost: item.manaCost)
                        Text("· \(item.numDecks) \(item.numDecks == 1 ? "mazo" : "mazos")")
                            .font(.caption)
                            .foregroundStyle(Color.mtgTextSecondary)
                    }

                    Text("Faltan \(item.deficit) copias (Total: \(item.totalDeficitCost.formattedPrice(symbol: currencySymbol)))")
                        .font(.caption2)
                        .foregroundStyle(Color.mtgTextSecondary)
                }
            }

            // Decks needing this card
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(item.decks) { deck in
                        HStack(spacing: 4) {
                            Text(deck.deckName)
                                .font(.caption2.weight(.medium))
                            Text("(\(Int(deck.completionPercentage))%)")
                                .font(.caption2)
                                .foregroundStyle(Color.mtgAmber)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.mtgSurfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }

            // Action buttons
            HStack(spacing: 8) {
                if item.isReassignable {
                    Button {
                        itemToReassign = item
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right.arrow.left")
                            Text("Reasignar (\(item.reassignOptions.count))")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.mtgAmber)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    Task { await handleAddToWants(item: item) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: addedWants.contains(item.cardScryfallId) ? "checkmark" : "heart.fill")
                        Text(addedWants.contains(item.cardScryfallId) ? "En Wants" : "+ A Wants")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(addedWants.contains(item.cardScryfallId) ? Color.mtgGreen : Color.mtgText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.mtgSurfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(addedWants.contains(item.cardScryfallId))

                Spacer()
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Actions

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            data = try await appStore.client.priorities(
                sort: sortMode,
                reassignableOnly: reassignableOnly,
                hideOwned: hideOwned,
                cardType: selectedCardType == "all" ? nil : selectedCardType,
                provider: appStore.settings.priceProvider,
                userId: appStore.userId,
                accessToken: appStore.accessToken
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func handleReassign(sourceDeckId: String, targetDeckId: String, cardScryfallId: String, quantity: Int) async {
        do {
            _ = try await appStore.client.reassignCard(
                sourceDeckId: sourceDeckId,
                targetDeckId: targetDeckId,
                cardScryfallId: cardScryfallId,
                quantity: quantity,
                userId: appStore.userId,
                accessToken: appStore.accessToken
            )
            await loadData()
        } catch {
            errorMessage = "No se pudo reasignar la carta: \(error.localizedDescription)"
        }
    }

    private func handleAddToWants(item: PriorityItem) async {
        do {
            _ = try await appStore.client.addWant(
                data: WantCardCreate(
                    cardScryfallId: item.cardScryfallId,
                    cardName: item.cardName,
                    quantity: max(1, item.deficit),
                    manaCost: item.manaCost,
                    typeLine: item.typeLine,
                    imageUri: item.imageUri
                ),
                userId: appStore.userId,
                accessToken: appStore.accessToken
            )
            addedWants.insert(item.cardScryfallId)
        } catch {
            errorMessage = "Error al añadir a wants: \(error.localizedDescription)"
        }
    }
}

// MARK: - Golden Wants Solver Sheet

struct GoldenWantsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let items: [PriorityItem]
    let currencySymbol: String

    @State private var budget: Double = 30.0

    private var selectedCards: [PriorityItem] {
        // Greedy solver: picks items that give highest sumPointsGain / cost within budget
        var remainingBudget = budget
        var result: [PriorityItem] = []
        let sorted = items.filter { $0.price > 0 }.sorted {
            ($0.sumPointsGain / max(0.1, $0.price)) > ($1.sumPointsGain / max(0.1, $1.price))
        }
        for item in sorted {
            if item.price <= remainingBudget {
                result.append(item)
                remainingBudget -= item.price
            }
        }
        return result
    }

    private var totalCost: Double {
        selectedCards.reduce(0) { $0 + $1.price }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    HStack {
                        Text("Presupuesto: \(Int(budget))\(currencySymbol)")
                            .font(.headline)
                            .foregroundStyle(Color.mtgAmber)
                        Spacer()
                        Text("Gasto: \(totalCost.formattedPrice(symbol: currencySymbol))")
                            .font(.subheadline)
                            .foregroundStyle(Color.mtgTextSecondary)
                    }

                    Slider(value: $budget, in: 10...200, step: 5)
                        .tint(Color.mtgAmber)
                }
                .padding()
                .background(Color.mtgSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                List(selectedCards) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.cardName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.mtgText)
                            Text("Para \(item.numDecks) \(item.numDecks == 1 ? "mazo" : "mazos")")
                                .font(.caption2)
                                .foregroundStyle(Color.mtgTextSecondary)
                        }
                        Spacer()
                        Text(item.price.formattedPrice(symbol: currencySymbol))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.mtgAmber)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .padding()
            .navigationTitle("Golden Wants Optimizer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}
