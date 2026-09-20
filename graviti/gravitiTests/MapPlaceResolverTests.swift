import XCTest
@testable import graviti

@MainActor
final class MapPlaceResolverTests: XCTestCase {
    func testGoogleImportUsesAddressHintForSearch() async throws {
        let place = savedPlace(id: "tea", name: "Tea House", latitude: 40.7, longitude: -73.9)
        let provider = RecordingPlaceSearchProvider(results: [PlaceCandidate(place: place, sourceURL: "https://maps.apple.com")])
        let resolver = MapPlaceResolver(searchProvider: provider, linkExpander: IdentityMapLinkExpander())
        let artifact = Artifact(
            kind: .url,
            sourceURL: "https://www.google.com/maps/place/Tea%20House/data=!4m2?q=Tea%20House,%201%20Main%20St&ll=40.7,-73.9",
            originalText: "Tea House"
        )

        let resolution = try await resolver.resolve(artifact)

        guard case .matched(let matched) = resolution else {
            return XCTFail("Expected the exact place to match")
        }
        XCTAssertEqual(matched.id, "tea")
        XCTAssertEqual(provider.queries, ["Tea House, 1 Main St"])
    }

    func testCoordinateHintResolvesCompatibleRenamedPlace() async throws {
        let nearby = savedPlace(
            id: "nearby",
            name: "Aoko Matcha West Village",
            latitude: 40.7317,
            longitude: -74.0031
        )
        let unrelated = savedPlace(
            id: "other",
            name: "Aoko Matcha East Village",
            latitude: 40.7280,
            longitude: -73.9850
        )
        let provider = RecordingPlaceSearchProvider(results: [nearby, unrelated].map {
            PlaceCandidate(place: $0, sourceURL: "https://maps.apple.com")
        })
        let resolver = MapPlaceResolver(searchProvider: provider, linkExpander: IdentityMapLinkExpander())
        let artifact = Artifact(
            kind: .url,
            sourceURL: "https://www.google.com/maps/place/Aoko%20Matcha/data=!4m2?q=Aoko%20Matcha,%20275%20Bleecker%20St&ll=40.7316255,-74.0030701",
            originalText: "Aoko Matcha"
        )

        let resolution = try await resolver.resolve(artifact)

        guard case .matched(let matched) = resolution else {
            return XCTFail("Expected the nearby compatible place to match")
        }
        XCTAssertEqual(matched.id, "nearby")
    }

    func testCoordinateHintDoesNotSelectNearbyUnrelatedPlace() async throws {
        let place = savedPlace(id: "other", name: "Completely Different Cafe", latitude: 40.7001, longitude: -73.9001)
        let provider = RecordingPlaceSearchProvider(results: [PlaceCandidate(place: place, sourceURL: "https://maps.apple.com")])
        let resolver = MapPlaceResolver(searchProvider: provider, linkExpander: IdentityMapLinkExpander())
        let artifact = Artifact(
            kind: .url,
            sourceURL: "https://www.google.com/maps/place/Tea%20House/data=!4m2?q=Tea%20House,%201%20Main%20St&ll=40.7,-73.9",
            originalText: "Tea House"
        )

        let resolution = try await resolver.resolve(artifact)

        guard case .needsReview = resolution else {
            return XCTFail("Expected an unrelated candidate to need review")
        }
    }

    private func savedPlace(
        id: String,
        name: String,
        latitude: Double,
        longitude: Double
    ) -> SavedPlace {
        SavedPlace(
            id: id,
            name: name,
            latitude: latitude,
            longitude: longitude,
            locality: "New York",
            region: "New York",
            country: "United States"
        )
    }
}

@MainActor
private final class RecordingPlaceSearchProvider: PlaceSearchProviding {
    let results: [PlaceCandidate]
    private(set) var queries = [String]()

    init(results: [PlaceCandidate]) {
        self.results = results
    }

    func search(_ query: String) async throws -> [PlaceCandidate] {
        queries.append(query)
        return results
    }
}

@MainActor
private struct IdentityMapLinkExpander: MapLinkExpanding {
    func expandedURL(for rawURL: String) async -> String { rawURL }
}
