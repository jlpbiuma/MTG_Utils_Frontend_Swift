import Foundation

// MARK: - EDHREC slug helpers

/// Builds the EDHREC URL slug for a commander name.
/// - Lowercase, removes accents, strips non-alphanumeric punctuation,
///   joins split-card faces (`A // B` → `a-b`) as EDHREC does, spaces → `-`.
func toEdhrecSlug(_ name: String) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "" }

    var slug = trimmed.folding(
        options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
        locale: Locale(identifier: "es_ES")
    )
    slug = slug.lowercased()

    // Join split-card faces like EDHREC partner pages: "A // B" → "A - B".
    slug = slug.replacingOccurrences(of: #"/{2,}"#, with: "-", options: .regularExpression)

    // Remove non-alphanumeric characters except spaces.
    slug = slug.replacingOccurrences(of: #"[^a-z0-9\s-]"#, with: "", options: .regularExpression)

    // Trim leading/trailing hyphens and spaces.
    slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "- "))

    // Collapse multiple spaces/hyphens and replace spaces with hyphens.
    slug = slug.replacingOccurrences(of: #"[\s-]+"#, with: "-", options: .regularExpression)

    return slug
}

/// Returns the EDHREC CDN card image URL for a Scryfall UUID used by the
/// recommendations sheet: `https://card-images.edhrec.com/normal/front/{c}/{n}/{uuid}.jpg`
/// where `c`/`n` are the first two characters of the UUID.
func edhrecCardImageUrl(forScryfallId scryfallId: String) -> String? {
    let trimmed = scryfallId.trimmingCharacters(in: .whitespaces).lowercased()
    guard
        trimmed.range(
            of: #"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"#,
            options: .regularExpression
        ) != nil
    else { return nil }

    let characters = Array(trimmed)
    return "https://card-images.edhrec.com/normal/front/\(characters[0])/\(characters[1])/\(trimmed).jpg"
}

/// Returns the JSON API endpoint for a commander's EDHREC page data.
func edhrecJsonUrl(for commanderName: String) -> URL? {
    let slug = toEdhrecSlug(commanderName)
    guard !slug.isEmpty else { return nil }
    return URL(string: "https://json.edhrec.com/pages/commanders/\(slug).json")
}

/// Returns the human-readable EDHREC page URL for a commander.
func edhrecPageUrl(for commanderName: String) -> URL? {
    let slug = toEdhrecSlug(commanderName)
    guard !slug.isEmpty else { return nil }
    return URL(string: "https://edhrec.com/commanders/\(slug)")
}