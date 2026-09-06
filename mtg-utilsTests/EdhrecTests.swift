import Foundation
import Testing
@testable import mtg_utils

// Port of frontend/tests/unit/edhrec.test.ts (slug, card image URL, pure
// name matching, inclusion percentage).

@Suite("EDHREC Integration & Recommendation Logic")
struct EdhrecTests {

    @Test func convertsSimpleCommanderNamesToSlugs() {
        #expect(toEdhrecSlug("Aragorn, the Uniter") == "aragorn-the-uniter")
        #expect(toEdhrecSlug("Niv-Mizzet, Parun") == "niv-mizzet-parun")
        #expect(toEdhrecSlug("Urza, Lord High Artificer") == "urza-lord-high-artificer")
    }

    @Test func handlesDiacriticsAndAccents() {
        #expect(toEdhrecSlug("Lim-Dûl's Vault") == "lim-duls-vault")
        #expect(toEdhrecSlug("Séance") == "seance")
        #expect(toEdhrecSlug("Borborygmos Enragé") == "borborygmos-enrage")
    }

    @Test func handlesPunctuation() {
        #expect(toEdhrecSlug("Atraxa, Praetors' Voice") == "atraxa-praetors-voice")
        #expect(toEdhrecSlug("Kongming, \"Sleeping Dragon\"") == "kongming-sleeping-dragon")
    }

    @Test func joinsPartnerAndSplitSlashFaces() {
        #expect(toEdhrecSlug("Kraum, Ludevic's Opus // Tymna the Weaver") ==
            "kraum-ludevics-opus-tymna-the-weaver")
    }

    @Test func handlesEmptyInputsGracefully() {
        #expect(toEdhrecSlug("") == "")
        #expect(toEdhrecSlug("   ") == "")
    }

    @Test func constructsEdhrecCdnImageUrls() {
        let id = "c05c2aa6-29c7-40f8-872e-91099b9225c4"
        #expect(edhrecCardImageUrl(forScryfallId: id) ==
            "https://card-images.edhrec.com/normal/front/c/0/c05c2aa6-29c7-40f8-872e-91099b9225c4.jpg")
    }

    @Test func returnsNilForInvalidOrEmptyUuids() {
        #expect(edhrecCardImageUrl(forScryfallId: "") == nil)
        #expect(edhrecCardImageUrl(forScryfallId: "a") == nil)
        #expect(edhrecCardImageUrl(forScryfallId: "not-a-uuid") == nil)
    }

    @Test func matchesCardsAcrossSourcesRegardlessOfCaseAndSplitFaces() {
        let edhrecName = "Birds of Paradise"
        let collectionName = "birds of paradise"
        let deckName = "Birds of Paradise // Front"

        let normEdhrec = normalizeCardName(edhrecName)
        let normCollection = normalizeCardName(collectionName)
        let normDeck = normalizeCardName(deckName)

        #expect(normEdhrec == "birds of paradise")
        #expect(normCollection == "birds of paradise")
        #expect(normDeck == "birds of paradise")
        #expect(normEdhrec == normCollection)
        #expect(normEdhrec == normDeck)
    }

    @Test func matchesIgnoringWhitespaceAndCase() {
        let edhrecName = "  Sol   Ring  "
        let collectionName = "Sol Ring"
        #expect(normalizeCardName(edhrecName) == normalizeCardName(collectionName))
    }

    @Test func calculatesCommunityInclusionPercentage() {
        let numDecks = 1530.0
        let potentialDecks = 2000.0
        let inclusionPct = ((numDecks / potentialDecks * 100) * 10).rounded() / 10
        #expect(inclusionPct == 76.5)
    }

    @Test func handlesEdgeCasesForInclusion() {
        let numDecks = 0.0
        let potentialDecks = 0.0
        let inclusionPct = potentialDecks > 0 ? (numDecks / potentialDecks) * 100 : 0
        #expect(inclusionPct == 0)
    }
}