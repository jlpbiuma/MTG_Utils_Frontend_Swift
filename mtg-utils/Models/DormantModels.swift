import Foundation

// MARK: - Dormant Cards Models

public struct DormantCardItem: Codable, Identifiable, Hashable {
    public let id: String
    public let cardScryfallId: String
    public let cardName: String
    public let isFoil: Bool
    public let quantity: Int
    public let setCode: String?
    public let collectorNumber: String?
    public let manaCost: String?
    public let typeLine: String?
    public let imageUri: String?
    public let price: Double
    public let totalValue: Double
}

public struct DormantCardsResponse: Codable {
    public let totalCards: Int
    public let uniqueCards: Int
    public let totalValue: Double
    public let currencySymbol: String
    public let provider: String
    public let activeCommanders: [String]
    public let cards: [DormantCardItem]
}
