import Foundation

// MARK: - Simulated Collections Models

public struct CandidateDeckInfo: Codable, Identifiable, Hashable {
    public let deckId: String
    public let deckName: String
    public let completionPercentage: Double
    public let colors: [String]
    public let requestedQuantity: Int
    public let assignedQuantity: Int
    public let missingQuantity: Int
    public let potentialGain: Double

    public var id: String { deckId }
}

public struct SimulatedCardAnalysisItem: Codable, Identifiable, Hashable {
    public let cardName: String
    public let cardScryfallId: String?
    public let quantity: Int
    public let setCode: String?
    public let collectorNumber: String?
    public let manaCost: String?
    public let typeLine: String?
    public let imageUri: String?
    public let unitPrice: Double
    public let totalPrice: Double
    public let copiesOwnedReal: Int
    public let copiesNeededTotal: Int
    public let usefulCopies: Int
    public let surplusCopies: Int
    public let sellableCopies: Int
    public let sellableValue: Double
    public let netCompletionGain: Double
    public let candidateDeckCount: Int
    public let candidateDecks: [CandidateDeckInfo]

    public var id: String { cardScryfallId ?? cardName }
}

public struct SimulatedCollectionSummary: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let description: String?
    public let totalCards: Int
    public let uniqueCards: Int
    public let totalEconomicValue: Double
    public let economicValueExcludingOwned: Double
    public let sellableValue: Double
    public let sellableCardsCount: Int
    public let globalNetGain: Double
    public let usefulCardsCount: Int
    public let alreadyOwnedCardsCount: Int
    public let benefitedDecksCount: Int
    public let createdAt: String
    public let updatedAt: String
}

public struct SimulatedCollectionAnalysisResponse: Codable {
    public let id: String?
    public let name: String
    public let description: String?
    public let totalEconomicValue: Double
    public let economicValueExcludingOwned: Double
    public let sellableValue: Double
    public let sellableCardsCount: Int
    public let currencySymbol: String
    public let globalNetGain: Double
    public let totalCards: Int
    public let uniqueCards: Int
    public let usefulCardsCount: Int
    public let alreadyOwnedCardsCount: Int
    public let benefitedDecksCount: Int
    public let cards: [SimulatedCardAnalysisItem]
}

public struct SimulatedCollectionCreateRequest: Codable {
    public let name: String
    public let description: String?
    public let rawText: String

    public init(name: String, description: String? = nil, rawText: String) {
        self.name = name
        self.description = description
        self.rawText = rawText
    }
}

public struct SimulatedCollectionAnalyzeRequest: Codable {
    public let rawText: String
    public let provider: String

    public init(rawText: String, provider: String = "cardmarket") {
        self.rawText = rawText
        self.provider = provider
    }
}
