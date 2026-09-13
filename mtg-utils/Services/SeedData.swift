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
            imageUri: nil,
            setCode: "ELD"
        )

        let teferi = DeckCard(
            cardScryfallId: "pending:teferi-time-raveler",
            cardName: "Teferi, Time Raveler",
            quantity: 1,
            manaCost: "{1}{W}{U}",
            typeLine: "Legendary Planeswalker — Teferi",
            setCode: "WAR"
        )
        let rhystic = DeckCard(
            cardScryfallId: "pending:rhystic-study",
            cardName: "Rhystic Study",
            quantity: 1,
            manaCost: "{2}{U}",
            typeLine: "Enchantment",
            setCode: "WOT"
        )
        let solRing = DeckCard(
            cardScryfallId: "pending:sol-ring",
            cardName: "Sol Ring",
            quantity: 1,
            manaCost: "{1}",
            typeLine: "Artifact",
            setCode: "C21"
        )
        let arcaneSignet = DeckCard(
            cardScryfallId: "pending:arcane-signet",
            cardName: "Arcane Signet",
            quantity: 1,
            manaCost: "{2}",
            typeLine: "Artifact",
            setCode: "ELD"
        )
        let birds = DeckCard(
            cardScryfallId: "pending:birds-of-paradise",
            cardName: "Birds of Paradise",
            quantity: 1,
            manaCost: "{G}",
            typeLine: "Creature — Bird",
            setCode: "DMR"
        )
        let llanowar = DeckCard(
            cardScryfallId: "pending:llanowar-elves",
            cardName: "Llanowar Elves",
            quantity: 1,
            manaCost: "{G}",
            typeLine: "Creature — Elf Druid",
            setCode: "DOM"
        )
        let cyclonic = DeckCard(
            cardScryfallId: "pending:cyclonic-rift",
            cardName: "Cyclonic Rift",
            quantity: 1,
            manaCost: "{1}{U}",
            typeLine: "Instant",
            setCode: "2XM"
        )
        let wrathOfGod = DeckCard(
            cardScryfallId: "pending:wrath-of-god",
            cardName: "Wrath of God",
            quantity: 1,
            manaCost: "{2}{W}{W}",
            typeLine: "Sorcery",
            setCode: "DMR"
        )
        let upkeepLands = [
            DeckCard(cardScryfallId: "pending:forest", cardName: "Forest", quantity: 12, manaCost: "", typeLine: "Basic Land — Forest", setCode: "M21"),
            DeckCard(cardScryfallId: "pending:island", cardName: "Island", quantity: 10, manaCost: "", typeLine: "Basic Land — Island", setCode: "M21"),
            DeckCard(cardScryfallId: "pending:plains", cardName: "Plains", quantity: 8, manaCost: "", typeLine: "Basic Land — Plains", setCode: "M21"),
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
            cards: [chulane, teferi, rhystic, wrathOfGod, cyclonic, birds, llanowar, solRing, arcaneSignet] + upkeepLands
        )

        // Modern deck — Esper control
        let snapcaster = DeckCard(cardScryfallId: "pending:snapcaster-mage", cardName: "Snapcaster Mage", quantity: 4, manaCost: "{1}{U}", typeLine: "Creature — Human Wizard", setCode: "ISD")
        let bolt = DeckCard(cardScryfallId: "pending:lightning-bolt", cardName: "Lightning Bolt", quantity: 4, manaCost: "{R}", typeLine: "Instant", setCode: "2X2")
        let counterspell = DeckCard(cardScryfallId: "pending:counterspell", cardName: "Counterspell", quantity: 4, manaCost: "{U}{U}", typeLine: "Instant", setCode: "MH2")
        let wrath = DeckCard(cardScryfallId: "pending:wrath-of-god", cardName: "Wrath of God", quantity: 3, manaCost: "{2}{W}{W}", typeLine: "Sorcery", setCode: "EMA")
        let scaldingTarn = DeckCard(cardScryfallId: "pending:scalding-tarn", cardName: "Scalding Tarn", quantity: 4, manaCost: "", typeLine: "Land", setCode: "MH2")
        let modernLands = [
            DeckCard(cardScryfallId: "pending:island", cardName: "Island", quantity: 6, manaCost: "", typeLine: "Basic Land — Island", setCode: "MH2"),
            DeckCard(cardScryfallId: "pending:mountain", cardName: "Mountain", quantity: 3, manaCost: "", typeLine: "Basic Land — Mountain", setCode: "MH2"),
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
            CollectionCard(cardScryfallId: "pending:teferi-time-raveler", cardName: "Teferi, Time Raveler", quantity: 1, setCode: "WAR", manaCost: "{1}{W}{U}", typeLine: "Legendary Planeswalker — Teferi"),
            CollectionCard(cardScryfallId: "pending:sol-ring", cardName: "Sol Ring", quantity: 2, setCode: "C21", manaCost: "{1}", typeLine: "Artifact"),
            CollectionCard(cardScryfallId: "pending:arcane-signet", cardName: "Arcane Signet", quantity: 2, setCode: "ELD", manaCost: "{2}", typeLine: "Artifact"),
            CollectionCard(cardScryfallId: "pending:birds-of-paradise", cardName: "Birds of Paradise", quantity: 1, setCode: "DMR", manaCost: "{G}", typeLine: "Creature — Bird"),
            CollectionCard(cardScryfallId: "pending:llanowar-elves", cardName: "Llanowar Elves", quantity: 4, setCode: "DOM", manaCost: "{G}", typeLine: "Creature — Elf Druid"),
            CollectionCard(cardScryfallId: "pending:forest", cardName: "Forest", quantity: 40, setCode: "M21", manaCost: "", typeLine: "Basic Land — Forest"),
            CollectionCard(cardScryfallId: "pending:island", cardName: "Island", quantity: 40, setCode: "M21", manaCost: "", typeLine: "Basic Land — Island"),
            CollectionCard(cardScryfallId: "pending:plains", cardName: "Plains", quantity: 40, setCode: "M21", manaCost: "", typeLine: "Basic Land — Plains"),
            CollectionCard(cardScryfallId: "pending:mountain", cardName: "Mountain", quantity: 30, setCode: "MH2", manaCost: "", typeLine: "Basic Land — Mountain"),
            CollectionCard(cardScryfallId: "pending:snapcaster-mage", cardName: "Snapcaster Mage", quantity: 3, setCode: "ISD", manaCost: "{1}{U}", typeLine: "Creature — Human Wizard"),
            CollectionCard(cardScryfallId: "pending:lightning-bolt", cardName: "Lightning Bolt", quantity: 3, setCode: "2X2", manaCost: "{R}", typeLine: "Instant"),
            CollectionCard(cardScryfallId: "pending:counterspell", cardName: "Counterspell", quantity: 4, setCode: "MH2", manaCost: "{U}{U}", typeLine: "Instant"),
        ]

        self.decks = [esperDeck, chulaneDeck]
        self.collection = collectionCards
    }
}