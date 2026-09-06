import Foundation

// MARK: - Decklist / collection importer

enum ImportError: LocalizedError {
    case emptyInput
    case noCardsDetected

    var errorDescription: String? {
        switch self {
        case .emptyInput: return "El texto está vacío."
        case .noCardsDetected: return "No se detectaron cartas. Comprueba el formato."
        }
    }
}

struct ParsedDeckEntry: Identifiable, Hashable {
    var id: String { "\(lineNumber)-\(quantity)-\(name)" }
    var lineNumber: Int
    var quantity: Int
    var name: String
    var isSideboard: Bool
    var setCode: String?
    var collectorNumber: String?

    /// Scryfall search query for resolving this entry to a precise card.
    var scryfallQuery: String {
        var query = "!\"\(name)\""
        if let setCode { query += " set:\(setCode)" }
        return query
    }

    /// Multiverse ID (marketing-free, so we keep lookup name-based).
    var resolvedName: String { name }
}

struct ParsedDecklist: Hashable {
    var mainboard: [ParsedDeckEntry]
    var sideboard: [ParsedDeckEntry]
    var totalLines: Int

    var totalCards: Int {
        mainboard.reduce(0) { $0 + $1.quantity } + sideboard.reduce(0) { $0 + $1.quantity }
    }
}

/// Parses decklist text in several formats (faithful port of the web app's
/// `src/lib/parser.ts`):
/// - Moxfield/Archidekt: `1 Atraxa, Praetors' Voice (2XM) 198 *F*` (alphanumeric
///   collector numbers like `191p`, `360s`, `E02-3` are supported)
/// - Arena/export: `Deck` / `Sideboard` section headers
/// - Plain text: `4x Lightning Bolt`
/// - Optional `SB:` prefix marks sideboard entries when no section headers exist.
/// - Alt set tag: `[SET:123]`
func parseDecklistText(_ text: String) throws -> ParsedDecklist {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw ImportError.emptyInput }

    var mainboard: [ParsedDeckEntry] = []
    var sideboard: [ParsedDeckEntry] = []
    var totalLines = 0
    var inSideboard = false
    var sawCard = false

    let lines = text.components(separatedBy: .newlines)

    for (index, rawLine) in lines.enumerated() {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty else { continue }

        let lower = line.lowercased()

        // Sideboard section headers.
        if lower.hasPrefix("// sideboard")
            || lower.hasPrefix("sideboard")
            || lower.hasPrefix("//sideboard")
            || lower == "sideboard:" {
            inSideboard = true
            continue
        }

        // Mainboard / deck / commander section headers.
        if lower.hasPrefix("// main")
            || lower.hasPrefix("deck")
            || lower.hasPrefix("// deck")
            || lower.hasPrefix("// commander")
            || lower.hasPrefix("commander") {
            inSideboard = false
            continue
        }

        // Skip other commentary lines.
        if line.hasPrefix("//") || line.hasPrefix("#") { continue }

        var isSideboardCard = inSideboard
        var cardText = line

        // Per-line sideboard marker: `SB: 2 Card Name`.
        if cardText.range(of: #"^sb:\s*"#, options: [.regularExpression, .caseInsensitive]) != nil {
            isSideboardCard = true
            cardText = cardText.replacingOccurrences(of: #"^sb:\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
                .trimmingCharacters(in: .whitespaces)
        }

        guard let parsed = parseCardLine(cardText, lineNumber: index + 1) else { continue }

        let entry = ParsedDeckEntry(
            lineNumber: index + 1,
            quantity: parsed.quantity,
            name: parsed.name,
            isSideboard: isSideboardCard,
            setCode: parsed.setCode,
            collectorNumber: parsed.collectorNumber
        )

        if isSideboardCard {
            sideboard.append(entry)
        } else {
            mainboard.append(entry)
        }
        totalLines += 1
        sawCard = true
    }

    guard sawCard else { throw ImportError.noCardsDetected }

    return ParsedDecklist(mainboard: mainboard, sideboard: sideboard, totalLines: totalLines)
}

// MARK: - Collection text parsing (same line grammar, grouped by card name)

struct ParsedCollectionLine: Hashable {
    var quantity: Int
    var name: String
    var setCode: String?
    var collectorNumber: String?
}

func parseCollectionText(_ text: String) throws -> [ParsedCollectionLine] {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw ImportError.emptyInput }

    var result: [String: ParsedCollectionLine] = [:]

    for (index, rawLine) in text.components(separatedBy: .newlines).enumerated() {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        if line.isEmpty || line.hasPrefix("#") { continue }

        guard let entry = parseCardLine(line, lineNumber: index + 1) else { continue }

        let collectionEntry = ParsedCollectionLine(
            quantity: entry.quantity,
            name: entry.name,
            setCode: entry.setCode,
            collectorNumber: entry.collectorNumber
        )

        let key = normalizeCardName(entry.name)
        if let existing = result[key] {
            result[key] = ParsedCollectionLine(
                quantity: existing.quantity + entry.quantity,
                name: existing.name,
                setCode: existing.setCode,
                collectorNumber: existing.collectorNumber
            )
        } else {
            result[key] = collectionEntry
        }
    }

    guard !result.isEmpty else { throw ImportError.noCardsDetected }
    return Array(result.values)
}

// MARK: - Shared line grammar

private struct RawParsedLine {
    var quantity: Int
    var name: String
    var setCode: String?
    var collectorNumber: String?
}

private func parseCardLine(_ raw: String, lineNumber: Int) -> RawParsedLine? {
    var cardText = raw.trimmingCharacters(in: .whitespaces)
    guard !cardText.isEmpty, !cardText.hasPrefix("//"), !cardText.hasPrefix("#") else { return nil }

    // Quantity: "4 ", "4x ", "1 ", or default 1.
    var quantity = 1
    if let qtyMatch = cardText.firstMatch(of: #/(?i)(\d+)(?:x|\s)\s*(.*)$/#) {
        let qty = Int(qtyMatch.output.1)
        quantity = qty ?? 1
        cardText = String(qtyMatch.output.2).trimmingCharacters(in: .whitespaces)
    }

    // Clean trailing tags like *F*, *E*, *Foil*.
    cardText = cardText.replacingOccurrences(
        of: #"\s*\*[A-Za-z0-9]+\*\s*$"#,
        with: "",
        options: .regularExpression
    ).trimmingCharacters(in: .whitespaces)

    var setCode: String?
    var collectorNumber: String?

    // Set code + collector number: `(2XM) 198`, `(CLB) 12`, `(LCC) 191p`, `(PCLB) 360s`.
    let setPattern = #"\(([A-Za-z0-9_]{3,6})\)\s*([A-Za-z0-9\-pP]+)?$"#
    if let setMatch = cardText.range(of: setPattern, options: .regularExpression),
       let code = extractGroup(cardText, pattern: setPattern, group: 1) {
        setCode = code.lowercased()
        collectorNumber = extractGroup(cardText, pattern: setPattern, group: 2)?.trimmingCharacters(in: .whitespaces)
        cardText = cardText.replacingOccurrences(
            of: setPattern,
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespaces)
        _ = setMatch
    }

    // Fallback: `[SET:123]` format.
    let altPattern = #"\[([A-Za-z0-9_]{3,6}):([A-Za-z0-9\-pP]+)\]$"#
    if cardText.range(of: altPattern, options: .regularExpression) != nil,
       let code = extractGroup(cardText, pattern: altPattern, group: 1) {
        setCode = code.lowercased()
        collectorNumber = extractGroup(cardText, pattern: altPattern, group: 2) ?? collectorNumber
        cardText = cardText.replacingOccurrences(
            of: altPattern,
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespaces)
    }

    guard !cardText.isEmpty else { return nil }

    return RawParsedLine(
        quantity: quantity,
        name: cardText,
        setCode: setCode,
        collectorNumber: collectorNumber
    )
}

private func extractGroup(_ text: String, pattern: String, group: Int) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
    let range = NSRange(text.startIndex..., in: text)
    guard let match = regex.firstMatch(in: text, options: [], range: range),
          group < match.numberOfRanges,
          let swiftRange = Range(match.range(at: group), in: text)
    else { return nil }
    return String(text[swiftRange])
}