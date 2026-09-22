import SwiftUI

// MARK: - Wants View

struct WantsView: View {
    @Environment(AppStore.self) private var appStore

    @State private var queryResponse: WantQueryResponse?
    @State private var moversResponse: PriceMoversResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var searchQuery = ""
    @State private var isGrouped = true
    @State private var showingAddCard = false
    @State private var cardToDelete: WantCardResponse?
    @State private var copiedToClipboard = false

    var body: some View {
        Group {
            if isLoading && queryResponse == nil {
                ProgressView("Cargando lista de deseos (Wants)…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                EmptyStateView(
                    title: "Error al cargar Wants",
                    message: error,
                    systemImage: "exclamationmark.triangle",
                    actionTitle: "Reintentar",
                    action: { Task { await loadData() } }
                )
            } else if let response = queryResponse {
                content(response)
            }
        }
        .task { await loadData() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddCard = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Añadir carta a Wants")
            }

            ToolbarItem(placement: .secondaryAction) {
                Button {
                    copyWantsList()
                } label: {
                    Label(copiedToClipboard ? "Copiado" : "Exportar lista", systemImage: copiedToClipboard ? "checkmark" : "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showingAddCard) {
            NavigationStack {
                CardSearchPickerView(title: "Añadir a Wants") { card in
                    Task { await handleAddCard(card: card) }
                }
            }
        }
        .alert(item: $cardToDelete) { card in
            Alert(
                title: Text("¿Eliminar \(card.cardName)?"),
                message: Text("Se eliminará de tu lista de deseos."),
                primaryButton: .destructive(Text("Eliminar")) {
                    Task { await handleDelete(card: card) }
                },
                secondaryButton: .cancel()
            )
        }
    }

    // MARK: - Content

    private func content(_ response: WantQueryResponse) -> some View {
        List {
            // KPI Strip
            Section {
                KPIStripView(stats: [
                    KPIStat(
                        id: "unique",
                        label: "Cartas únicas",
                        value: "\(response.uniqueCards)",
                        systemImage: "heart.fill",
                        tint: .mtgAmber
                    ),
                    KPIStat(
                        id: "total",
                        label: "Total cartas",
                        value: "\(response.totalCards)",
                        systemImage: "shippingbox.fill",
                        tint: .mtgGreen
                    ),
                    KPIStat(
                        id: "provider",
                        label: "Proveedor",
                        value: response.provider.uppercased(),
                        systemImage: "eurosign.circle",
                        tint: .mtgAmber
                    )
                ])
            }

            // Wants Price Movers (if available)
            if let movers = moversResponse, (!movers.gainers.isEmpty || !movers.losers.isEmpty) {
                Section("Tendencias de Precios en Wants") {
                    wantsPriceMoversBanner(movers)
                }
            }

            // Cards Content
            if response.grouped {
                ForEach(response.sections) { section in
                    Section(section.label) {
                        ForEach(section.cards) { card in
                            wantCardRow(card: card, currencySymbol: response.currencySymbol)
                        }
                    }
                }
            } else {
                Section("Todas las cartas") {
                    ForEach(response.cards) { card in
                        wantCardRow(card: card, currencySymbol: response.currencySymbol)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchQuery, prompt: "Buscar en wants…")
        .onChange(of: searchQuery) { _, _ in
            Task { await loadData() }
        }
    }

    // MARK: - Wants Price Movers Banner

    private func wantsPriceMoversBanner(_ movers: PriceMoversResponse) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(movers.gainers.prefix(4)) { item in
                    moverPill(item: item, isGainer: true)
                }
                ForEach(movers.losers.prefix(4)) { item in
                    moverPill(item: item, isGainer: false)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func moverPill(item: PriceMoverItem, isGainer: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isGainer ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(isGainer ? Color.mtgGreen : Color.mtgRed)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.cardName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.mtgText)
                    .lineLimit(1)
                Text("\(item.changePct >= 0 ? "+" : "")\(String(format: "%.1f", item.changePct))%")
                    .font(.caption2)
                    .foregroundStyle(isGainer ? Color.mtgGreen : Color.mtgRed)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.mtgSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Want Card Row

    private func wantCardRow(card: WantCardResponse, currencySymbol: String) -> some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let uri = card.imageUri, let url = URL(string: uri) {
                CardImageView(url: url, placeholderText: nil, targetSize: 120)
                    .frame(width: 40, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(card.cardName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.mtgText)

                HStack(spacing: 6) {
                    ManaCostView(cost: card.manaCost)
                    if let setCode = card.setCode {
                        Text(setCode.uppercased())
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.mtgSurfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .foregroundStyle(Color.mtgTextSecondary)
                    }
                }

                // Decks requesting this card
                if !card.requestedInDecks.isEmpty {
                    HStack(spacing: 4) {
                        Text("En \(card.requestedInDecks.count) \(card.requestedInDecks.count == 1 ? "mazo" : "mazos"):")
                            .font(.caption2)
                            .foregroundStyle(Color.mtgTextSecondary)
                        ForEach(card.requestedInDecks.prefix(2)) { req in
                            Text(req.deckName)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(Color.mtgAmber)
                        }
                    }
                }
            }

            Spacer()

            // Quantity Controls
            HStack(spacing: 6) {
                Button {
                    Task { await handleUpdateQuantity(card: card, delta: -1) }
                } label: {
                    Image(systemName: "minus")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.mtgTextSecondary)
                        .frame(width: 24, height: 24)
                        .background(Color.mtgSurfaceElevated)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Text("\(card.quantity)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.mtgText)
                    .frame(minWidth: 20, alignment: .center)

                Button {
                    Task { await handleUpdateQuantity(card: card, delta: 1) }
                } label: {
                    Image(systemName: "plus")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.mtgText)
                        .frame(width: 24, height: 24)
                        .background(Color.mtgSurfaceElevated)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                cardToDelete = card
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
    }

    // MARK: - Actions

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            async let queryTask = appStore.client.wantsQuery(
                query: searchQuery.isEmpty ? nil : searchQuery,
                sort: "name",
                direction: "asc",
                grouped: isGrouped,
                priceProvider: appStore.settings.priceProvider,
                userId: appStore.userId,
                accessToken: appStore.accessToken
            )
            async let moversTask = appStore.client.priceMovers(
                provider: appStore.settings.priceProvider,
                windowDays: 30,
                limit: 10,
                scope: .wants,
                userId: appStore.userId,
                accessToken: appStore.accessToken
            )

            queryResponse = try await queryTask
            moversResponse = try? await moversTask
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func handleAddCard(card: ScryfallCard) async {
        do {
            _ = try await appStore.client.addWant(
                data: WantCardCreate(
                    cardScryfallId: card.id,
                    cardName: card.name,
                    quantity: 1,
                    setCode: card.set,
                    collectorNumber: card.collectorNumber,
                    manaCost: card.displayManaCost,
                    typeLine: card.displayTypeLine,
                    imageUri: card.displayImageUri
                ),
                userId: appStore.userId,
                accessToken: appStore.accessToken
            )
            await loadData()
        } catch {
            errorMessage = "Error al añadir carta a wants: \(error.localizedDescription)"
        }
    }

    private func handleUpdateQuantity(card: WantCardResponse, delta: Int) async {
        let newQty = card.quantity + delta
        if newQty <= 0 {
            cardToDelete = card
            return
        }
        do {
            _ = try await appStore.client.updateWantQuantity(
                cardId: card.id,
                quantity: newQty,
                setCode: card.setCode,
                userId: appStore.userId,
                accessToken: appStore.accessToken
            )
            await loadData()
        } catch {
            errorMessage = "Error al actualizar cantidad: \(error.localizedDescription)"
        }
    }

    private func handleDelete(card: WantCardResponse) async {
        do {
            _ = try await appStore.client.deleteWant(
                cardId: card.id,
                userId: appStore.userId,
                accessToken: appStore.accessToken
            )
            await loadData()
        } catch {
            errorMessage = "Error al eliminar de wants: \(error.localizedDescription)"
        }
    }

    private func copyWantsList() {
        guard let response = queryResponse else { return }
        let allCards = response.grouped ? response.sections.flatMap { $0.cards } : response.cards
        let lines = allCards.map { "\($0.quantity) \($0.cardName)" }
        UIPasteboard.general.string = lines.joined(separator: "\n")
        copiedToClipboard = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedToClipboard = false
        }
    }
}
