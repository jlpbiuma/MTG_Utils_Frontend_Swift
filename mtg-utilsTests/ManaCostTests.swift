import Foundation
import Testing
@testable import mtg_utils

// Port of frontend/tests/components/mana-cost.test.tsx, adapted to the pure
// symbol parser shared by ManaCostView so no UI rendering is required.

@Suite("ManaCost Symbol Parser")
struct ManaCostTests {

    @Test func rendersNothingForNilOrEmptyCost() {
        #expect(parseManaCostSymbols(nil).isEmpty)
        #expect(parseManaCostSymbols("").isEmpty)
    }

    @Test func parsesAndRendersSymbolsCorrectly() {
        let symbols = parseManaCostSymbols("{2}{U}{U}")
        #expect(symbols == ["2", "U", "U"])
        #expect(symbols.filter { $0 == "U" }.count == 2)
    }

    @Test func parsesHybridSymbolsAsSinglePills() {
        #expect(parseManaCostSymbols("{W/B}{R}") == ["W/B", "R"])
    }

    @Test func parsesVariableAndColorless() {
        #expect(parseManaCostSymbols("{X}{1}{G}{G}") == ["X", "1", "G", "G"])
    }

    @Test func computesPillGlyphsForAccessibility() {
        #expect(manaPillGlyph("U") == "U")
        #expect(manaPillGlyph("W/B") == "W/B")
        #expect(manaPillGlyph("X") == "X")
        #expect(manaPillGlyph("2") == "2")
    }
}
@Suite("Multi-face cards, hybrid and Phyrexian mana")
struct MultiFaceCardRulesTests {

    @Test func splitsFacesAndRecognizesCompositeSymbols() {
        #expect(parseManaCostFaces("{1}{R} // {1}{U}") == [["1", "R"], ["1", "U"]])
        #expect(parseManaCostFaces("{U}") == [["U"]])
        #expect(compositeManaParts("B/P")! == (["B"], true))
        #expect(compositeManaParts("G/U/P")! == (["G", "U"], true))
        #expect(compositeManaParts("2/W")! == (["2", "W"], false))
        #expect(compositeManaParts("1/2") == nil)
    }

    @Test func manaValueMatchesWebAndBackend() {
        #expect(extractCmc(from: "{2/W}{2/W}{2/W}") == 6)
        #expect(extractCmc(from: "{1}{B/P}{B/P}") == 3)
        #expect(extractCmc(from: "{HW}") == 0.5)
        #expect(extractCmc(from: "{X}{G}{G}") == 2)
        #expect(extractCmc(from: "{1}{R} // {1}{U}", typeLine: "Instant // Instant") == 4)
        #expect(extractCmc(from: "{2}{R} // {1}{R}", typeLine: "Creature — Giant // Instant — Adventure") == 3)
    }

    @Test func groupsByFrontFaceAndMatchesBasicLandsExactly() {
        #expect(getCardCategory(typeLine: "Battle — Siege // Creature — Phyrexian Dinosaur", cardName: "Invasion of Ikoria") == .battles)
        #expect(getCardCategory(typeLine: "Land // Legendary Creature — Demon", cardName: "Westvale Abbey") == .lands)
        #expect(getCardCategory(typeLine: "Instant // Land", cardName: "Valakut Awakening") == .instants)
        #expect(getCardCategory(typeLine: "Artifact Creature — Golem", cardName: "Solemn Simulacrum") == .creatures)
        #expect(isBasicLand(typeLine: "Land — Forest Island", cardName: "Tropical Island") == false)
        #expect(isBasicLand(typeLine: nil, cardName: "Mountain Goat") == false)
        #expect(isBasicLand(typeLine: nil, cardName: "Montañas") == true)
        #expect(isBasicLand(typeLine: "Basic Snow Land — Forest", cardName: "Snow-Covered Forest") == true)
    }
}
