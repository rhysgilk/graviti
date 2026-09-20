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
