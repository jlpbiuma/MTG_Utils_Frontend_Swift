import SwiftUI
import Charts

// MARK: - Deck Analytics View (SwiftUI Charts)

struct DeckAnalyticsView: View {
    let cards: [DeckCardWithOwnership]
    let colors: [String]

    @State private var excludeLands = true
    @State private var excludeCommander = true
    @State private var simulatedLands: Double = 36

    private var nonSideboardCards: [DeckCardWithOwnership] {
        cards.filter { !$0.isSideboard }
    }

    // MARK: - Mana Curve Calculation

    private struct CmcBucket: Identifiable {
        let cmc: String
        let count: Int
        var id: String { cmc }
    }

    private var manaCurveData: [CmcBucket] {
        var buckets: [Int: Int] = [:]
        for i in 0...7 { buckets[i] = 0 }

        for card in nonSideboardCards {
            if excludeLands && (card.typeLine?.localizedCaseInsensitiveContains("Land") == true) {
                continue
            }
            if excludeCommander && card.isCommander {
                continue
            }
            let cmc = parseCmc(from: card.manaCost)
            let clampedCmc = min(cmc, 7)
            buckets[clampedCmc, default: 0] += card.quantity
        }

        return (0...7).map { i in
            CmcBucket(cmc: i >= 7 ? "7+" : "\(i)", count: buckets[i] ?? 0)
        }
    }

    private var avgCmcWithoutLands: Double {
        let nonLands = nonSideboardCards.filter { !($0.typeLine?.localizedCaseInsensitiveContains("Land") == true) }
        let totalCount = nonLands.reduce(0) { $0 + $1.quantity }
        guard totalCount > 0 else { return 0 }
        let totalCmc = nonLands.reduce(0) { $0 + (parseCmc(from: $1.manaCost) * $1.quantity) }
        return Double(totalCmc) / Double(totalCount)
    }

    // MARK: - Type Distribution

    private struct TypeBucket: Identifiable {
        let typeName: String
        let count: Int
        var id: String { typeName }
    }

    private var typeDistribution: [TypeBucket] {
        var counts: [String: Int] = [
            "Criaturas": 0,
            "Tierras": 0,
            "Instantáneos": 0,
            "Conjuros": 0,
            "Artefactos": 0,
            "Encantamientos": 0,
            "Planeswalkers": 0,
            "Otros": 0
        ]

        for card in nonSideboardCards {
            let t = card.typeLine ?? ""
            let qty = card.quantity
            if t.localizedCaseInsensitiveContains("Creature") { counts["Criaturas", default: 0] += qty }
            else if t.localizedCaseInsensitiveContains("Land") { counts["Tierras", default: 0] += qty }
            else if t.localizedCaseInsensitiveContains("Instant") { counts["Instantáneos", default: 0] += qty }
            else if t.localizedCaseInsensitiveContains("Sorcery") { counts["Conjuros", default: 0] += qty }
            else if t.localizedCaseInsensitiveContains("Artifact") { counts["Artefactos", default: 0] += qty }
            else if t.localizedCaseInsensitiveContains("Enchantment") { counts["Encantamientos", default: 0] += qty }
            else if t.localizedCaseInsensitiveContains("Planeswalker") { counts["Planeswalkers", default: 0] += qty }
            else { counts["Otros", default: 0] += qty }
        }

        return counts.filter { $0.value > 0 }.map { TypeBucket(typeName: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    // MARK: - Color Mana Pips

    private struct PipBucket: Identifiable {
        let color: String
        let symbol: String
        let count: Int
        var id: String { color }
    }

    private var colorPips: [PipBucket] {
        var pips: [String: Int] = ["W": 0, "U": 0, "B": 0, "R": 0, "G": 0]
        for card in nonSideboardCards {
            guard let cost = card.manaCost else { continue }
            for char in cost {
                let s = String(char)
                if pips.keys.contains(s) {
                    pips[s, default: 0] += card.quantity
                }
            }
        }
        let names = ["W": "Blanco", "U": "Azul", "B": "Negro", "R": "Rojo", "G": "Verde"]
        return ["W", "U", "B", "R", "G"].compactMap { sym in
            let count = pips[sym] ?? 0
            return count > 0 ? PipBucket(color: names[sym] ?? sym, symbol: sym, count: count) : nil
        }
    }

    // MARK: - Hypergeometric Opening Hand

    private var landCount: Int {
        nonSideboardCards.filter { $0.typeLine?.localizedCaseInsensitiveContains("Land") == true }.reduce(0) { $0 + $1.quantity }
    }

    private var totalDeckCount: Int {
        max(1, nonSideboardCards.reduce(0) { $0 + $1.quantity })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header KPIs
                KPIStripView(stats: [
                    KPIStat(
                        id: "avgCmc",
                        label: "CMC Medio",
                        value: String(format: "%.2f", avgCmcWithoutLands),
                        systemImage: "gauge.with.dots.needle.50percent",
                        tint: .mtgAmber
                    ),
                    KPIStat(
                        id: "lands",
                        label: "Tierras",
                        value: "\(landCount)",
                        systemImage: "mountain.2.fill",
                        tint: .mtgGreen
                    ),
                    KPIStat(
                        id: "total",
                        label: "Cartas",
                        value: "\(totalDeckCount)",
                        systemImage: "rectangle.stack.fill",
                        tint: .mtgAmber
                    )
                ])

                // Mana Curve Chart
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Curva de Maná")
                                .font(.headline)
                                .foregroundStyle(Color.mtgText)
                            Text("Distribución de costes de cartas no tierra")
                                .font(.caption2)
                                .foregroundStyle(Color.mtgTextSecondary)
                        }
                        Spacer()
                    }

                    Chart(manaCurveData) { item in
                        BarMark(
                            x: .value("Coste", item.cmc),
                            y: .value("Cantidad", item.count)
                        )
                        .foregroundStyle(Color.mtgAmber)
                        .annotation(position: .top) {
                            if item.count > 0 {
                                Text("\(item.count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.mtgTextSecondary)
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(height: 160)
                }
                .padding()
                .background(Color.mtgSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Type Distribution
                VStack(alignment: .leading, spacing: 12) {
                    Text("Distribución por Tipos")
                        .font(.headline)
                        .foregroundStyle(Color.mtgText)

                    Chart(typeDistribution) { item in
                        BarMark(
                            x: .value("Cantidad", item.count),
                            y: .value("Tipo", item.typeName)
                        )
                        .foregroundStyle(Color.mtgGreen)
                        .annotation(position: .trailing) {
                            Text("\(item.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.mtgTextSecondary)
                        }
                    }
                    .frame(height: CGFloat(max(120, typeDistribution.count * 26)))
                }
                .padding()
                .background(Color.mtgSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Color Pips Requirements
                if !colorPips.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Símbolos de Maná Exigidos (Pips)")
                            .font(.headline)
                            .foregroundStyle(Color.mtgText)

                        HStack(spacing: 12) {
                            ForEach(colorPips) { pip in
                                VStack(spacing: 4) {
                                    ManaPill(symbol: pip.symbol, style: .regular)
                                    Text("\(pip.count)")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.mtgText)
                                    Text(pip.color)
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.mtgTextSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.mtgSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding()
                    .background(Color.mtgSurfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Probability of lands in opening hand
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Probabilidad en Mano Inicial (7 cartas)")
                            .font(.headline)
                            .foregroundStyle(Color.mtgText)
                        Text("Con \(landCount) tierras en \(totalDeckCount) cartas")
                            .font(.caption2)
                            .foregroundStyle(Color.mtgTextSecondary)
                    }

                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { landsInHand in
                            let prob = hypergeometric(k: landsInHand, N: totalDeckCount, K: landCount, n: 7)
                            VStack(spacing: 4) {
                                Text("\(landsInHand) Tierras")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.mtgTextSecondary)
                                Text("\(Int(prob * 100))%")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(landsInHand == 2 || landsInHand == 3 ? Color.mtgGreen : Color.mtgText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.mtgSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding()
                .background(Color.mtgSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
    }

    // MARK: - Helpers

    private func parseCmc(from manaCost: String?) -> Int {
        guard let manaCost else { return 0 }
        var total = 0
        let cleaned = manaCost.replacingOccurrences(of: "{", with: " ").replacingOccurrences(of: "}", with: " ")
        for token in cleaned.split(separator: " ") {
            if let num = Int(token) {
                total += num
            } else if ["W", "U", "B", "R", "G", "C"].contains(String(token)) {
                total += 1
            }
        }
        return total
    }

    private func hypergeometric(k: Int, N: Int, K: Int, n: Int) -> Double {
        func combinations(_ n: Int, _ k: Int) -> Double {
            guard k >= 0, k <= n else { return 0 }
            if k == 0 || k == n { return 1 }
            let kClamped = min(k, n - k)
            var result: Double = 1
            for i in 1...kClamped {
                result *= Double(n - (kClamped - i))
                result /= Double(i)
            }
            return result
        }

        let waysToPickLands = combinations(K, k)
        let waysToPickNonLands = combinations(N - K, n - k)
        let totalHands = combinations(N, n)

        guard totalHands > 0 else { return 0 }
        return (waysToPickLands * waysToPickNonLands) / totalHands
    }
}
