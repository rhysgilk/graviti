import XCTest
@testable import graviti

@MainActor
final class FitGuideSearchEngineTests: XCTestCase {
    func testBuildsOneDestinationScopedQueryPerInterest() async throws {
        let provider = RecordingFitGuideProvider(responses: [:])
        let guide = FitGuide(
            destination: SavedDestination(name: "New York City", country: "United States"),
            interests: ["Museums", "Coffee", "Matcha"]
        )

        _ = try await FitGuideSearchEngine.search(guide: guide, using: provider)

        XCTAssertEqual(provider.queries, [
            "Museums in New York City, United States",
            "Coffee in New York City, United States",
            "Matcha in New York City, United States"
        ])
    }

    func testGroupsByPatternAndDeduplicatesPlacesAcrossSections() async throws {
        let shared = candidate("shared", name: "Museum Café")
        let museum = candidate("museum", name: "City Museum")
        let coffee = candidate("coffee", name: "Good Coffee")
        let provider = RecordingFitGuideProvider(responses: [
            "Museums in New York City, United States": [shared, museum],
            "Coffee in New York City, United States": [shared, coffee]
        ])
        let guide = FitGuide(
            destination: SavedDestination(name: "New York City", country: "United States"),
            interests: ["Museums", "Coffee"]
        )

        let sections = try await FitGuideSearchEngine.search(guide: guide, using: provider)

        XCTAssertEqual(sections.map(\.interest), ["Museums", "Coffee"])
        XCTAssertEqual(sections[0].places.map(\.id), ["shared", "museum"])
        XCTAssertEqual(sections[1].places.map(\.id), ["coffee"])
    }

    private func candidate(_ id: String, name: String) -> PlaceCandidate {
        PlaceCandidate(
            place: SavedPlace(
                id: id,
                name: name,
                latitude: 40.7,
                longitude: -74,
                locality: "New York",
                region: "New York",
                country: "United States"
            ),
            sourceURL: "https://maps.apple.com/?q=\(id)"
        )
    }
}

@MainActor
private final class RecordingFitGuideProvider: PlaceSearchProviding {
    let responses: [String: [PlaceCandidate]]
    private(set) var queries = [String]()

    init(responses: [String: [PlaceCandidate]]) {
        self.responses = responses
    }

    func search(_ query: String) async throws -> [PlaceCandidate] {
        queries.append(query)
        return responses[query] ?? []
    }
}
