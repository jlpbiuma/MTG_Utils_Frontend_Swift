import SwiftUI

// MARK: - Card detail sheet

/// Full card information shown as a sheet when a deck card row is selected.
/// Loads Spanish-localized details from the backend (`/api/scryfall/card`) and
/// falls back to the already-loaded row data when the backend is unreachable.
struct CardDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let card: DeckCardWithOwnership
    /// Price for one copy, supplied by the collection/deck price summary.
    var unitPrice: Double = 0
    var currencySymbol = "€"
    var provider: PriceProvider = .cardmarket
    let client: BackendClient?

    @State private var details: SpanishCardDetails?
    @State private var isLoadingDetails = true

    var body: some View {
        NavigationStack {
            Group {
                if let details {
                    detailContent(details)
                } else if isLoadingDetails {
                    ProgressView("Cargando ficha de la carta…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    fallbackContent
                }
            }
            .navigationTitle(details?.displayName ?? card.cardName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .tint(.mtgAmber)
        .task { await loadDetails() }
    }

    @MainActor
    private func loadDetails() async {
        isLoadingDetails = true
        defer { isLoadingDetails = false }
        guard !card.cardScryfallId.hasPrefix("pending:") else { return }
        details = try? await client?.cardDetails(id: card.cardScryfallId)
        if details == nil, let client {
            details = try? await client.cardDetails(name: card.cardName)
        }
    }

    // MARK: Full detail (backend)

    @MainActor
    private func detailContent(_ details: SpanishCardDetails) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                artworkSection(imageUri: details.largeImageUri, hasSpanishPrint: details.hasSpanishPrint)

                VStack(alignment: .leading, spacing: 5) {
                    if details.nameEs != details.name, !details.nameEs.isEmpty {
                        Text(details.nameEs)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.mtgText)
                        Text(details.name)
                            .font(.subheadline)
                            .foregroundStyle(.mtgTextSecondary)
                    } else {
                        Text(details.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.mtgText)
                    }

                    HStack(spacing: 6) {
                        ManaCostView(cost: details.manaCost, font: .subheadline)
                        if let cmc = details.cmc {
                            Text("· CMC \(cmc.cleanNumber())")
                                .font(.caption)
                                .foregroundStyle(.mtgTextSecondary)
                        }
                    }

                    if !details.displayTypeLine.isEmpty {
                        Text(details.displayTypeLine)
                            .font(.subheadline)
                            .foregroundStyle(.mtgAmber)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                statsSection(details)
                ownershipSection
                providerPricesSection(details)

                if !details.displayOracleText.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Texto de la carta")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.mtgTextSecondary)
                        OracleTextView(text: details.displayOracleText)
                            .font(.subheadline)
                            .foregroundStyle(.mtgText)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.mtgSurface, in: RoundedRectangle(cornerRadius: 12))
                }

                if !details.displayFlavorText.isEmpty {
                    SectionCard(title: "Texto de ambientación") {
                        Text(details.displayFlavorText)
                            .font(.subheadline.italic())
                            .foregroundStyle(.mtgTextSecondary)
                    }
                }

                if let printings = details.printings, !printings.isEmpty { printingsSection(printings) }
                if let rulings = details.rulings, !rulings.isEmpty { rulingsSection(rulings) }
                if let legalities = details.legalities, !legalities.isEmpty { legalitiesSection(legalities) }
            }
            .padding()
        }
    }

    @MainActor private func rulingsSection(_ rulings: [CardRulingDetail]) -> some View {
        SectionCard(title: "Rulings") { ForEach(rulings) { ruling in VStack(alignment: .leading, spacing: 3) { Text(ruling.date.prefix(10)).font(.caption).foregroundStyle(.mtgTextSecondary); Text(ruling.text).font(.subheadline) } } }
    }

    @MainActor private func printingsSection(_ printings: [CardPrintingDetail]) -> some View {
        SectionCard(title: "Todos los artes y ediciones") {
            ForEach(printings) { printing in
                HStack(alignment: .top, spacing: 12) {
                    CardImageView(
                        url: AppConfiguration.imageURL(from: printing.imageUriSmall ?? printing.imageUri),
                        placeholderText: nil,
                        targetSize: 180
                    )
                    .frame(width: 72, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(printing.setName ?? printing.setCode.uppercased())
                            .font(.subheadline.weight(.semibold))
                        Text("\(printing.setCode.uppercased()) · #\(printing.collectorNumber)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.mtgTextSecondary)
                        if let rarity = printing.rarity, !rarity.isEmpty {
                            Text(rarity.capitalized)
                                .font(.caption2)
                                .foregroundStyle(.mtgAmber)
                        }
                        let quote = providerQuote(for: printing)
                        Text(provider.displayName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.mtgTextSecondary)
                        Text("T \(price(quote.trend)) · Min \(price(quote.min)) · Max \(price(quote.max))")
                            .font(.caption.monospacedDigit())
                        if let releasedAt = printing.releasedAt {
                            Text("Publicado: \(releasedAt.prefix(10))")
                                .font(.caption2)
                                .foregroundStyle(.mtgTextSecondary)
                        }
                    }
                }
                .padding(.vertical, 5)
                Divider().opacity(0.25)
            }
        }
    }

    @MainActor
    private func statsSection(_ details: SpanishCardDetails) -> some View {
        SectionCard(title: "Datos de la carta") {
            LabeledContent("Edición", value: "\(details.set)\(details.setName.map { " · \($0)" } ?? "")")
            if let collectorNumber = details.collectorNumber, !collectorNumber.isEmpty {
                LabeledContent("Nº de colección", value: collectorNumber)
            }
            LabeledContent("Rareza", value: details.rarityEs)
            if let power = details.power, let toughness = details.toughness {
                LabeledContent("Fuerza/Resistencia", value: "\(power)/\(toughness)")
            }
            if let loyalty = details.loyalty, !loyalty.isEmpty {
                LabeledContent("Lealtad", value: loyalty)
            }
            if let defense = details.defense, !defense.isEmpty {
                LabeledContent("Defensa", value: defense)
            }
            if let artist = details.artist, !artist.isEmpty {
                LabeledContent("Artista", value: artist)
            }
        }
    }

    @MainActor
    private func legalitiesSection(_ legalities: [SpanishCardLegality]) -> some View {
        SectionCard(title: "Legalidad de formatos") {
            FlowLayout(spacing: 6) {
                ForEach(legalities) { legality in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(legality.isLegal ? Color.mtgGreen : Color.mtgRed)
                            .frame(width: 6, height: 6)
                        Text(legality.formatName)
                            .font(.caption.weight(.medium))
                        Text("· \(legality.statusEs)")
                            .font(.caption)
                            .foregroundStyle(.mtgTextSecondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Color.white.opacity(0.06),
                        in: Capsule()
                    )
                }
            }
        }
    }

    @MainActor
    private func providerPricesSection(_ details: SpanishCardDetails) -> some View {
        let currentPrinting = details.printings?.first(where: { $0.id == card.cardScryfallId })
            ?? details.printings?.first
        let quote = currentPrinting.map(providerQuote)
        return SectionCard(title: "Precios · \(provider.displayName)") {
            if let quote {
                LabeledContent("Tendencia", value: price(quote.trend))
                LabeledContent("Mínimo", value: price(quote.min))
                LabeledContent("Máximo", value: price(quote.max))
            } else if unitPrice > 0 {
                LabeledContent("Tendencia", value: unitPrice.formattedPrice(symbol: currencySymbol))
                LabeledContent("Mínimo", value: "—")
                LabeledContent("Máximo", value: "—")
            } else {
                Text("Sin cotización disponible para esta edición.")
                    .font(.caption)
                    .foregroundStyle(.mtgTextSecondary)
            }
        }
    }

    private func providerQuote(for printing: CardPrintingDetail) -> (trend: Double?, min: Double?, max: Double?) {
        switch provider {
        case .cardmarket:
            return (printing.trend, printing.min, printing.max)
        case .cardtrader:
            return (printing.cardtraderTrend, printing.cardtraderMin, printing.cardtraderMax)
        case .mtggoldfish:
            return (printing.priceUsd, printing.priceUsd, printing.priceUsd)
        }
    }

    private func price(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formattedPrice(symbol: provider.currencySymbol)
    }

    @MainActor
    private var ownershipSection: some View {
        SectionCard(title: "En tu colección") {
            LabeledContent("En colección", value: "\(card.ownedInCollection)")
                .foregroundStyle(Color.mtgGreen)
            if card.missingCount > 0 {
                LabeledContent("Faltan en este mazo", value: "\(card.missingCount)")
                    .foregroundStyle(Color.mtgRed)
            }
            let otherCount = card.assignedInOtherDecks.reduce(0) { $0 + $1.quantity }
            if otherCount > 0 {
                LabeledContent("En otros mazos", value: "\(otherCount)")
                    .foregroundStyle(Color.mtgAmber)
            }
            LabeledContent("Cantidad en mazo", value: "×\(card.quantity)")
        }
    }

    // MARK: Fallback (local row data)

    @MainActor
    private var fallbackContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                artworkSection(imageUri: card.imageUri, hasSpanishPrint: false)

                VStack(alignment: .leading, spacing: 5) {
                    Text(card.cardName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.mtgText)
                    HStack(spacing: 6) {
                        ManaCostView(cost: card.manaCost)
                        if let typeLine = card.typeLine, !typeLine.isEmpty {
                            Text(typeLine)
                                .font(.subheadline)
                                .foregroundStyle(.mtgTextSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                SectionCard(title: "Datos de la carta") {
                    LabeledContent("Edición", value: (card.setCode?.isEmpty == false ? card.setCode! : "MTG").uppercased())
                    if card.missingCount > 0 {
                        LabeledContent("Faltan en este mazo", value: "\(card.missingCount)")
                            .foregroundStyle(Color.mtgRed)
                    }
                    LabeledContent("En colección", value: "\(card.ownedInCollection)")
                        .foregroundStyle(Color.mtgGreen)
                    LabeledContent("Cantidad en mazo", value: "×\(card.quantity)")
                    if unitPrice > 0 {
                        LabeledContent("Precio unitario", value: unitPrice.formattedPrice(symbol: currencySymbol))
                    }
                }

                Text("No se pudieron cargar los datos completos. Comprueba que el backend está activo.")
                    .font(.caption)
                    .foregroundStyle(.mtgTextSecondary)
            }
            .padding()
        }
    }

    @MainActor
    private func artworkSection(imageUri: String?, hasSpanishPrint: Bool) -> some View {
        VStack(spacing: 8) {
            ZStack {
                if let url = AppConfiguration.imageURL(from: imageUri) {
                    CardImageView(url: url, placeholderText: nil, targetSize: 600)
                } else {
                    CardBackPlaceholder.view
                }
            }
            .frame(width: 210, height: 292)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.14), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.45), radius: 14, x: 0, y: 8)

            if hasSpanishPrint {
                Text("Impresión oficial en español")
                    .font(.caption2)
                    .foregroundStyle(.mtgTextSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Section container

private struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.mtgTextSecondary)
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.mtgSurface, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Flowing oracle text with inline mana symbols

/// A word flow layout that wraps within the proposed width and justifies every
/// completed line. The final line remains leading-aligned, as in normal text.
struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    var justifyLines = false

    private struct RowItem {
        let index: Int
        let size: CGSize
    }

    private func rowHeight(_ row: [RowItem]) -> CGFloat {
        var height: CGFloat = 0
        for item in row {
            height = max(height, item.size.height)
        }
        return height
    }

    private func rowWidth(_ row: [RowItem]) -> CGFloat {
        guard !row.isEmpty else { return 0 }
        var width: CGFloat = 0
        for item in row {
            width += item.size.width
        }
        return width + CGFloat(row.count - 1) * spacing
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [[RowItem]] {
        var rows: [[RowItem]] = []
        var currentRow: [RowItem] = []
        var currentWidth: CGFloat = 0

        for index in subviews.indices {
            let intrinsic = subviews[index].sizeThatFits(.unspecified)
            let constrainedSize = intrinsic.width > maxWidth
                ? subviews[index].sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
                : intrinsic
            let nextWidth = currentWidth + (currentRow.isEmpty ? 0 : spacing) + constrainedSize.width

            if !currentRow.isEmpty, nextWidth > maxWidth {
                rows.append(currentRow)
                currentRow = []
                currentWidth = 0
            }

            currentRow.append(RowItem(index: index, size: constrainedSize))
            currentWidth += (currentRow.count == 1 ? 0 : spacing) + constrainedSize.width
        }

        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 10_000
        let rows = rows(for: subviews, maxWidth: maxWidth)
        var height: CGFloat = 0
        var contentWidth: CGFloat = 0
        for row in rows {
            height += rowHeight(row)
            contentWidth = max(contentWidth, rowWidth(row))
        }
        if rows.count > 1 {
            height += CGFloat(rows.count - 1) * spacing
        }
        return CGSize(width: proposal.width ?? contentWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(for: subviews, maxWidth: bounds.width)
        var y = bounds.minY

        for (rowIndex, row) in rows.enumerated() {
            let height = rowHeight(row)
            let contentWidth = rowWidth(row) - CGFloat(max(row.count - 1, 0)) * spacing
            let shouldJustify = justifyLines && rowIndex < rows.count - 1 && row.count > 1
            let gap = shouldJustify
                ? max(spacing, (bounds.width - contentWidth) / CGFloat(row.count - 1))
                : spacing
            var x = bounds.minX

            for item in row {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(width: min(item.size.width, bounds.width), height: item.size.height)
                )
                x += item.size.width + gap
            }
            y += height + spacing
        }
    }
}

/// Renders MTG oracle text, turning `{S}` cost tokens into inline mana pills.
struct OracleTextView: View {
    let text: String

    private struct Token: Identifiable {
        let id = UUID()
        let value: String
        let isMana: Bool
    }

    private func tokens(for paragraph: String) -> [Token] {
        let pattern = #"(\{[^}]*\})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return paragraph.split(whereSeparator: \.isWhitespace).map { Token(value: String($0), isMana: false) }
        }
        let ns = paragraph as NSString
        let range = NSRange(location: 0, length: ns.length)
        let matches = regex.matches(in: paragraph, range: range)

        var result: [Token] = []
        var last = 0
        for match in matches {
            let segmentRange = NSRange(location: last, length: match.range.location - last)
            if segmentRange.length > 0 {
                result += ns.substring(with: segmentRange)
                    .split(whereSeparator: \.isWhitespace)
                    .map { Token(value: String($0), isMana: false) }
            }
            let symbol = ns.substring(with: match.range)
            let inner = symbol.trimmingCharacters(in: CharacterSet(charactersIn: "{}"))
            result.append(Token(value: inner, isMana: true))
            last = match.range.location + match.range.length
        }
        if last < ns.length {
            result += ns.substring(from: last)
                .split(whereSeparator: \.isWhitespace)
                .map { Token(value: String($0), isMana: false) }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(text.split(separator: "\n", omittingEmptySubsequences: false).enumerated()), id: \.offset) { _, paragraph in
                let tokens = tokens(for: String(paragraph))
                if tokens.isEmpty {
                    Spacer().frame(height: 4)
                } else {
                    FlowLayout(spacing: 5, justifyLines: false) {
                        ForEach(tokens) { token in
                            if token.isMana {
                                ManaPill(symbol: token.value, style: .small)
                                    .frame(height: 18)
                            } else {
                                Text(token.value)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.65)
                                    .allowsTightening(true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }
}

// MARK: - Helpers

private extension Double {
    func cleanNumber() -> String {
        self == self.rounded() ? String(format: "%.0f", self) : String(self)
    }
}

#Preview {
    CardDetailView(
        card: DeckCardWithOwnership(
            id: "1",
            deckId: "d",
            cardScryfallId: "0000",
            cardName: "Snapcaster Mage",
            quantity: 2,
            assignedQuantity: 1,
            isSideboard: false,
            isCommander: false,
            manaCost: "{1}{U}",
            typeLine: "Creature — Human Wizard",
            imageUri: nil,
            ownedInCollection: 2,
            availableToAssign: 1,
            assignedInOtherDecks: [],
            missingCount: 0
        ),
        unitPrice: 29.99,
        client: nil
    )
    .preferredColorScheme(.dark)
}
