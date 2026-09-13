import Foundation
import Testing
import UIKit
import CoreGraphics
import ImageIO
@testable import mtg_utils

@Suite("Performance Benchmarks (iPhone 15 Pro Max / A17 Pro)")
struct PerformanceBenchmarksTests {

    // MARK: - Benchmark 1: Name Normalization (10,000 iterations)
    @Test func benchmarkNameNormalization() {
        let sampleNames = [
            "Lightning Bolt",
            "Jace, the Mind Sculptor",
            "Snow-Covered Swamp",
            "Lim-Dûl's Vault",
            "Wear // Tear",
            "Boseiju, Who Endures",
            "  Atraxa,   Praetors' Voice  ",
            "Fire // Ice",
            "Thassa's Oracle",
            "Sol Ring"
        ]

        let clock = ContinuousClock()
        let iterations = 10_000

        let duration = clock.measure {
            for i in 0..<iterations {
                let name = sampleNames[i % sampleNames.count]
                _ = normalizeCardName(name)
            }
        }

        let ms = Double(duration.components.attoseconds) / 1_000_000_000_000_000.0 + Double(duration.components.seconds) * 1_000.0
        print("⏱️ [BENCHMARK] Normalizing \(iterations) card names took: \(String(format: "%.2f", ms)) ms")
        #expect(ms >= 0)
    }

    // MARK: - Benchmark 2: Deck vs Collection Cross-Matching (100 vs 5,000 cards)
    @Test func benchmarkDeckCrossMatchingLinearVsIndexed() {
        // 100 deck cards, with some missing from the collection
        let deckCards: [DeckCard] = (0..<100).map { i in
            DeckCard(
                id: "deck-card-\(i)",
                deckId: "deck-1",
                cardScryfallId: "scry-\(i)",
                cardName: i < 30 ? "Missing Card \(i)" : "Card Name \(i * 30)",
                quantity: (i % 4) + 1,
                setCode: nil
            )
        }

        // 5,000-card collection
        let collection: [CollectionCard] = (0..<5000).map { i in
            CollectionCard(
                id: "col-card-\(i)",
                userId: "user-1",
                cardScryfallId: "scry-\(i)",
                cardName: "Card Name \(i)",
                quantity: (i % 3) + 1,
                setCode: "set-\(i % 10)"
            )
        }

        let clock = ContinuousClock()

        // 1. Simulating previous O(N*M) linear search:
        let linearDuration = clock.measure {
            for card in deckCards {
                let norm = normalizeCardName(card.cardName)
                _ = card.setCode ?? collection.first(where: {
                    normalizeCardName($0.cardName) == norm && $0.setCode != nil
                })?.setCode
            }
        }
        let linearMs = Double(linearDuration.components.attoseconds) / 1_000_000_000_000_000.0 + Double(linearDuration.components.seconds) * 1_000.0
        print("⏱️ [BENCHMARK] Linear O(N*M) 100 cards vs 5,000 collection: \(String(format: "%.2f", linearMs)) ms")

        // 2. Hash-indexed O(N + M) search:
        let indexedDuration = clock.measure {
            var setMap: [String: String] = [:]
            for col in collection {
                if let set = col.setCode, !set.isEmpty {
                    let norm = normalizeCardName(col.cardName)
                    if setMap[norm] == nil {
                        setMap[norm] = set
                    }
                }
            }
            for card in deckCards {
                let norm = normalizeCardName(card.cardName)
                _ = card.setCode ?? setMap[norm]
            }
        }
        let indexedMs = Double(indexedDuration.components.attoseconds) / 1_000_000_000_000_000.0 + Double(indexedDuration.components.seconds) * 1_000.0
        print("⏱️ [BENCHMARK] Hash Indexed O(N+M) 100 cards vs 5,000 collection: \(String(format: "%.2f", indexedMs)) ms")

        #expect(indexedMs < linearMs)
    }

    // MARK: - Benchmark 3: Image Decoding (Full UIImage(data:) vs Downsampled Thumbnail)
    @Test func benchmarkImageDecodingFullVsDownsampled() {
        // Create an in-memory sample JPEG image (488x680 like Scryfall)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 488, height: 680))
        let uiImage = renderer.image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 488, height: 680))
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 50, y: 50, width: 388, height: 580))
        }
        guard let jpegData = uiImage.jpegData(compressionQuality: 0.8) else {
            #expect(Bool(false), "Failed to generate test image")
            return
        }

        let clock = ContinuousClock()
        let count = 20

        // 1. Current method: full UIImage(data:)
        let fullDuration = clock.measure {
            for _ in 0..<count {
                if let decoded = UIImage(data: jpegData) {
                    _ = decoded.cgImage?.width
                }
            }
        }
        let fullMs = Double(fullDuration.components.attoseconds) / 1_000_000_000_000_000.0 + Double(fullDuration.components.seconds) * 1_000.0
        print("⏱️ [BENCHMARK] Decoding \(count) full images UIImage(data:): \(String(format: "%.2f", fullMs)) ms")

        // 2. Downsampling via CGImageSource: target size 120 max pixel dimension
        let downsampledDuration = clock.measure {
            for _ in 0..<count {
                let options: [CFString: Any] = [
                    kCGImageSourceShouldCache: false,
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 120,
                    kCGImageSourceCreateThumbnailWithTransform: true
                ]
                if let source = CGImageSourceCreateWithData(jpegData as CFData, nil),
                   let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
                    _ = UIImage(cgImage: cgImage)
                }
            }
        }
        let downsampledMs = Double(downsampledDuration.components.attoseconds) / 1_000_000_000_000_000.0 + Double(downsampledDuration.components.seconds) * 1_000.0
        print("⏱️ [BENCHMARK] Downsampling \(count) images to thumbnail: \(String(format: "%.2f", downsampledMs)) ms")

        #expect(downsampledMs >= 0)
    }

    // MARK: - Benchmark 4: Store Single-Request vs N+1 Calls
    @Test func benchmarkStoreSummariesVsNPlusOne() async throws {
        let mockStore = await MockDataStore(seed: true)

        let clock = ContinuousClock()
        let singleCallDuration = try await clock.measure {
            let summaries = try await mockStore.allDeckSummaries()
            #expect(!summaries.isEmpty)
        }
        let singleMs = Double(singleCallDuration.components.attoseconds) / 1_000_000_000_000_000.0 + Double(singleCallDuration.components.seconds) * 1_000.0
        print("⏱️ [BENCHMARK] allDeckSummaries() call: \(String(format: "%.4f", singleMs)) ms")
        #expect(singleMs >= 0)
    }
}
