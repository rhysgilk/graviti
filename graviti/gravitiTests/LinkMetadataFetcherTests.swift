import XCTest
@testable import graviti

final class LinkMetadataFetcherTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchesAndNormalizesOpenGraphMetadataAndImage() async throws {
        let html = """
        <html><head>
        <meta property="og:title" content="Kyoto &amp; Tea">
        <meta name="description" content="  Ceremonial   matcha and gardens. ">
        <meta property="og:site_name" content="Travel Notes">
        <meta property="og:image" content="/preview.jpg">
        </head></html>
        """
        MockURLProtocol.handler = { request in
            if request.url?.path == "/preview.jpg" {
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "image/jpeg"])!, Data([0xFF, 0xD8, 0xFF]))
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "text/html; charset=utf-8"])!, Data(html.utf8))
        }

        let metadata = try await LinkMetadataFetcher(session: session()).fetch("https://example.com/story")

        XCTAssertEqual(metadata?.title, "Kyoto & Tea")
        XCTAssertEqual(metadata?.summary, "Ceremonial matcha and gardens.")
        XCTAssertEqual(metadata?.siteName, "Travel Notes")
        XCTAssertEqual(metadata?.imageData, Data([0xFF, 0xD8, 0xFF]))
        XCTAssertEqual(metadata?.resolvedURL, "https://example.com/story")
    }

    func testRejectsPrivateNetworkTargetsWithoutStartingARequest() async {
        MockURLProtocol.handler = { _ in XCTFail("Unsafe URL should not be requested"); throw URLError(.badURL) }
        for url in [
            "http://localhost/private",
            "http://127.0.0.1/private",
            "http://10.0.0.4/private",
            "http://172.20.0.4/private",
            "http://192.168.1.4/private",
            "http://[::1]/private"
        ] {
            do {
                _ = try await LinkMetadataFetcher(session: session()).fetch(url)
                XCTFail("Expected unsafe URL rejection for \(url)")
            } catch {
                XCTAssertNotNil(error)
            }
        }
    }

    func testInstagramMetadataUsesCaptionWithoutPlatformBoilerplate() async throws {
        let html = """
        <html><head>
        <meta property="og:title" content="Alyssa | Boston Foodie on Instagram: &quot;Hottest new sandwich spot in Boston 👀&#10;&#10;What we ordered: The South End, The Calabria, Roman Gold&#10;&#10;📍South End — @calistosdeli&#10;682 Tremont St Boston, MA 02118&quot;">
        <meta property="og:description" content="1,287 likes, 46 comments - bottomlyssbites on August 18, 2026: &quot;Hottest new sandwich spot in Boston 👀&#10;&#10;The Roman Gold has a crispy chicken cutlet, and the South End has turkey, whipped Brie and fig jam.&#10;&#10;What we ordered: The South End, The Calabria, Roman Gold&#10;&#10;📍South End — @calistosdeli&#10;682 Tremont St Boston, MA 02118&#10;&#10;#bostonfood #sandwiches Boston recs&quot;. ">
        <meta property="og:site_name" content="Instagram">
        </head></html>
        """
        MockURLProtocol.handler = { request in
            (HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/html; charset=utf-8"]
            )!, Data(html.utf8))
        }

        let metadata = try await LinkMetadataFetcher(session: session()).fetch(
            "https://www.instagram.com/reel/DcMn8LBpcM0/"
        )

        XCTAssertEqual(metadata?.title, "Hottest new sandwich spot in Boston 👀")
        XCTAssertTrue(metadata?.summary?.contains("Roman Gold") == true)
        XCTAssertTrue(metadata?.summary?.contains("682 Tremont St Boston, MA 02118") == true)
        XCTAssertFalse(metadata?.summary?.contains("likes, 46 comments") == true)
        XCTAssertFalse(metadata?.summary?.contains("#bostonfood") == true)
        XCTAssertEqual(metadata?.siteName, "Instagram")
    }

    private func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

@MainActor
final class LinkMetadataEnrichmentPipelineTests: XCTestCase {
    func testInterruptedMetadataEnrichmentResumesToCompletion() async throws {
        let repository = PreviewArtifactRepository()
        let artifact = Artifact(
            kind: .url,
            sourceURL: "https://example.com/hike",
            linkMetadata: ArtifactLinkMetadata(
                title: "Volcanic forest hike",
                summary: "A scenic trail through subtropical rain forest and mountain landscapes.",
                siteName: "Travel Notes",
                imageData: nil,
                resolvedURL: "https://example.com/hike",
                fetchedAt: .now
            ),
            linkMetadataState: .processed,
            enrichmentState: .processing
        )
        try await repository.save(artifact)
        let library = ArtifactLibrary(repository: repository)
        await library.load()

        await library.processPendingEnrichment()

        let updated = try XCTUnwrap(library.artifacts.first)
        XCTAssertEqual(updated.enrichmentState, .processed)
        XCTAssertEqual(updated.enrichment?.category, .sceneryAndNature)
        XCTAssertEqual(updated.enrichment?.source, .linkMetadata)
        XCTAssertTrue(updated.enrichment?.interests.contains("Forests") == true)
        XCTAssertTrue(updated.enrichment?.interests.contains("Hiking") == true)
    }

    func testLinkCaptionBecomesDescriptionAndSemanticEvidence() async throws {
        let caption = "Calistos Deli in Boston serves crispy chicken cutlet sandwiches, whipped Brie, and fig jam at 682 Tremont St."
        let artifact = Artifact(
            kind: .url,
            sourceURL: "https://www.instagram.com/reel/example/",
            originalText: "Hottest new sandwich spot in Boston",
            linkMetadata: ArtifactLinkMetadata(
                title: "Hottest new sandwich spot in Boston",
                summary: caption,
                siteName: "Instagram",
                imageData: nil,
                resolvedURL: "https://www.instagram.com/reel/example/",
                fetchedAt: .now
            ),
            linkMetadataState: .processed
        )

        let result = try await ArtifactEnricher().enrich(artifact)

        XCTAssertEqual(result?.summary, caption)
        XCTAssertEqual(result?.category, .foodAndDrink)
        XCTAssertEqual(result?.source, .linkMetadata)
    }
}

private final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw URLError(.unknown) }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}
