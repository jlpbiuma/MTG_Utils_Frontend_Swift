import SwiftUI

// MARK: - Mana cost pills

/// Renders an MTG mana-cost string like `{2}{U}{U}` as a row of colored circles.
struct ManaCostView: View {
    let cost: String?
    let font: UIFont.TextStyle

    init(cost: String?, font: UIFont.TextStyle = .caption1) {
        self.cost = cost
        self.font = font
    }

    private var symbols: [String] { parseManaCostSymbols(cost) }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                ManaPill(symbol: symbol, style: .small)
            }
        }
    }
}

/// A single mana pip rendered as a circle with a 1-letter glyph.
struct ManaPill: View {
    enum Style {
        case small
        case regular
    }

    let symbol: String
    let style: Style

    private var diameter: CGFloat {
        switch style {
        case .small: return 18
        case .regular: return 26
        }
    }

    var body: some View {
        let color = manaTint(symbol)
        Text(manaPillGlyph(symbol))
            .font(.system(size: diameter * 0.62, weight: .bold, design: .rounded))
            .foregroundStyle(circleForeground(symbol))
            .frame(width: diameter, height: diameter)
            .background(
                Circle()
                    .fill(color)
                    .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 1))
            )
            .accessibilityLabel("maná \(symbol)")
    }

    private func manaTint(_ symbol: String) -> Color {
        let base = symbol.uppercased().split(separator: "/").first.map(String.init) ?? ""
        switch base {
        case "W": return Color(red: 0.96, green: 0.96, blue: 0.91)
        case "U": return Color(red: 0.19, green: 0.55, blue: 0.85)
        case "B": return Color(red: 0.40, green: 0.42, blue: 0.47)
        case "R": return Color(red: 0.91, green: 0.30, blue: 0.27)
        case "G": return Color(red: 0.24, green: 0.72, blue: 0.39)
        default:
            if let _ = Int(base) { return Color(red: 0.76, green: 0.78, blue: 0.80) }
            return Color(red: 0.76, green: 0.78, blue: 0.80)
        }
    }

    private func circleForeground(_ symbol: String) -> Color {
        switch symbol.uppercased() {
        case "W": return Color(red: 0.25, green: 0.22, blue: 0.16)
        case "U", "R", "G", "B": return .white
        default: return Color(red: 0.18, green: 0.20, blue: 0.24)
        }
    }
}

// MARK: - Completion progress bar

struct CompletionBar: View {
    var progress: Double
    var showsLabel = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(LinearGradient(
                            colors: [.mtgAmberDeep, .mtgAmber],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: max(geo.size.width * CGFloat(progress / 100), 4))
                }
            }
            .frame(height: 8)

            if showsLabel {
                Text(progress.percentFormatted())
                    .font(.caption)
                    .foregroundStyle(.mtgTextSecondary)
            }
        }
    }
}

// MARK: - Section list header

struct SectionHeaderRow<T>: View {
    let section: GroupedCardSection<T>

    var body: some View {
        HStack {
            Text(section.label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.mtgText)
            Spacer()
            if section.totalCards > 0 {
                Text("\(section.uniqueCards) · \(section.ownedCards)/\(section.totalCards)")
                    .font(.caption)
                    .foregroundStyle(.mtgTextSecondary)
                CompletionBar(progress: section.completionPercentage)
                    .frame(width: 56)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Empty states

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(.mtgAmber)
            }
        }
    }
}

// MARK: - KPI card row

struct KPIStat: Identifiable {
    let id: String
    let label: String
    let value: String
    let systemImage: String
    let tint: Color
}

struct KPIStripView: View {
    let stats: [KPIStat]

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(stats) { stat in
                VStack(spacing: 2) {
                    Image(systemName: stat.systemImage)
                        .foregroundStyle(stat.tint)
                    Text(stat.value)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.mtgText)
                    Text(stat.label)
                        .font(.caption2)
                        .foregroundStyle(.mtgTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.mtgSurface, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - Sorting controls

struct CardSortingBar: View {
    @Binding var field: SortField
    @Binding var direction: SortDirection

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(SortField.allCases) { candidate in
                    Button {
                        field = candidate
                    } label: {
                        if candidate == field {
                            Label(candidate.displayName, systemImage: "checkmark")
                        } else {
                            Text(candidate.displayName)
                        }
                    }
                }
            } label: {
                Label(field.displayName, systemImage: "arrow.up.arrow.down")
                    .font(.subheadline)
            }

            Menu {
                ForEach(SortDirection.allCases) { candidate in
                    Button {
                        direction = candidate
                    } label: {
                        if candidate == direction {
                            Label(candidate.displayName, systemImage: "checkmark")
                        } else {
                            Text(candidate.displayName)
                        }
                    }
                }
            } label: {
                Image(systemName: direction == .ascending ? "chevron.up" : "chevron.down")
                    .font(.subheadline)
            }
            Spacer()
        }
    }
}