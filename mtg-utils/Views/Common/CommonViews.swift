import SwiftUI

struct CardEditionEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let cardName: String
    let onSave: (String?) async -> Void

    @State private var setCode: String

    init(cardName: String, setCode: String?, onSave: @escaping (String?) async -> Void) {
        self.cardName = cardName
        self.onSave = onSave
        _setCode = State(initialValue: setCode ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Carta") {
                    Text(cardName)
                }
                Section("Edición") {
                    TextField("Código de edición, p. ej. MH3", text: $setCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Editar edición")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let normalized = setCode.trimmingCharacters(in: .whitespacesAndNewlines)
                        Task {
                            await onSave(normalized.isEmpty ? nil : normalized)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

struct CardQuantityEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let cardName: String
    let onSave: (Int) async -> Void

    @State private var quantity: Int

    init(cardName: String, quantity: Int, onSave: @escaping (Int) async -> Void) {
        self.cardName = cardName
        self.onSave = onSave
        _quantity = State(initialValue: max(quantity, 1))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Carta") {
                    Text(cardName)
                }
                Section("Cantidad") {
                    Stepper(value: $quantity, in: 1...999) {
                        Text("\(quantity) \(quantity == 1 ? "carta" : "cartas")")
                    }
                }
            }
            .navigationTitle("Editar cantidad")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task {
                            await onSave(quantity)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

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

/// A single mana pip rendered as an authentic MTG mana circle with iconic vector symbols
/// (water droplet for blue, tree for green, skull for black, sun for white, flame for red, diamond for colorless).
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
        let clean = symbol.uppercased()
        content(for: clean)
            .frame(width: diameter, height: diameter)
            .background(circleBackground(for: clean))
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 1))
            .accessibilityLabel(manaAccessibilityLabel(clean))
    }

    @ViewBuilder
    private func content(for sym: String) -> some View {
        let iconSize = diameter * 0.58
        switch sym {
        case "U":
            Image(systemName: "drop.fill")
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(.white)
        case "G":
            Image(systemName: "tree.fill")
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(.white)
        case "B":
            Text("☠")
                .font(.system(size: diameter * 0.72, weight: .bold))
                .foregroundStyle(.white)
        case "W":
            Image(systemName: "sun.max.fill")
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(Color(red: 0.28, green: 0.24, blue: 0.16))
        case "R":
            Image(systemName: "flame.fill")
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(.white)
        case "C":
            Image(systemName: "diamond.fill")
                .font(.system(size: iconSize * 0.9, weight: .bold))
                .foregroundStyle(Color(red: 0.22, green: 0.24, blue: 0.26))
        case "S":
            Image(systemName: "snowflake")
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(Color(red: 0.15, green: 0.35, blue: 0.55))
        case "E":
            Image(systemName: "bolt.fill")
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(Color(red: 0.95, green: 0.85, blue: 0.20))
        case "T":
            Image(systemName: "arrow.clockwise")
                .font(.system(size: iconSize * 0.85, weight: .bold))
                .foregroundStyle(Color(red: 0.20, green: 0.20, blue: 0.22))
        default:
            if sym.contains("/") {
                let parts = sym.split(separator: "/").map(String.init)
                HStack(spacing: 0.5) {
                    ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                        miniGlyph(part, size: iconSize * 0.65)
                    }
                }
            } else {
                Text(manaPillGlyph(sym))
                    .font(.system(size: diameter * 0.58, weight: .heavy, design: .rounded))
                    .foregroundStyle(circleForeground(sym))
            }
        }
    }

    @ViewBuilder
    private func miniGlyph(_ part: String, size: CGFloat) -> some View {
        switch part {
        case "U":
            Image(systemName: "drop.fill").font(.system(size: size, weight: .bold)).foregroundStyle(.white)
        case "G":
            Image(systemName: "tree.fill").font(.system(size: size, weight: .bold)).foregroundStyle(.white)
        case "B":
            Text("☠").font(.system(size: size, weight: .bold)).foregroundStyle(.white)
        case "W":
            Image(systemName: "sun.max.fill").font(.system(size: size, weight: .bold)).foregroundStyle(Color(red: 0.28, green: 0.24, blue: 0.16))
        case "R":
            Image(systemName: "flame.fill").font(.system(size: size, weight: .bold)).foregroundStyle(.white)
        default:
            Text(part).font(.system(size: size, weight: .bold, design: .rounded)).foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private func circleBackground(for sym: String) -> some View {
        if sym.contains("/") {
            let parts = sym.split(separator: "/").map(String.init)
            let c1 = manaColor(parts.first ?? "")
            let c2 = manaColor(parts.last ?? "")
            LinearGradient(colors: [c1, c2], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            manaColor(sym)
        }
    }

    private func manaColor(_ sym: String) -> Color {
        switch sym {
        case "W": return Color(red: 0.96, green: 0.95, blue: 0.88)
        case "U": return Color(red: 0.08, green: 0.52, blue: 0.83)
        case "B": return Color(red: 0.16, green: 0.15, blue: 0.18)
        case "R": return Color(red: 0.88, green: 0.24, blue: 0.20)
        case "G": return Color(red: 0.10, green: 0.55, blue: 0.32)
        case "C": return Color(red: 0.72, green: 0.73, blue: 0.74)
        case "S": return Color(red: 0.75, green: 0.85, blue: 0.95)
        case "E": return Color(red: 0.25, green: 0.25, blue: 0.28)
        default:
            return Color(red: 0.74, green: 0.75, blue: 0.76)
        }
    }

    private func circleForeground(_ sym: String) -> Color {
        switch sym {
        case "W": return Color(red: 0.28, green: 0.24, blue: 0.16)
        case "U", "R", "G", "B": return .white
        default: return Color(red: 0.18, green: 0.20, blue: 0.24)
        }
    }

    private func manaAccessibilityLabel(_ sym: String) -> String {
        switch sym {
        case "W": return "maná blanco"
        case "U": return "maná azul"
        case "B": return "maná negro"
        case "R": return "maná rojo"
        case "G": return "maná verde"
        case "C": return "maná incoloro"
        case "S": return "maná nevado"
        case "E": return "energía"
        case "T": return "girar"
        default:
            if sym.contains("/") { return "maná híbrido \(sym)" }
            return "maná \(sym)"
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible()), count: dynamicTypeSize.isAccessibilitySize ? 1 : 3)
    }

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
                        .font(.caption)
                        .foregroundStyle(.mtgTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .accessibilityElement(children: .combine)
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

// MARK: - Set Expansion Badge

struct SetExpansionBadge: View {
    let setCode: String?

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 8, weight: .bold))
            Text((setCode?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? setCode! : "MTG").uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2.5)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
        )
        .foregroundStyle(.mtgTextSecondary)
    }
}

// MARK: - Ownership Status Chip

struct OwnershipStatusChip: View {
    let text: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
                .font(.system(size: 8, weight: .bold))
            Text(text)
                .font(.system(size: 10, weight: .semibold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .foregroundStyle(tint)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(tint.opacity(0.25), lineWidth: 0.5))
    }
}

// MARK: - Sort & Group Options Sheet

struct SortAndGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isGrouped: Bool
    @Binding var sortField: SortField
    @Binding var sortDirection: SortDirection
    var filterMissingOnly: Binding<Bool>?

    init(
        isGrouped: Binding<Bool>,
        sortField: Binding<SortField>,
        sortDirection: Binding<SortDirection>,
        filterMissingOnly: Binding<Bool>? = nil
    ) {
        self._isGrouped = isGrouped
        self._sortField = sortField
        self._sortDirection = sortDirection
        self.filterMissingOnly = filterMissingOnly
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Agrupar por tipo", isOn: $isGrouped)
                } header: {
                    Text("Agrupación")
                } footer: {
                    Text("Agrupa las cartas en Planeswalkers, Criaturas, Instantáneos, Conjuros, Encantamientos, Artefactos, Batallas y Tierras.")
                        .font(.caption2)
                }

                Section("Criterio de ordenación") {
                    Picker("Ordenar por", selection: $sortField) {
                        ForEach(SortField.allCases) { field in
                            Text(field.displayName).tag(field)
                        }
                    }

                    Picker("Dirección", selection: $sortDirection) {
                        ForEach(SortDirection.allCases) { dir in
                            Text(dir.displayName).tag(dir)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if let filterMissingOnly {
                    Section("Filtros") {
                        Toggle("Solo cartas faltantes", isOn: filterMissingOnly)
                    }
                }
            }
            .navigationTitle("Organizar cartas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
