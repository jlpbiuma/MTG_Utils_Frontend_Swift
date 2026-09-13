import Foundation
import Testing
@testable import mtg_utils

// Port of frontend/tests/unit/scryfall.test.ts. Network reads are replaced
// with a URLProtocol-driven URLSession so no remote calls are made.
// The suite is serialized because the three wire-serving tests share the
// static MockURLProtocol handler and would otherwise race under parallelization.

@Suite("Scryfall Client", .serialized)
struct ScryfallTests {

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    @Test func returnsEmptyForBlankQueryWithoutHittingNetwork() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.badServerResponse)
        }

        let client = ScryfallClient(session: makeSession())
        let result = try await client.search(query: "   ")

        #expect(result.totalCards == 0)
        #expect(result.data.isEmpty)
        #expect(MockURLProtocol.requestCount == 0)
    }

    @Test func searchesAndParsesResults() async throws {
        let json = """
        {
          "data": [
            {
              "id": "card-uuid-1",
              "name": "Black Lotus",
              "mana_cost": "{0}",
              "type_line": "Artifact"
            }
          ],
          "has_more": false,
          "total_cards": 1
        }
        """.data(using: .utf8)!

        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.query?.contains("q=Black%20Lotus") == true)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json)
        }

        let client = ScryfallClient(session: makeSession())
        let result = try await client.search(query: "Black Lotus")

        #expect(result.totalCards == 1)
        #expect(result.data.count == 1)
        #expect(result.data[0].name == "Black Lotus")
        #expect(result.data[0].displayManaCost == "{0}")
        #expect(result.hasMore == false)
        #expect(MockURLProtocol.requestCount == 1)
    }

    @Test func usesTheSmallDerivativeForThumbnailsAndNormalAsFallback() throws {
        let withSmall = """
        {"id":"one","name":"One","image_uris":{"small":"http://localhost:8080/images/small.webp","normal":"http://localhost:8080/images/normal.webp","large":"http://localhost:8080/images/large.webp"}}
        """.data(using: .utf8)!
        let normalOnly = """
        {"id":"two","name":"Two","image_uris":{"normal":"http://localhost:8080/images/normal.webp"}}
        """.data(using: .utf8)!

        let first = try JSONDecoder().decode(ScryfallCard.self, from: withSmall)
        let second = try JSONDecoder().decode(ScryfallCard.self, from: normalOnly)

        #expect(first.displayImageSmallUri?.contains("small.webp") == true)
        #expect(first.displayImageUri?.contains("normal.webp") == true)
        #expect(second.displayImageSmallUrl == second.displayImageUrl)
    }

    @Test func decodesCompleteBackendDetailsWithNumericPricesAndArtVariants() throws {
        let json = """
        {
          "id":"card-1","name":"Wall of Nets","name_es":"Muro de redes",
          "mana_cost":"{1}{W}{W}","type_line":"Creature — Wall",
          "type_line_es":"Criatura — Muro","oracle_text_es":"Defensor",
          "power":"0","toughness":"7","rarity":"rare","rarity_es":"Rara",
          "set":"exo","set_name":"Exodus","has_spanish_print":true,
          "image_uris":{"normal":"http://localhost:8080/images/normal.webp","large":"http://localhost:8080/images/large.webp"},
          "prices":{"eur":1.68,"eur_foil":"2.50","usd":5.78,"usd_foil":null},
          "printings":[{
            "id":"card-1","set_code":"exo","set_name":"Exodus","collector_number":"24",
            "name_es":"Muro de redes","rarity":"rare",
            "image_uri":"http://localhost:8080/images/normal.webp",
            "image_uri_small":"http://localhost:8080/images/small.webp",
            "image_uri_large":"http://localhost:8080/images/large.webp",
            "trend":1.68,"min":1.20,"max":2.10,"cardtrader_trend":1.65,
            "price_usd":5.78,"released_at":"1998-06-15T00:00:00+00:00"
          }],
          "rulings":[{"date":"2004-10-04","text":"A ruling.","source":"wotc"}]
        }
        """.data(using: .utf8)!

        let details = try JSONDecoder().decode(SpanishCardDetails.self, from: json)

        #expect(details.prices?.eur == 1.68)
        #expect(details.prices?.eurFoil == 2.50)
        #expect(details.power == "0")
        #expect(details.toughness == "7")
        #expect(details.largeImageUri?.contains("large.webp") == true)
        #expect(details.printings?.first?.imageUriSmall?.contains("small.webp") == true)
        #expect(details.rulings?.first?.text == "A ruling.")
    }

    @Test func handles404ByReturningEmptyList() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let client = ScryfallClient(session: makeSession())
        let result = try await client.search(query: "NonExistentCardXYZ12345")

        #expect(result.totalCards == 0)
        #expect(result.data.isEmpty)
    }

    @Test func autocompletesCardNames() async throws {
        let json = #"{"data": ["Lightning Bolt", "Lightning Helix", "Lightning Strike"]}"#.data(using: .utf8)!

        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json)
        }

        let client = ScryfallClient(session: makeSession())
        let names = try await client.autocomplete("Light")

        #expect(names.count == 3)
        #expect(names.contains("Lightning Bolt"))
    }

    @Test func autocompleteReturnsEmptyForBlankPrefix() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.badServerResponse)
        }

        let client = ScryfallClient(session: makeSession())
        let names = try await client.autocomplete("  ")

        #expect(names.isEmpty)
        #expect(MockURLProtocol.requestCount == 0)
    }
}

// MARK: - URLProtocol harness

/// URLProtocol mock adopting default-actor-isolation opt-out so URLSession can
/// drive it on its internal queues without a MainActor hop.
nonisolated final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) private static var _requestCount = 0

    static var requestCount: Int { _requestCount }

    static func reset() {
        _requestCount = 0
        requestHandler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            Self._requestCount += 1
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
