import SwiftUI
import Charts

// MARK: - Pricing sheet

struct PricingSheet: View {
    @Environment(AppStore.self) private var appStore
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
        .task {
            viewModel.selectedProvider = appStore.settings.priceProvider
            if let backendStore = appStore.store as? BackendDataStore {
                await viewModel.loadFromBackend(for: detail, store: backendStore, provider: appStore.settings.priceProvider)
            } else {
                await viewModel.load(for: detail, collection: [])
            }
        }
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
                LabeledContent("Valor total", value: summary.totalNetValue.formattedPrice(symbol: summary.currencySymbol))
                if let owned = summary.totalOwnedValue {
                    LabeledContent("Valor en posesión", value: owned.formattedPrice(symbol: summary.currencySymbol))
                        .foregroundStyle(Color.mtgGreen)
                }
                if let missing = summary.totalMissingValue {
                    LabeledContent("Valor de las faltantes", value: missing.formattedPrice(symbol: summary.currencySymbol))
                        .foregroundStyle(Color.mtgRed)
                }
            }

            Section("Completitud por cartas") {
                donutChart(
                    slices: countSlices,
                    centerTitle: "\(detail.missingCardsCount)",
                    centerSubtitle: "faltan"
                )
            }

            Section("Valor en posesión vs faltante") {
                donutChart(
                    slices: valueSlices,
                    centerTitle: summary.currencySymbol + (summary.totalMissingValue ?? 0).formattedPrice(symbol: ""),
                    centerSubtitle: "faltan"
                )
            }

        }
    }

    // MARK: Chart data

    private var countSlices: [PriceSlice] {
        [
            PriceSlice(label: "Tienes", value: Double(detail.ownedCards), color: .mtgGreen),
            PriceSlice(label: "Faltan", value: Double(detail.missingCardsCount), color: .mtgRed),
        ]
    }

    private var valueSlices: [PriceSlice] {
        [
            PriceSlice(label: "En posesión", value: viewModel.summary?.totalOwnedValue ?? 0, color: .mtgGreen),
            PriceSlice(label: "Faltante", value: viewModel.summary?.totalMissingValue ?? 0, color: .mtgRed),
        ]
    }

    // MARK: Donut chart

    @MainActor
    private func donutChart(slices: [PriceSlice], centerTitle: String, centerSubtitle: String) -> some View {
        let total = slices.reduce(0) { $0 + $1.value }
        return HStack(spacing: 16) {
            Chart {
                ForEach(slices) { slice in
                    SectorMark(
                        angle: .value("Valor", slice.value),
                        innerRadius: .ratio(0.62),
                        angularInset: 1.5
                    )
                    .foregroundStyle(slice.color)
                }
            }
            .chartBackground { _ in
                VStack(spacing: 2) {
                    if total > 0 {
                        Text(centerTitle)
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(.mtgText)
                        Text(centerSubtitle)
                            .font(.caption2)
                            .foregroundStyle(.mtgTextSecondary)
                    } else {
                        Text("—")
                            .font(.headline)
                            .foregroundStyle(.mtgTextSecondary)
                    }
                }
            }
            .frame(width: 120, height: 120)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(slices) { slice in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(slice.color)
                            .frame(width: 8, height: 8)
                        Text(slice.label)
                            .font(.caption)
                            .foregroundStyle(.mtgTextSecondary)
                        Spacer(minLength: 0)
                        Text(formatValue(slice.value))
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.mtgText)
                    }
                    .frame(maxWidth: 160)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private func formatValue(_ value: Double) -> String {
        value == value.rounded()
            ? "\(Int(value))"
            : value.formattedPrice(symbol: "")
    }

    // MARK: Empty / zero handling
}

// MARK: - Slice model

private struct PriceSlice: Identifiable {
    let id: String
    let label: String
    let value: Double
    let color: Color

    init(label: String, value: Double, color: Color) {
        self.id = label
        self.label = label
        self.value = value
        self.color = color
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
