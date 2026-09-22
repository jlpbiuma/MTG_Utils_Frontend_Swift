import SwiftUI

// MARK: - Prices View (Movers & Trends)

struct PricesView: View {
    @Environment(AppStore.self) private var appStore

    @State private var provider: PriceProvider = .cardmarket
    @State private var scope: MoversScope = .global
    @State private var moversResponse: PriceMoversResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedCardForDetail: PriceMoverItem?

    var body: some View {
        Group {
            if isLoading && moversResponse == nil {
                ProgressView("Cargando tendencias de precios…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                EmptyStateView(
                    title: "Error al cargar precios",
                    message: error,
                    systemImage: "exclamationmark.triangle",
                    actionTitle: "Reintentar",
                    action: { Task { await loadMovers() } }
                )
            } else if let movers = moversResponse {
                content(movers)
            }
        }
        .navigationTitle("Precios")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await loadMovers() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Actualizar precios")
            }
        }
        .task {
            provider = appStore.settings.priceProvider
            await loadMovers()
        }
        .sheet(item: $selectedCardForDetail) { mover in
            CardDetailView(
                card: DeckCardWithOwnership(
                    id: mover.printingId,
                    deckId: "",
                    cardScryfallId: mover.printingId,
                    cardName: mover.cardName,
                    quantity: 1,
                    assignedQuantity: 0,
                    isSideboard: false,
                    isCommander: false,
                    manaCost: nil,
                    typeLine: nil,
                    imageUri: mover.imageUri,
                    setCode: mover.setCode,
                    ownedInCollection: 0,
                    availableToAssign: 0,
                    assignedInOtherDecks: [],
                    missingCount: 0
                ),
                unitPrice: mover.currentPrice,
                currencySymbol: mover.currencySymbol,
                provider: provider,
                client: appStore.client
            )
        }
    }

    // MARK: - Content

    private func content(_ movers: PriceMoversResponse) -> some View {
        List {
            // Controls Section
            Section {
                // Scope selector
                Picker("Ámbito", selection: $scope) {
                    Text("Mercado Global").tag(MoversScope.global)
                    Text("Mi Colección").tag(MoversScope.collection)
                }
                .pickerStyle(.segmented)
                .onChange(of: scope) { _, _ in
                    Task { await loadMovers() }
                }

                // Provider picker
                Picker("Proveedor", selection: $provider) {
                    ForEach(PriceProvider.allCases) { prov in
                        Text(prov.displayName).tag(prov)
                    }
                }
                .onChange(of: provider) { _, _ in
                    Task { await loadMovers() }
                }
            }

            // Top Gainers (Subidas)
            Section {
                if movers.gainers.isEmpty {
                    Text("No hay variaciones destacadas en este período.")
                        .font(.subheadline)
                        .foregroundStyle(Color.mtgTextSecondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(movers.gainers) { item in
                        moverRow(item: item, isGainer: true)
                    }
                }
            } header: {
                Label("Top Subidas (Últimos \(movers.windowDays) días)", systemImage: "arrow.up.right.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.mtgGreen)
            }

            // Top Losers (Bajadas)
            Section {
                if movers.losers.isEmpty {
                    Text("No hay variaciones destacadas en este período.")
                        .font(.subheadline)
                        .foregroundStyle(Color.mtgTextSecondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(movers.losers) { item in
                        moverRow(item: item, isGainer: false)
                    }
                }
            } header: {
                Label("Top Bajadas (Últimos \(movers.windowDays) días)", systemImage: "arrow.down.right.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.mtgRed)
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await loadMovers()
        }
    }

    // MARK: - Mover Row

    private func moverRow(item: PriceMoverItem, isGainer: Bool) -> some View {
        Button {
            selectedCardForDetail = item
        } label: {
            HStack(spacing: 12) {
                // Thumbnail
                if let uri = item.imageUri, let url = URL(string: uri) {
                    CardImageView(url: url, placeholderText: nil, targetSize: 120)
                        .frame(width: 40, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                // Card info
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.cardName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.mtgText)

                    HStack(spacing: 6) {
                        if let setCode = item.setCode {
                            Text(setCode.uppercased())
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.mtgSurfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .foregroundStyle(Color.mtgTextSecondary)
                        }

                        Text("Antes: \(item.baselinePrice.formattedPrice(symbol: item.currencySymbol))")
                            .font(.caption2)
                            .foregroundStyle(Color.mtgTextSecondary)
                    }
                }

                Spacer()

                // Price & Percentage Change
                VStack(alignment: .trailing, spacing: 3) {
                    Text(item.currentPrice.formattedPrice(symbol: item.currencySymbol))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.mtgText)

                    HStack(spacing: 2) {
                        Image(systemName: isGainer ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2)
                        Text("\(isGainer ? "+" : "")\(String(format: "%.1f", item.changePct))%")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(isGainer ? Color.mtgGreen : Color.mtgRed)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func loadMovers() async {
        isLoading = true
        errorMessage = nil
        do {
            moversResponse = try await appStore.client.priceMovers(
                provider: provider,
                windowDays: 30,
                limit: 20,
                scope: scope,
                userId: appStore.userId,
                accessToken: appStore.accessToken
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
