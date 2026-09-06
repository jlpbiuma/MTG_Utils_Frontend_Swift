import SwiftUI

// MARK: - Pricing sheet

struct PricingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = PricingViewModel()
    let detail: DeckDetail

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.summary == nil {
                    ProgressView("Consultando precios…")
                } else if let summary = viewModel.summary {
                    content(summary)
                } else {
                    ContentUnavailableView {
                        Label("Sin precios", systemImage: "eurosign.circle")
                    } description: {
                        Text("No se pudieron obtener precios para este mazo.")
                    }
                }
            }
            .navigationTitle("Precios")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
        .tint(.mtgAmber)
        .task { await viewModel.load(for: detail, collection: []) }
    }

    @MainActor
    private func content(_ summary: PriceSummary) -> some View {
        List {
            Section {
                Picker("Proveedor", selection: $viewModel.selectedProvider) {
                    ForEach(PriceProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: viewModel.selectedProvider) {
                    Task { await viewModel.selectProvider(viewModel.selectedProvider) }
                }
            }

            Section("Resumen (\(summary.currency))") {
                LabeledContent("Cartas totales", value: "\(summary.totalCards)")
                LabeledContent("Valor total", value: summary.totalNetValue.formattedPrice(symbol: summary.currencySymbol))
                if let owned = summary.totalOwnedValue {
                    LabeledContent("Valor de lo que tienes", value: owned.formattedPrice(symbol: summary.currencySymbol))
                        .foregroundStyle(Color.mtgGreen)
                }
                if let missing = summary.totalMissingValue {
                    LabeledContent("Valor de las faltantes", value: missing.formattedPrice(symbol: summary.currencySymbol))
                        .foregroundStyle(Color.mtgRed)
                }
            }

            Section("Por carta") {
                ForEach(detail.mainboardCards) { card in
                    if let quote = summary.quote(forCardScryfallId: card.cardScryfallId, normalizedName: normalizeCardName(card.cardName)) {
                        HStack {
                            Text(card.cardName)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(quote.unitPrice.trend.formattedPrice(symbol: summary.currencySymbol))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.mtgText)
                                Text("×\(quote.quantity) = \(quote.subtotal.formattedPrice(symbol: summary.currencySymbol))")
                                    .font(.caption2)
                                    .foregroundStyle(.mtgTextSecondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    PricingSheet(detail: DeckDetail(
        id: "1",
        userId: "u",
        name: "Esper Control",
        format: "Modern",
        createdAt: Date(),
        updatedAt: Date(),
        totalCards: 32,
        uniqueCards: 10,
        ownedCards: 24,
        missingCardsCount: 8,
        completionPercentage: 75,
        cards: []
    ))
    .preferredColorScheme(.dark)
}