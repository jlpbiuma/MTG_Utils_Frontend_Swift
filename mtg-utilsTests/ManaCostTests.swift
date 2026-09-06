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