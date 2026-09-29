import XCTest
@testable import graviti

@MainActor
final class PlaceMapCategoryStyleTests: XCTestCase {
    func testUsesMostFrequentCategoryForAPlace() {
        let artifacts = [
            artifact(placeID: "venue", category: .foodAndDrink),
            artifact(placeID: "venue", category: .sceneryAndNature),
            artifact(placeID: "venue", category: .sceneryAndNature),
            artifact(placeID: "somewhere-else", category: .artsAndCulture)
        ]

        XCTAssertEqual(
            PlaceMapCategoryStyle.category(for: "venue", in: artifacts),
            .sceneryAndNature
        )
    }

    func testCategoryTieUsesStableDisplayOrder() {
        let artifacts = [
            artifact(placeID: "venue", category: .landmarks),
            artifact(placeID: "venue", category: .foodAndDrink)
        ]

        XCTAssertEqual(
            PlaceMapCategoryStyle.category(for: "venue", in: artifacts),
            .foodAndDrink
        )
    }

    func testPlaceWithoutEvidenceUsesOtherCategory() {
        XCTAssertEqual(
            PlaceMapCategoryStyle.category(for: "missing", in: []),
            .other
        )
    }

    private func artifact(placeID: String, category: ExperienceCategory) -> Artifact {
        Artifact(
            kind: .manual,
            originalText: "Saved place",
            place: SavedPlace(
                id: placeID,
                name: "Venue",
                latitude: 42,
                longitude: -71,
                locality: "Boston",
                region: "Massachusetts",
                country: "United States"
            ),
            enrichment: ArtifactEnrichment(
                summary: "A saved place.",
                category: category,
                interests: [],
                source: .savedText,
                confidence: 1,
                generatedAt: .now
            ),
            enrichmentState: .processed,
            processingState: .processed
        )
    }
}
