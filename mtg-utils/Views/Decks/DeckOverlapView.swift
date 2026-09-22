import SwiftUI

// MARK: - Deck Overlap View

struct DeckOverlapView: View {
    let cards: [DeckCardWithOwnership]
    let deckName: String

    private var overlappingCards: [DeckCardWithOwnership] {
        cards.filter { !$0.assignedInOtherDecks.isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header Banner
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "square.on.square.dashed")
                            .font(.title2)
                            .foregroundStyle(Color.mtgAmber)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Solapamiento de Cartas")
                                .font(.headline)
                                .foregroundStyle(Color.mtgText)

                            Text("\(overlappingCards.count) cartas de este mazo están compartidas o asignadas en otros mazos.")
                                .font(.caption)
                                .foregroundStyle(Color.mtgTextSecondary)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.mtgSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                if overlappingCards.isEmpty {
                    EmptyStateView(
                        title: "Sin solapamiento",
                        message: "Ninguna de las cartas de este mazo se comparte actualmente con otros mazos.",
                        systemImage: "checkmark.circle",
                        actionTitle: nil,
                        action: nil
                    )
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(overlappingCards) { card in
                            overlapCardRow(card: card)
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func overlapCardRow(card: DeckCardWithOwnership) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if let uri = card.imageUri, let url = URL(string: uri) {
                CardImageView(url: url, placeholderText: nil, targetSize: 120)
                    .frame(width: 40, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(card.cardName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.mtgText)
                    Spacer()
                    ManaCostView(cost: card.manaCost)
                }

                Text("Necesarias en este mazo: \(card.quantity) (Poseídas en colección: \(card.ownedInCollection))")
                    .font(.caption2)
                    .foregroundStyle(Color.mtgTextSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Asignadas en otros mazos:")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.mtgAmber)

                    ForEach(card.assignedInOtherDecks) { other in
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8))
                            Text("\(other.deckName):")
                                .font(.caption2.weight(.medium))
                            Text("\(other.quantity)x")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.mtgAmber)
                        }
                        .foregroundStyle(Color.mtgTextSecondary)
                    }
                }
                .padding(6)
                .background(Color.mtgSurface)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding()
        .background(Color.mtgSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
