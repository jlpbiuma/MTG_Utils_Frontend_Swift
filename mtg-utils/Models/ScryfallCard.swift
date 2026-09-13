import Foundation

// MARK: - Scryfall API models

struct ScryfallSearchResponse: Decodable {
    let data: [ScryfallCard]
    let hasMore: Bool
    let totalCards: Int

    enum CodingKeys: String, CodingKey {
        case data
        case hasMore = "has_more"
        case totalCards = "total_cards"
    }
}

struct ScryfallAutocompleteResponse: Decodable {
    let data: [String]
}

/// A card as returned by the public Scryfall API.
struct ScryfallCard: Identifiable, Decodable, Hashable {
    let id: String
    let name: String
    let manaCost: String?
    let cmc: Double?
    let typeLine: String?
    let oracleText: String?
    let set: String?
    let setName: String?
    let collectorNumber: String?
    let rarity: String?
    let imageUris: ScryfallImageUris?
    let cardFaces: [ScryfallCardFace]?
    let colorIdentity: [String]?

    enum CodingKeys: String, CodingKey {
        case id, name, cmc, set, rarity
        case cardFaces = "card_faces"
        case manaCost = "mana_cost"
        case typeLine = "type_line"
        case oracleText = "oracle_text"
        case setName = "set_name"
        case collectorNumber = "collector_number"
        case imageUris = "image_uris"
        case colorIdentity = "color_identity"
    }

    /// Color identity in WUBRG order (empty for colorless).
    var displayColorIdentity: [String] {
        let order = ["W", "U", "B", "R", "G"]
        let set = Set(colorIdentity ?? [])
        return order.filter { set.contains($0) }
    }

    // MARK: Convenience display helpers (handles double-faced / front-face cards)

    var displayImageUri: String? {
        if let normal = imageUris?.normal { return normal }
        return cardFaces?.first?.imageUris?.normal
    }

    var displayImageSmallUri: String? {
        if let small = imageUris?.small { return small }
        return cardFaces?.first?.imageUris?.small
    }

    var displayManaCost: String? {
        manaCost ?? cardFaces?.first?.manaCost
    }

    var displayTypeLine: String? {
        typeLine ?? cardFaces?.first?.typeLine
    }

    var displayImageUrl: URL? {
        AppConfiguration.imageURL(from: displayImageUri)
    }

    var displayImageSmallUrl: URL? {
        AppConfiguration.imageURL(from: displayImageSmallUri ?? displayImageUri)
    }
}

struct ScryfallImageUris: Decodable, Hashable {
    let small: String?
    let normal: String?
    let large: String?
    let artCrop: String?

    enum CodingKeys: String, CodingKey {
        case small, normal, large
        case artCrop = "art_crop"
    }
}

struct ScryfallCardFace: Decodable, Hashable {
    let name: String?
    let manaCost: String?
    let typeLine: String?
    let imageUris: ScryfallImageUris?

    enum CodingKeys: String, CodingKey {
        case name
        case manaCost = "mana_cost"
        case typeLine = "type_line"
        case imageUris = "image_uris"
    }
}

/// Resolved card metadata used when importing decklists / collections.
struct ResolvedCardData: Hashable {
    let scryfallId: String
    let name: String
    let manaCost: String?
    let typeLine: String?
    let imageUri: String?
    let set: String?
    let collectorNumber: String?

    var displayName: String { name }
}

struct ScryfallSearchResult: Hashable {
    var totalCards: Int
    var hasMore: Bool
    var data: [ScryfallCard]
}

// MARK: - Spanish card details (backend `/api/scryfall/card`)

/// Spanish-localized card details served by the MTG Utils backend. Mirrors
/// `SpanishCardDetails` on the web frontend / `get_card_details_es` on the backend.
struct SpanishCardDetails: Decodable, Hashable {
    let id: String
    let name: String
    let nameEs: String
    let manaCost: String?
    let cmc: Double?
    let typeLine: String?
    let typeLineEs: String?
    let oracleText: String?
    let oracleTextEs: String?
    let flavorText: String?
    let flavorTextEs: String?
    let power: String?
    let toughness: String?
    let loyalty: String?
    let defense: String?
    let rarity: String?
    let rarityEs: String
    let set: String
    let setName: String?
    let collectorNumber: String?
    let artist: String?
    let hasSpanishPrint: Bool
    let imageUris: ScryfallImageUris?
    let cardFaces: [SpanishCardFace]?
    let legalities: [SpanishCardLegality]?
    let prices: SpanishCardPrices?
    let printings: [CardPrintingDetail]?
    let rulings: [CardRulingDetail]?

    enum CodingKeys: String, CodingKey {
        case id, name, cmc, set, rarity, power, toughness, loyalty, defense, artist
        case cardFaces = "card_faces"
        case nameEs = "name_es"
        case manaCost = "mana_cost"
        case typeLine = "type_line"
        case typeLineEs = "type_line_es"
        case oracleText = "oracle_text"
        case oracleTextEs = "oracle_text_es"
        case flavorText = "flavor_text"
        case flavorTextEs = "flavor_text_es"
        case rarityEs = "rarity_es"
        case setName = "set_name"
        case collectorNumber = "collector_number"
        case hasSpanishPrint = "has_spanish_print"
        case imageUris = "image_uris"
        case legalities
        case prices
        case printings, rulings
    }

    var displayName: String { nameEs.isEmpty ? name : nameEs }
    var displayTypeLine: String { typeLineEs ?? typeLine ?? "" }
    var displayOracleText: String { oracleTextEs ?? oracleText ?? "" }
    var displayFlavorText: String { flavorTextEs ?? flavorText ?? "" }

    var imageUri: String? {
        imageUris?.normal ?? cardFaces?.first?.imageUris?.normal
    }

    var largeImageUri: String? {
        imageUris?.large ?? imageUri ?? cardFaces?.first?.imageUris?.large
    }
}

struct CardPrintingDetail: Decodable, Hashable, Identifiable {
    let id: String
    let setCode: String
    let collectorNumber: String
    let nameEs: String
    let setName: String?
    let rarity: String?
    let imageUri: String?
    let imageUriSmall: String?
    let imageUriLarge: String?
    let trend: Double?
    let min: Double?
    let max: Double?
    let cardtraderTrend: Double?
    let cardtraderMin: Double?
    let cardtraderMax: Double?
    let priceEur: Double?
    let priceEurFoil: Double?
    let priceUsd: Double?
    let priceUsdFoil: Double?
    let releasedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, rarity, trend, min, max
        case setCode = "set_code"
        case setName = "set_name"
        case collectorNumber = "collector_number"
        case nameEs = "name_es"
        case imageUri = "image_uri"
        case imageUriSmall = "image_uri_small"
        case imageUriLarge = "image_uri_large"
        case cardtraderTrend = "cardtrader_trend"
        case cardtraderMin = "cardtrader_min"
        case cardtraderMax = "cardtrader_max"
        case priceEur = "price_eur"
        case priceEurFoil = "price_eur_foil"
        case priceUsd = "price_usd"
        case priceUsdFoil = "price_usd_foil"
        case releasedAt = "released_at"
    }
}

struct CardRulingDetail: Decodable, Hashable, Identifiable {
    let date: String
    let text: String
    let source: String
    var id: String { "\(date)-\(text)" }
}

struct SpanishCardFace: Decodable, Hashable {
    let name: String?
    let nameEs: String?
    let manaCost: String?
    let typeLine: String?
    let typeLineEs: String?
    let oracleText: String?
    let oracleTextEs: String?
    let flavorTextEs: String?
    let power: String?
    let toughness: String?
    let loyalty: String?
    let defense: String?
    let imageUris: ScryfallImageUris?

    enum CodingKeys: String, CodingKey {
        case name, power, toughness, loyalty, defense
        case nameEs = "name_es"
        case manaCost = "mana_cost"
        case typeLine = "type_line"
        case typeLineEs = "type_line_es"
        case oracleText = "oracle_text"
        case oracleTextEs = "oracle_text_es"
        case flavorTextEs = "flavor_text_es"
        case imageUris = "image_uris"
    }

    var displayName: String { nameEs ?? name ?? "" }
    var displayTypeLine: String { typeLineEs ?? typeLine ?? "" }
    var displayOracleText: String { oracleTextEs ?? oracleText ?? "" }
}

struct SpanishCardLegality: Decodable, Hashable, Identifiable {
    let format: String
    let formatName: String
    let status: String
    let statusEs: String

    enum CodingKeys: String, CodingKey {
        case format
        case formatName = "format_name"
        case status
        case statusEs = "status_es"
    }

    var id: String { format }

    var isLegal: Bool { status == "legal" }
}

struct SpanishCardPrices: Decodable, Hashable {
    let eur: Double?
    let eurFoil: Double?
    let usd: Double?
    let usdFoil: Double?

    enum CodingKeys: String, CodingKey {
        case eur
        case eurFoil = "eur_foil"
        case usd
        case usdFoil = "usd_foil"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        func number(_ key: CodingKeys) -> Double? {
            if let value = try? values.decodeIfPresent(Double.self, forKey: key) { return value }
            if let value = try? values.decodeIfPresent(String.self, forKey: key) { return Double(value) }
            return nil
        }
        eur = number(.eur)
        eurFoil = number(.eurFoil)
        usd = number(.usd)
        usdFoil = number(.usdFoil)
    }
}
