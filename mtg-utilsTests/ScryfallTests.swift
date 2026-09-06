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