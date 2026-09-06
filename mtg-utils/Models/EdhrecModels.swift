import Foundation

// MARK: - EDHREC models

struct EdhrecParsedCard: Identifiable, Hashable {
    let id: String
    let name: String
    let normalizedName: String
    let sanitized: String
    var category: String
    var categories: [String]
    let numDecks: Int
    let potentialDecks: Int
    let inclusionPct: Double
    let synergy: Double
    let imageUri: String?
}

struct EdhrecCommanderInfo: Hashable {
    let name: String
    let id: String
    let imageUri: String?
    let numDecks: Int
    let colorIdentity: [String]
    let typeLine: String

    var imageUrl: URL? { imageUri.flatMap(URL.init(string:)) }
}

struct EdhrecCommanderResponse: Hashable {
    let commander: EdhrecCommanderInfo?
    let categories: [String]
    let cards: [EdhrecParsedCard]
}

/// A recommendation enriched with the user's deck / collection ownership status.
struct EdhrecCardRecommendation: Identifiable, Hashable {
    let id: String
    let name: String
    let normalizedName: String
    let sanitized: String
    let category: String
    let numDecks: Int
    let potentialDecks: Int
    let inclusionPct: Double
    let synergy: Double
    let imageUri: String?
    let isInDeck: Bool
    let isInCollection: Bool
    let collectionQuantity: Int

    var imageUrl: URL? { imageUri.flatMap(URL.init(string:)) }
}

struct EdhrecRecommendationsResult: Hashable {
    var hasCommander: Bool
    var commanderName: String?
    var commanderImageUri: String?
    var commanderScryfallId: String?
    var numDecks: Int?
    var colorIdentity: [String]?
    var categories: [String]
    var recommendations: [EdhrecCardRecommendation]
    var error: String?
}

// MARK: - Raw decoding shapes for json.edhrec.com

struct EdhrecPayload: Decodable {
    let container: EdhrecContainer?

    enum CodingKeys: String, CodingKey { case container }
}

struct EdhrecContainer: Decodable {
    let jsonDict: EdhrecJsonDict?

    enum CodingKeys: String, CodingKey { case jsonDict = "json_dict" }
}

struct EdhrecJsonDict: Decodable {
    let card: EdhrecRawCommander?
    let cardlists: [EdhrecRawCardlist]?
}

struct EdhrecRawCommander: Decodable {
    let name: String?
    let id: String?
    let imageUris: [EdhrecRawImageUri]?
    let numDecks: Int?
    let colorIdentity: [String]?
    let typeLine: String?

    enum CodingKeys: String, CodingKey {
        case name, id
        case imageUris = "image_uris"
        case numDecks = "num_decks"
        case colorIdentity = "color_identity"
        case typeLine = "type_line"
    }
}

struct EdhrecRawImageUri: Decodable, Hashable {
    let normal: String?
}

struct EdhrecRawCardlist: Decodable {
    let tag: String?
    let header: String?
    let cardviews: [EdhrecRawCardview]?
}

struct EdhrecRawCardview: Decodable {
    let id: String?
    let name: String?
    let sanitized: String?
    let synergy: Double?
    let numDecks: Int?
    let potentialDecks: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, sanitized, synergy
        case numDecks = "num_decks"
        case potentialDecks = "potential_decks"
    }
}