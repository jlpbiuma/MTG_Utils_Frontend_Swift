import Foundation
import Testing
@testable import mtg_utils

// Port of frontend/tests/unit/import-parser.test.ts plus the alphanumeric
// collector-number / alt-format cases exercised by the fixture suite.

@Suite("Decklist & Collection Text Parser")
struct CardParserTests {

    @Test func parsesStandardPlaintextLines() throws {
        let text = """
        4 Lightning Bolt
        2 Counterspell
        1 Sol Ring
        """
        let parsed = try parseDecklistText(text)

        #expect(parsed.mainboard.count == 3)
        #expect(parsed.sideboard.isEmpty)

        let first = parsed.mainboard[0]
        #expect(first.quantity == 4)
        #expect(first.name == "Lightning Bolt")
        #expect(first.setCode == nil)
        #expect(first.collectorNumber == nil)
        #expect(first.isSideboard == false)

        #expect(parsed.mainboard[1].quantity == 2)
        #expect(parsed.mainboard[1].name == "Counterspell")
        #expect(parsed.mainboard[2].quantity == 1)
        #expect(parsed.mainboard[2].name == "Sol Ring")
    }

    @Test func handlesFourXNotationAndDefaultQuantity() throws {
        let text = """
        4x Brainstorm
        Black Lotus
        """
        let parsed = try parseDecklistText(text)

        #expect(parsed.mainboard.count == 2)
        #expect(parsed.mainboard[0].quantity == 4)
        #expect(parsed.mainboard[0].name == "Brainstorm")
        #expect(parsed.mainboard[1].quantity == 1)
        #expect(parsed.mainboard[1].name == "Black Lotus")
    }

    @Test func parsesMoxfieldExportWithSetsAndFoilFlags() throws {
        let text = """
        1 Atraxa, Praetors' Voice (2XM) 198 *F*
        1 Sol Ring (C21) 263
        4 Lightning Bolt (CLB) 123 *E*
        """
        let parsed = try parseDecklistText(text)

        #expect(parsed.mainboard.count == 3)

        let atraxa = parsed.mainboard[0]
        #expect(atraxa.quantity == 1)
        #expect(atraxa.name == "Atraxa, Praetors' Voice")
        #expect(atraxa.setCode == "2xm")
        #expect(atraxa.collectorNumber == "198")

        let solRing = parsed.mainboard[1]
        #expect(solRing.name == "Sol Ring")
        #expect(solRing.setCode == "c21")
        #expect(solRing.collectorNumber == "263")

        let bolt = parsed.mainboard[2]
        #expect(bolt.name == "Lightning Bolt")
        #expect(bolt.setCode == "clb")
    }

    @Test func detectsSideboardSections() throws {
        let text = """
        4 Lightning Bolt
        2 Counterspell

        // Sideboard
        2 Pyroblast
        1 Red Elemental Blast
        """
        let parsed = try parseDecklistText(text)

        #expect(parsed.mainboard.count == 2)
        #expect(parsed.mainboard.allSatisfy { !$0.isSideboard })

        #expect(parsed.sideboard.count == 2)
        #expect(parsed.sideboard[0].name == "Pyroblast")
        #expect(parsed.sideboard[0].isSideboard)
        #expect(parsed.sideboard[1].name == "Red Elemental Blast")
        #expect(parsed.sideboard[1].isSideboard)
    }

    @Test func supportsMTGArenaHeaders() throws {
        let text = """
        Deck
        4 Thoughtseize (AKR) 127
        2 Fatal Push (KLR) 84

        Sideboard
        2 Duress (M21) 96
        """
        let parsed = try parseDecklistText(text)

        #expect(parsed.mainboard.count == 2)
        #expect(parsed.mainboard[0].isSideboard == false)
        #expect(parsed.mainboard[0].name == "Thoughtseize")
        #expect(parsed.sideboard.count == 1)
        #expect(parsed.sideboard[0].isSideboard)
        #expect(parsed.sideboard[0].name == "Duress")
    }

    @Test func supportsSBLinePrefix() throws {
        let text = """
        4 Lightning Bolt
        SB: 2 Smash to Smithereens
        """
        let parsed = try parseDecklistText(text)

        #expect(parsed.mainboard.count == 1)
        #expect(parsed.sideboard.count == 1)
        #expect(parsed.sideboard[0].isSideboard)
        #expect(parsed.sideboard[0].quantity == 2)
        #expect(parsed.sideboard[0].name == "Smash to Smithereens")
    }

    @Test func parsesAlphanumericCollectorNumbers() throws {
        let text = """
        1 Annie Joins Up (LCC) 191p
        1 Sea of Clouds (PCLB) 360s *F*
        1 Path to Exile (PLST) E02-3
        """
        let parsed = try parseDecklistText(text)

        #expect(parsed.mainboard.count == 3)
        #expect(parsed.mainboard[0].name == "Annie Joins Up")
        #expect(parsed.mainboard[0].setCode == "lcc")
        #expect(parsed.mainboard[0].collectorNumber == "191p")

        #expect(parsed.mainboard[1].name == "Sea of Clouds")
        #expect(parsed.mainboard[1].setCode == "pclb")
        #expect(parsed.mainboard[1].collectorNumber == "360s")

        #expect(parsed.mainboard[2].name == "Path to Exile")
        #expect(parsed.mainboard[2].collectorNumber == "E02-3")
    }

    @Test func supportsBracketSetTagFormat() throws {
        let text = """
        1 Island [ANA:1]
        2 Mountain (MKM) 283
        """
        let parsed = try parseDecklistText(text)

        #expect(parsed.mainboard.count == 2)
        #expect(parsed.mainboard[0].name == "Island")
        #expect(parsed.mainboard[0].setCode == "ana")
        #expect(parsed.mainboard[0].collectorNumber == "1")
        #expect(parsed.mainboard[1].name == "Mountain")
        #expect(parsed.mainboard[1].setCode == "mkm")
    }

    @Test func throwsOnEmptyInput() {
        #expect(throws: ImportError.self) { try parseDecklistText("   ") }
    }

    @Test func throwsWhenNoCardsDetected() {
        #expect(throws: ImportError.self) { try parseDecklistText("// Comentario\n# otro\n") }
    }

    @Test func collectionTextGroupsQuantitiesByNormalizedName() throws {
        let text = """
        2 Sol Ring (C21) 263
        1 Sol Ring (CMR) 36x
        """
        let collection = try parseCollectionText(text)

        #expect(collection.count == 1)
        #expect(collection[0].quantity == 3)
        #expect(collection[0].name == "Sol Ring")
    }
}