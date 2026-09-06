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

    enum CodingKeys: String, CodingKey {
        case id, name, cmc, set, rarity
        case cardFaces = "card_faces"
        case manaCost = "mana_cost"
        case typeLine = "type_line"
        case oracleText = "oracle_text"
        case setName = "set_name"
        case collectorNumber = "collector_number"
        case imageUris = "image_uris"
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
        displayImageUri.flatMap(URL.init(string:))
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