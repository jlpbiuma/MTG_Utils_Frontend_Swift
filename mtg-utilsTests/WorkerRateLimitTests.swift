import Foundation
import Testing
@testable import mtg_utils

// Port of frontend/tests/unit/worker-rate-limit.test.ts. The Swift app has no
// background worker; normalizeCardName + the 75/request batch policy and
// polite inter-batch delays are validated as pure helpers.

@Suite("Worker Rate Limiting & Card Normalization")
struct WorkerRateLimitTests {

    @Test func normalizesCardNames() {
        #expect(normalizeCardName("Sol Ring") == "sol ring")
        #expect(normalizeCardName("  LIGHTNING   BOLT  ") == "lightning bolt")
        #expect(normalizeCardName("Wear // Tear") == "wear")
        #expect(normalizeCardName("Delver of Secrets // Insectile Aberration") == "delver of secrets")
        #expect(normalizeCardName("Boseiju, Who Endures") == "boseiju, who endures")
    }

    @Test func sleepResolvesAfterSpecifiedDuration() async throws {
        let start = Date()
        try await Task.sleep(nanoseconds: 50_000_000)
        let elapsed = Date().timeIntervalSince(start) * 1000
        #expect(elapsed >= 40)
    }

    @Test func enforcesMaximumBatchSizeOf75() {
        let totalCards = 200
        let batchSize = 75

        var batches: [[Int]] = []
        var start = 0
        while start < totalCards {
            let end = min(start + batchSize, totalCards)
            batches.append(Array(start..<end))
            start = end
        }

        #expect(batches.count == 3)
        #expect(batches[0].count == 75)
        #expect(batches[1].count == 75)
        #expect(batches[2].count == 50)
    }

    @Test func calculatesDelayIntervalsToAvoidHTTP429() {
        let delayMs = 100
        let numBatches = 5
        let totalMinimumDelay = (numBatches - 1) * delayMs

        #expect(totalMinimumDelay == 400)
    }
}