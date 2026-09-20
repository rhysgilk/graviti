import XCTest
@testable import graviti

final class LibrarySearchEngineTests: XCTestCase {
    func testSearchFindsCachedLinkTextInterestsDestinationsAndPlaces() {
        let place = SavedPlace(
            id: "burlington", name: "Green Mountain Trail", latitude: 44.48, longitude: -73.21,
            locality: "Burlington", region: "Vermont", country: "United States"
        )
        let artifact = Artifact(
            kind: .url,
            sourceURL: "https://example.com/trail",
            linkMetadata: ArtifactLinkMetadata(
                title: "Quiet forest walks",
                summary: "A mossy woodland trail near Burlington.",
                siteName: "Trail Notes",
                imageData: nil,
                resolvedURL: "https://example.com/trail",
                fetchedAt: .now
            ),
            linkMetadataState: .processed,
            place: place,
            enrichment: ArtifactEnrichment(
                summary: "A forest hiking trail.", category: .sceneryAndNature, interests: ["Forests", "Hiking"],
                source: .linkMetadata, confidence: 0.55, generatedAt: .now
            ),
            enrichmentState: .processed,
            processingState: .processed
        )

        let forest = LibrarySearchEngine.search("forest", in: [artifact])
        XCTAssertEqual(forest.artifacts.map(\.id), [artifact.id])
        XCTAssertEqual(forest.interests.map(\.name), ["Forests"])

        let spanishForest = LibrarySearchEngine.search(
            "bosques",
            in: [artifact],
            locale: Locale(identifier: "es")
        )
        XCTAssertEqual(spanishForest.artifacts.map(\.id), [artifact.id])
        XCTAssertEqual(spanishForest.interests.map(\.name), ["Forests"])

        let burlington = LibrarySearchEngine.search("Burlington", in: [artifact])
        XCTAssertEqual(burlington.destinations.map(\.name), ["Burlington"])
        XCTAssertEqual(burlington.places.map(\.id), [place.id])
    }

    func testSearchIncludesOCRAndDeduplicatesRepeatedPlace() {
        let place = SavedPlace(
            id: "kyoto", name: "Kiyomizu-dera", latitude: 34.99, longitude: 135.78,
            locality: "Kyoto", region: nil, country: "Japan"
        )
        let first = Artifact(
            kind: .photo,
            mediaKey: "one.png",
            extractedText: "Historic temple architecture",
            extractedTextSource: .appleVision,
            textExtractionState: .processed,
            place: place,
            processingState: .processed
        )
        let second = Artifact(kind: .manual, originalText: "Kyoto architecture", place: place, processingState: .processed)

        let results = LibrarySearchEngine.search("architecture", in: [first, second])

        XCTAssertEqual(results.artifacts.count, 2)
        XCTAssertEqual(results.places.count, 0)
        XCTAssertEqual(LibrarySearchEngine.search("Kiyomizu", in: [first, second]).places.count, 1)
    }
}
