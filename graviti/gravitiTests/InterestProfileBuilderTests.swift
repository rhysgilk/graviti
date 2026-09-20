import XCTest
@testable import graviti

final class InterestProfileBuilderTests: XCTestCase {
    func testProfileCountsUniquePlacesAndAreasWithoutDoubleCountingArtifactTags() throws {
        let providence = place("pvd", locality: "Providence", country: "United States")
        let tokyo = place("tokyo", locality: "Tokyo", country: "Japan")
        let artifacts = [
            artifact(["Tea", "Tea", "Gardens"], at: providence),
            artifact(["Tea"], at: providence),
            artifact(["Tea", "Architecture"], at: tokyo)
        ]

        let profile = InterestProfileBuilder.build(from: artifacts)
        let tea = try XCTUnwrap(profile.interests.first { $0.name == "Tea" })

        XCTAssertEqual(tea.saveCount, 3)
        XCTAssertEqual(tea.placeCount, 2)
        XCTAssertEqual(tea.areaCount, 2)
        XCTAssertEqual(profile.strongestAcrossAreas?.name, "Tea")
    }

    func testProfilePrefersGeographicSpreadBeforeRawSaveCount() {
        let artifacts = [
            artifact(["Coffee"], at: place("one", locality: "Boston", country: "United States")),
            artifact(["Coffee"], at: place("one", locality: "Boston", country: "United States")),
            artifact(["Coffee"], at: place("one", locality: "Boston", country: "United States")),
            artifact(["Tea"], at: place("two", locality: "Kyoto", country: "Japan")),
            artifact(["Tea"], at: place("three", locality: "Taipei", country: "Taiwan"))
        ]

        XCTAssertEqual(InterestProfileBuilder.build(from: artifacts).interests.first?.name, "Tea")
    }

    private func artifact(_ interests: [String], at place: SavedPlace) -> Artifact {
        Artifact(
            kind: .manual,
            originalText: interests.joined(separator: " "),
            place: place,
            userDetails: ArtifactUserDetails(summary: nil, category: .other, interests: interests),
            processingState: .processed
        )
    }

    private func place(_ id: String, locality: String, country: String) -> SavedPlace {
        SavedPlace(id: id, name: id, latitude: 0, longitude: 0, locality: locality, region: nil, country: country)
    }
}
