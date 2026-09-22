import SwiftUI

// MARK: - Mulligan Simulator View

struct DeckMulliganSimulatorView: View {
    let cards: [DeckCardWithOwnership]
    let commanderName: String?

    private struct SimCard: Identifiable, Hashable {
        let uid: String
        let cardName: String
        let cardScryfallId: String
        let imageUri: String?
        let manaCost: String?
        let typeLine: String?
        let isLand: Bool

        var id: String { uid }
    }

    @State private var library: [SimCard] = []
    @State private var hand: [SimCard] = []
    @State private var mulliganCount = 0
    @State private var cardsToBottom: Set<String> = []
    @State private var currentTurn = 1

    private var pool: [SimCard] {
        var list: [SimCard] = []
        var counter = 0
        for card in cards {
            if card.isSideboard || card.isCommander { continue }
            let isLand = card.typeLine?.localizedCaseInsensitiveContains("Land") == true
            for _ in 0..<card.quantity {
                counter += 1
                list.append(
                    SimCard(
                        uid: "\(card.id)_\(counter)",
                        cardName: card.cardName,
                        cardScryfallId: card.cardScryfallId,
                        imageUri: card.imageUri,
                        manaCost: card.manaCost,
                        typeLine: card.typeLine,
                        isLand: isLand
                    )
                )
            }
        }
        return list
    }

    private var landsInHand: Int {
        hand.filter { $0.isLand }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Control Bar
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Simulador de Mulligan")
                                .font(.headline)
                                .foregroundStyle(Color.mtgText)
                            Text("London Mulligan · Turno \(currentTurn) · \(hand.count) cartas en mano")
                                .font(.caption2)
                                .foregroundStyle(Color.mtgTextSecondary)
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            Text("\(landsInHand) Tierras")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(landsInHand == 2 || landsInHand == 3 ? Color.mtgGreen.opacity(0.2) : Color.mtgAmber.opacity(0.2))
                                .foregroundStyle(landsInHand == 2 || landsInHand == 3 ? Color.mtgGreen : Color.mtgAmber)
                                .clipShape(Capsule())
                        }
                    }

                    // Action buttons
                    HStack(spacing: 8) {
                        Button {
                            startNewHand()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Nueva Mano")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.mtgAmber)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)

                        Button {
                            handleLondonMulligan()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "shuffle")
                                Text("Mulligan (\(mulliganCount + 1))")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.mtgText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.mtgSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)

                        Button {
                            drawCard()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.rectangle.on.rectangle")
                                Text("Robar")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.mtgText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.mtgSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .disabled(library.isEmpty)
                    }

                    // Mulligan bottoming guidance if needed
                    if mulliganCount > 0 && cardsToBottom.count < mulliganCount {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(Color.mtgAmber)
                            Text("Selecciona \(mulliganCount - cardsToBottom.count) \(mulliganCount - cardsToBottom.count == 1 ? "carta" : "cartas") para enviar al fondo de la biblioteca.")
                                .font(.caption2)
                                .foregroundStyle(Color.mtgText)
                            Spacer()
                        }
                        .padding(8)
                        .background(Color.mtgAmber.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding()
                .background(Color.mtgSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Hand Cards Grid
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90, maximum: 120), spacing: 10)], spacing: 12) {
                    ForEach(hand) { card in
                        Button {
                            toggleCardToBottom(card.uid)
                        } label: {
                            VStack(spacing: 4) {
                                ZStack(alignment: .topTrailing) {
                                    if let uri = card.imageUri, let url = URL(string: uri) {
                                        CardImageView(url: url, placeholderText: nil, targetSize: 240)
                                            .frame(height: 140)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    } else {
                                        CardBackPlaceholder.view
                                            .frame(height: 140)
                                    }

                                    if cardsToBottom.contains(card.uid) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.mtgRed)
                                                .frame(width: 22, height: 22)
                                            Image(systemName: "arrow.down")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(Color.white)
                                        }
                                        .padding(4)
                                    }
                                }

                                Text(card.cardName)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(Color.mtgText)
                                    .lineLimit(1)

                                ManaCostView(cost: card.manaCost)
                            }
                            .padding(4)
                            .background(cardsToBottom.contains(card.uid) ? Color.mtgRed.opacity(0.15) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .task {
            startNewHand()
        }
    }

    // MARK: - Game State Actions

    private func startNewHand() {
        var shuffled = pool.shuffled()
        hand = Array(shuffled.prefix(7))
        library = Array(shuffled.dropFirst(7))
        mulliganCount = 0
        cardsToBottom.removeAll()
        currentTurn = 1
    }

    private func handleLondonMulligan() {
        mulliganCount += 1
        var shuffled = pool.shuffled()
        hand = Array(shuffled.prefix(7))
        library = Array(shuffled.dropFirst(7))
        cardsToBottom.removeAll()
        currentTurn = 1
    }

    private func drawCard() {
        guard !library.isEmpty else { return }
        let drawn = library.removeFirst()
        hand.append(drawn)
        currentTurn += 1
    }

    private func toggleCardToBottom(_ uid: String) {
        guard mulliganCount > 0 else { return }
        if cardsToBottom.contains(uid) {
            cardsToBottom.remove(uid)
        } else if cardsToBottom.count < mulliganCount {
            cardsToBottom.insert(uid)
            if cardsToBottom.count == mulliganCount {
                // Remove bottomed cards from hand and put at bottom of library
                let bottomedCards = hand.filter { cardsToBottom.contains($0.uid) }
                hand.removeAll { cardsToBottom.contains($0.uid) }
                library.append(contentsOf: bottomedCards)
            }
        }
    }
}
