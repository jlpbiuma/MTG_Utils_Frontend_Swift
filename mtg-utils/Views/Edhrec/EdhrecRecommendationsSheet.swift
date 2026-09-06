import SwiftUI

// MARK: - EDHREC recommendations sheet

struct EdhrecRecommendationsSheet: View {
    @Environment(AppStore.self) private var appStore
    @Environment(\.dismiss) private var dismiss

    let commanderName: String
    let deckCards: [DeckCardWithOwnership]

    @State private var viewModel: EdhrecViewModel?
    @State private var selectedCategory: String?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    content(viewModel)
                } else {
                    ProgressView("Consultando EDHREC…")
                }
            }
            .navigationTitle("Recomendaciones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
        .tint(.mtgAmber)
        .onAppear {
            let cards = deckCards.map { card in
                DeckCard(
                    cardScryfallId: card.cardScryfallId,
                    cardName: card.cardName,
                    quantity: card.quantity
                )
            }
            let vm = EdhrecViewModel(
                client: .shared,
                commanderName: commanderName,
                deckCards: cards,
                collection: []
            )
            viewModel = vm
            Task {
                let stored = (try? await appStore.store.allCollection()) ?? []
                vm.collection = stored
                await vm.load(commanderName: commanderName)
            }
        }
    }

    @MainActor
    private func content(_ viewModel: EdhrecViewModel) -> some View {
        VStack(spacing: 0) {
            if let result = viewModel.result {
                if let error = result.error, result.recommendations.isEmpty {
                    ContentUnavailableView {
                        Label("Sin datos", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(error)
                    } actions: {
                        Link("Abrir página en EDHREC", destination: edhrecPageUrl(for: commanderName) ?? URL(string: "https://edhrec.com")!)
                    }
                } else {
                    categoryPicker(viewModel)

                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.recommendations) { rec in
                                EdhrecCardRow(recommendation: rec)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
    }

    @MainActor
    private func categoryPicker(_ viewModel: EdhrecViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    selectedCategory = nil
                } label: {
                    Text("Todo")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            selectedCategory == nil
                                ? Color.mtgAmber.opacity(0.25)
                                : Color.mtgSurfaceElevated,
                            in: Capsule()
                        )
                        .foregroundStyle(.mtgText)
                }

                ForEach(viewModel.categories, id: \.self) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                selectedCategory == category
                                    ? Color.mtgAmber.opacity(0.25)
                                    : Color.mtgSurfaceElevated,
                                in: Capsule()
                            )
                            .foregroundStyle(.mtgText)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color.mtgSurface)
    }
}

// MARK: - Recommendation row

struct EdhrecCardRow: View {
    let recommendation: EdhrecCardRecommendation

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.mtgSurfaceElevated)
                .frame(width: 30, height: 42)
                .overlay(
                    Text(String(recommendation.name.prefix(1)))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.mtgTextSecondary)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(recommendation.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.mtgText)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(recommendation.category)
                        .font(.caption2)
                        .foregroundStyle(.mtgTextSecondary)
                    Text("\(recommendation.numDecks.thousandsFormatted) mazos")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.mtgTextSecondary)
                }
                HStack(spacing: 6) {
                    ProgressView(value: min(recommendation.inclusionPct, 100), total: 100)
                        .frame(width: 70)
                        .tint(.mtgAmber)
                    Text(recommendation.inclusionPct.percentFormatted())
                        .font(.caption2)
                        .foregroundStyle(.mtgTextSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if recommendation.isInDeck {
                    Text("EN MAZO")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.mtgAmber)
                } else if recommendation.isInCollection {
                    Label("\(recommendation.collectionQuantity)", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.mtgGreen)
                } else {
                    Text("Falta")
                        .font(.caption2)
                        .foregroundStyle(Color.mtgRed)
                }
            }
        }
        .padding(10)
        .background(Color.mtgSurface, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    EdhrecRecommendationsSheet(commanderName: "Chulane, Teller of Tales", deckCards: [])
        .environment(AppStore.demo)
        .preferredColorScheme(.dark)
}