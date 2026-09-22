import SwiftUI

// MARK: - Dormant Cards View (Detector de Cartas Dormidas)

struct DormantCardsView: View {
    @Environment(AppStore.self) private var appStore

    @State private var response: DormantCardsResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var minPrice: Double = 0.0
    @State private var searchQuery = ""
    @State private var copiedToClipboard = false
    @State private var selectedCardForDetail: DormantCardItem?

    var body: some View {
        Group {
            if isLoading && response == nil {
                ProgressView("Detectando cartas dormidas en tu colección…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                EmptyStateView(
                    title: "Error al detectar cartas dormidas",
                    message: error,
                    systemImage: "exclamationmark.triangle",
                    actionTitle: "Reintentar",
                    action: { Task { await loadData() } }
                )
            } else if let resp = response {
                content(resp)
            }
        }
        .task { await loadData() }
        .sheet(item: $selectedCardForDetail) { card in
            CardDetailView(
                card: DeckCardWithOwnership(
                    id: card.id,
                    deckId: "",
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
                ),
                unitPrice: card.price,
                currencySymbol: response?.currencySymbol ?? "€",
                provider: appStore.settings.priceProvider,
                client: appStore.client
            )
        }
    }

    // MARK: - Content

    private func content(_ resp: DormantCardsResponse) -> some View {
        let filteredCards = resp.cards.filter { card in
            searchQuery.isEmpty || card.cardName.localizedCaseInsensitiveContains(searchQuery)
        }
        let totalFilteredValue = filteredCards.reduce(0.0) { $0 + $1.totalValue }

        return List {
            // Explanatory & Value Banner
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        Image(systemName: "moon.stars.fill")
                            .font(.title2)
                            .foregroundStyle(Color.mtgAmber)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Detector de Cartas Dormidas")
                                .font(.headline)
                                .foregroundStyle(Color.mtgText)

                            Text("Cartas físicas en tu colección que no están asignadas a ningún mazo ni recomendadas por EDHREC para tus comandantes activos.")
                                .font(.caption)
                                .foregroundStyle(Color.mtgTextSecondary)
                        }
                    }

                    Divider()

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Valor liquidable total:")
                                .font(.caption2)
                                .foregroundStyle(Color.mtgTextSecondary)
                            Text(totalFilteredValue.formattedPrice(symbol: resp.currencySymbol))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color.mtgGreen)
                        }

                        Spacer()

                        Button {
                            copyList(cards: filteredCards)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: copiedToClipboard ? "checkmark" : "doc.on.doc")
                                Text(copiedToClipboard ? "Copiado" : "Copiar lista")
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
                }
                .padding(.vertical, 4)
            }

            // Min price filter
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Precio mínimo:")
                            .font(.caption)
                            .foregroundStyle(Color.mtgTextSecondary)
                        Spacer()
                        Text(minPrice > 0 ? "\(String(format: "%.1f", minPrice))\(resp.currencySymbol)" : "Todas")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.mtgAmber)
                    }

                    Slider(value: $minPrice, in: 0...10, step: 0.5)
                        .tint(Color.mtgAmber)
                        .onChange(of: minPrice) { _, _ in
                            Task { await loadData() }
                        }
                }
                .padding(.vertical, 2)
            }

            // Cards list
            Section("\(filteredCards.count) cartas dormidas") {
                if filteredCards.isEmpty {
                    Text("No hay cartas dormidas con los filtros actuales.")
                        .font(.subheadline)
                        .foregroundStyle(Color.mtgTextSecondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(filteredCards) { card in
                        dormantCardRow(card: card, currencySymbol: resp.currencySymbol)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchQuery, prompt: "Buscar carta dormida…")
    }

    private func dormantCardRow(card: DormantCardItem, currencySymbol: String) -> some View {
        Button {
            selectedCardForDetail = card
        } label: {
            HStack(spacing: 12) {
                if let uri = card.imageUri, let url = URL(string: uri) {
                    CardImageView(url: url, placeholderText: nil, targetSize: 120)
                        .frame(width: 40, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                VStack(alignment: .leading, spacing: 3) {
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
                        Text("\(card.quantity) \(card.quantity == 1 ? "copia" : "copias")")
                            .font(.caption2)
                            .foregroundStyle(Color.mtgTextSecondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(card.totalValue.formattedPrice(symbol: currencySymbol))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.mtgAmber)
                    if card.quantity > 1 {
                        Text("\(card.price.formattedPrice(symbol: currencySymbol))/ud")
                            .font(.caption2)
                            .foregroundStyle(Color.mtgTextSecondary)
                    }
                }
            }
            .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            response = try await appStore.client.dormantCards(
                minPrice: minPrice,
                provider: appStore.settings.priceProvider,
                userId: appStore.userId,
                accessToken: appStore.accessToken
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func copyList(cards: [DormantCardItem]) {
        let lines = cards.map { "\($0.quantity) \($0.cardName)" }
        UIPasteboard.general.string = lines.joined(separator: "\n")
        copiedToClipboard = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedToClipboard = false
        }
    }
}
