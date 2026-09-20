import XCTest
@testable import graviti

@MainActor
final class FitGuideSearchEngineTests: XCTestCase {
    func testBuildsOneRegionScopedSearchPerInterest() async throws {
        let guide = FitGuide(
            destination: SavedDestination(name: "New York City", country: "United States"),
            interests: ["Museums", "Coffee", "Matcha"]
        )
        let provider = RecordingFitGuideProvider(responses: [
            "museum|\(guide.destination.id)": [candidate("museum", name: "Museum")],
            "coffee shop|\(guide.destination.id)": [candidate("coffee", name: "Coffee")],
            "matcha cafe|\(guide.destination.id)": [candidate("matcha", name: "Matcha")]
        ])

        _ = try await FitGuideSearchEngine.search(guide: guide, using: provider)

        XCTAssertEqual(provider.queries, [
            "museum",
            "coffee shop",
            "matcha cafe"
        ])
        XCTAssertEqual(provider.destinations, Array(repeating: guide.destination, count: 3))
    }

    func testGroupsByPatternAndDeduplicatesPlacesAcrossSections() async throws {
        let shared = candidate("shared", name: "Museum Café")
        let museum = candidate("museum", name: "City Museum")
        let coffee = candidate("coffee", name: "Good Coffee")
        let provider = RecordingFitGuideProvider(responses: [
            "museum|New York City, United States": [shared, museum],
            "coffee shop|New York City, United States": [shared, coffee]
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

    func testRetriesWithBroaderTermWhenRegionalCategoryIsEmpty() async throws {
        let landmark = candidate("landmark", name: "Historic Palace")
        let provider = RecordingFitGuideProvider(responses: [
            "historic landmark|Mexico City, Mexico": [landmark]
        ])
        let guide = FitGuide(
            destination: SavedDestination(name: "Mexico City", country: "Mexico"),
            interests: ["Architecture"]
        )

        let sections = try await FitGuideSearchEngine.search(guide: guide, using: provider)

        XCTAssertEqual(provider.queries, ["architectural landmark", "historic landmark"])
        XCTAssertEqual(sections.first?.places, [landmark])
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
    private(set) var destinations = [SavedDestination]()

    init(responses: [String: [PlaceCandidate]]) {
        self.responses = responses
    }

    func search(_ query: String) async throws -> [PlaceCandidate] {
        queries.append(query)
        return responses[query] ?? []
    }

    func search(_ query: String, near destination: SavedDestination) async throws -> [PlaceCandidate] {
        queries.append(query)
        destinations.append(destination)
        return responses["\(query)|\(destination.id)"] ?? []
    }
}
