import Foundation

/// Seeds the demo with a Commander deck, a Modern deck, and a partially owned collection.
struct SeedData {
    let decks: [Deck]
    let collection: [CollectionCard]

    init() {
        let user = MockDataStore.demoUserId

        // Commander deck — Chulane
        let chulaneId = UUID().uuidString
        let chulane = DeckCard(
            id: UUID().uuidString,
            deckId: "",
            cardScryfallId: "pending:chulane-teller-of-tales",
            cardName: "Chulane, Teller of Tales",
            quantity: 1,
            assignedQuantity: 0,
            isSideboard: false,
            isCommander: true,
            manaCost: "{2}{G}{W}{U}",
            typeLine: "Legendary Creature — Human Druid",
            imageUri: nil
        )

        let solRing = DeckCard(
            cardScryfallId: "pending:sol-ring",
            cardName: "Sol Ring",
            quantity: 1,
            manaCost: "{1}",
            typeLine: "Artifact"
        )
        let arcaneSignet = DeckCard(
            cardScryfallId: "pending:arcane-signet",
            cardName: "Arcane Signet",
            quantity: 1,
            manaCost: "{2}",
            typeLine: "Artifact"
        )
        let birds = DeckCard(
            cardScryfallId: "pending:birds-of-paradise",
            cardName: "Birds of Paradise",
            quantity: 1,
            manaCost: "{G}",
            typeLine: "Creature — Bird"
        )
        let llanowar = DeckCard(
            cardScryfallId: "pending:llanowar-elves",
            cardName: "Llanowar Elves",
            quantity: 1,
            manaCost: "{G}",
            typeLine: "Creature — Elf Druid"
        )
        let cyclonic = DeckCard(
            cardScryfallId: "pending:cyclonic-rift",
            cardName: "Cyclonic Rift",
            quantity: 1,
            manaCost: "{1}{U}",
            typeLine: "Instant"
        )
        let upkeepLands = [
            DeckCard(cardScryfallId: "pending:forest", cardName: "Forest", quantity: 12, manaCost: "", typeLine: "Basic Land — Forest"),
            DeckCard(cardScryfallId: "pending:island", cardName: "Island", quantity: 10, manaCost: "", typeLine: "Basic Land — Island"),
            DeckCard(cardScryfallId: "pending:plains", cardName: "Plains", quantity: 8, manaCost: "", typeLine: "Basic Land — Plains"),
        ]

        let chulaneDeck = Deck(
            id: UUID().uuidString,
            userId: user,
            name: "Chulane, Teller of Tales",
            format: "Commander",
            description: "Mazo de rampa y robo de criaturas.",
            commander: "Chulane, Teller of Tales",
            commanderScryfallId: "pending:chulane-teller-of-tales",
            commanderImageUri: nil,
            cards: [chulane, solRing, arcaneSignet, birds, llanowar, cyclonic] + upkeepLands
        )

        // Modern deck — Esper control
        let snapcaster = DeckCard(cardScryfallId: "pending:snapcaster-mage", cardName: "Snapcaster Mage", quantity: 4, manaCost: "{1}{U}", typeLine: "Creature — Human Wizard")
        let bolt = DeckCard(cardScryfallId: "pending:lightning-bolt", cardName: "Lightning Bolt", quantity: 4, manaCost: "{R}", typeLine: "Instant")
        let counterspell = DeckCard(cardScryfallId: "pending:counterspell", cardName: "Counterspell", quantity: 4, manaCost: "{U}{U}", typeLine: "Instant")
        let wrath = DeckCard(cardScryfallId: "pending:wrath-of-god", cardName: "Wrath of God", quantity: 3, manaCost: "{2}{W}{W}", typeLine: "Sorcery")
        let scaldingTarn = DeckCard(cardScryfallId: "pending:scalding-tarn", cardName: "Scalding Tarn", quantity: 4, manaCost: "", typeLine: "Land")
        let modernLands = [
            DeckCard(cardScryfallId: "pending:island", cardName: "Island", quantity: 6, manaCost: "", typeLine: "Basic Land — Island"),
            DeckCard(cardScryfallId: "pending:mountain", cardName: "Mountain", quantity: 3, manaCost: "", typeLine: "Basic Land — Mountain"),
        ]

        let esperDeck = Deck(
            id: UUID().uuidString,
            userId: user,
            name: "Esper Control",
            format: "Modern",
            description: "Control azul-blanco-negro con Snapcaster.",
            commander: nil,
            commanderScryfallId: nil,
            commanderImageUri: nil,
            cards: [snapcaster, bolt, counterspell, wrath, scaldingTarn] + modernLands
        )

        // Collection — partial ownership so percentages are meaningful.
        let collectionCards: [CollectionCard] = [
            CollectionCard(cardScryfallId: "pending:sol-ring", cardName: "Sol Ring", quantity: 2, manaCost: "{1}", typeLine: "Artifact"),
            CollectionCard(cardScryfallId: "pending:arcane-signet", cardName: "Arcane Signet", quantity: 2, manaCost: "{2}", typeLine: "Artifact"),
            CollectionCard(cardScryfallId: "pending:birds-of-paradise", cardName: "Birds of Paradise", quantity: 1, manaCost: "{G}", typeLine: "Creature — Bird"),
            CollectionCard(cardScryfallId: "pending:llanowar-elves", cardName: "Llanowar Elves", quantity: 4, manaCost: "{G}", typeLine: "Creature — Elf Druid"),
            CollectionCard(cardScryfallId: "pending:forest", cardName: "Forest", quantity: 40, manaCost: "", typeLine: "Basic Land — Forest"),
            CollectionCard(cardScryfallId: "pending:island", cardName: "Island", quantity: 40, manaCost: "", typeLine: "Basic Land — Island"),
            CollectionCard(cardScryfallId: "pending:plains", cardName: "Plains", quantity: 40, manaCost: "", typeLine: "Basic Land — Plains"),
            CollectionCard(cardScryfallId: "pending:mountain", cardName: "Mountain", quantity: 30, manaCost: "", typeLine: "Basic Land — Mountain"),
            CollectionCard(cardScryfallId: "pending:snapcaster-mage", cardName: "Snapcaster Mage", quantity: 3, manaCost: "{1}{U}", typeLine: "Creature — Human Wizard"),
            CollectionCard(cardScryfallId: "pending:lightning-bolt", cardName: "Lightning Bolt", quantity: 3, manaCost: "{R}", typeLine: "Instant"),
            CollectionCard(cardScryfallId: "pending:counterspell", cardName: "Counterspell", quantity: 4, manaCost: "{U}{U}", typeLine: "Instant"),
        ]

        self.decks = [esperDeck, chulaneDeck]
        self.collection = collectionCards
    }
}