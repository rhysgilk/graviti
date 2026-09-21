import XCTest
@testable import graviti

final class DestinationKnowledgeCatalogTests: XCTestCase {
    func testRejectsUnsupportedSchema() throws {
        let data = try encodedCatalog(schemaVersion: 2)

        XCTAssertThrowsError(try DestinationKnowledgeCatalogLoader.decode(data)) { error in
            XCTAssertEqual(error as? DestinationKnowledgeCatalogError, .unsupportedSchemaVersion(2))
        }
    }

    func testRejectsDuplicateDestinationsIgnoringCase() throws {
        let data = try encodedCatalog(destinationCount: 2)

        XCTAssertThrowsError(try DestinationKnowledgeCatalogLoader.decode(data)) { error in
            XCTAssertEqual(error as? DestinationKnowledgeCatalogError, .duplicateDestination("Example, Test"))
        }
    }

    func testRejectsUnreviewedAndInsecureKnowledge() throws {
        let missingSources = try encodedCatalog(includeSource: false)
        XCTAssertThrowsError(try DestinationKnowledgeCatalogLoader.decode(missingSources)) { error in
            XCTAssertEqual(error as? DestinationKnowledgeCatalogError, .missingSources("Example, Test"))
        }

        let insecureSource = try encodedCatalog(sourceURL: "http://example.com")
        XCTAssertThrowsError(try DestinationKnowledgeCatalogLoader.decode(insecureSource)) { error in
            XCTAssertEqual(error as? DestinationKnowledgeCatalogError, .insecureSource("Example, Test"))
        }
    }

    private func encodedCatalog(
        schemaVersion: Int = 1,
        destinationCount: Int = 1,
        includeSource: Bool = true,
        sourceURL: String = "https://example.com"
    ) throws -> Data {
        let source: [[String: String]] = includeSource ? [[
            "title": "Reviewed source",
            "url": sourceURL,
            "reviewedAt": "2026-09-20"
        ]] : []
        let destination: [String: Any] = [
            "name": "Example",
            "country": "Test",
            "region": "anywhere",
            "searchSpan": 1,
            "dataConfidence": 0.8,
            "strengths": ["Museums": 1],
            "sources": source
        ]
        return try JSONSerialization.data(withJSONObject: [
            "schemaVersion": schemaVersion,
            "catalogVersion": "test",
            "reviewedAt": "2026-09-20",
            "destinations": Array(repeating: destination, count: destinationCount)
        ])
    }
}
