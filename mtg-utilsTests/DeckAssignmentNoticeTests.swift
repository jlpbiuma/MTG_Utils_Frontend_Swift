import Foundation
import Testing
@testable import mtg_utils

private final class NoticeStore: AppDataStoring {
    var notices = [
        DeckAssignmentNotice(id: "one", deckId: "a", cardName: "Sol Ring", deckName: "A", quantity: 1),
        DeckAssignmentNotice(id: "two", deckId: "b", cardName: "Island", deckName: "B", quantity: 2)
    ]
    var failsAcceptance = false
    func pendingDeckAssignmentNotices() async throws -> [DeckAssignmentNotice] { notices }
    func acceptDeckAssignmentNotice(id: String) async throws {
        if failsAcceptance { throw URLError(.notConnectedToInternet) }
        notices.removeAll { $0.id == id }
    }
    func allDecks() async throws -> [Deck] { [] }
    func allDeckSummaries() async throws -> [DeckSummary] { [] }
    func deckDetail(id: String) async throws -> DeckDetail? { nil }
    func saveDecks(_ decks: [Deck]) async throws {}
    func allCollection() async throws -> [CollectionCard] { [] }
    func saveCollection(_ cards: [CollectionCard]) async throws {}
}

@Suite("Deck assignment notices")
@MainActor
struct DeckAssignmentNoticeTests {
    @Test func acceptancePersistsAndKeepsOtherNotices() async {
        let store = NoticeStore()
        let model = DecksListViewModel(store: store, userId: "alice")
        await model.load()
        #expect(model.assignmentNotices.count == 2)
        await model.acceptNotice(model.assignmentNotices[0])
        #expect(model.assignmentNotices.map(\.id) == ["two"])
        await model.load()
        #expect(model.assignmentNotices.map(\.id) == ["two"])
        #expect(model.acceptingNoticeIds.isEmpty)
    }

    @Test func failedAcceptanceRetainsNoticeForRetry() async {
        let store = NoticeStore()
        store.failsAcceptance = true
        let model = DecksListViewModel(store: store, userId: "alice")
        await model.load()
        await model.acceptNotice(model.assignmentNotices[0])
        #expect(model.assignmentNotices.count == 2)
        #expect(model.errorMessage != nil)
        #expect(model.acceptingNoticeIds.isEmpty)
        store.failsAcceptance = false
        await model.acceptNotice(model.assignmentNotices[0])
        #expect(model.assignmentNotices.count == 1)
        #expect(model.errorMessage == nil)
    }
}
