import XCTest
@testable import graviti

final class DestinationReadinessBuilderTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testRepeatedArtifactsForOnePlaceRemainTakingShape() throws {
        let artifacts = [
            artifact("museum-note", placeID: "museum", category: .artsAndCulture, interest: "Museums"),
            artifact("museum-photo", placeID: "museum", category: .landmarks, interest: "Architecture")
        ]

        let readiness = try readiness(for: artifacts)

        XCTAssertEqual(readiness.band, .takingShape)
        XCTAssertEqual(readiness.placeCount, 1)
        XCTAssertTrue(readiness.guidance.contains("3 more distinct places"))
    }

    func testFourVariedRecentPlacesSupportStrongWeekend() throws {
        let artifacts = [
            artifact("coffee", category: .foodAndDrink, interest: "Coffee"),
            artifact("museum", category: .artsAndCulture, interest: "Museums"),
            artifact("garden", category: .sceneryAndNature, interest: "Gardens"),
            artifact("market", category: .shopping, interest: "Markets")
        ]

        let readiness = try readiness(for: artifacts)

        XCTAssertEqual(readiness.band, .strongWeekend)
        XCTAssertEqual(readiness.placeCount, 4)
        XCTAssertEqual(readiness.categoryCount, 4)
    }

    func testEightVariedPlacesSupportSeveralDays() throws {
        let categories: [ExperienceCategory] = [
            .foodAndDrink, .artsAndCulture, .sceneryAndNature, .activities,
            .landmarks, .shopping, .foodAndDrink, .artsAndCulture
        ]
        let artifacts = categories.enumerated().map { index, category in
            artifact("place-\(index)", category: category, interest: "Interest \(index)")
        }

        let readiness = try readiness(for: artifacts)

        XCTAssertEqual(readiness.band, .readyForSeveralDays)
        XCTAssertEqual(readiness.placeCount, 8)
        XCTAssertEqual(readiness.categoryCount, 6)
    }

    func testCountryReadinessRecognizesEvidenceAcrossRegions() throws {
        let artifacts = [
            artifact("tokyo", city: "Tokyo", region: "Tokyo", country: "Japan", category: .foodAndDrink, interest: "Matcha"),
            artifact("kyoto", city: "Kyoto", region: "Kyoto", country: "Japan", category: .artsAndCulture, interest: "Temples")
        ]
        let node = try XCTUnwrap(DestinationOrbitBuilder.nodes(from: artifacts, mode: .countries, limit: nil).first)

        let readiness = DestinationReadinessBuilder.build(for: node, artifacts: artifacts, now: now)

        XCTAssertEqual(readiness.areaCount, 2)
    }

    private func readiness(for artifacts: [Artifact]) throws -> DestinationReadiness {
        let node = try XCTUnwrap(DestinationOrbitBuilder.nodes(from: artifacts, mode: .cities, limit: nil).first)
        return DestinationReadinessBuilder.build(for: node, artifacts: artifacts, now: now)
    }

    private func artifact(
        _ id: String,
        placeID: String? = nil,
        city: String = "Lisbon",
        region: String = "Lisbon",
        country: String = "Portugal",
        category: ExperienceCategory,
        interest: String
    ) -> Artifact {
        Artifact(
            kind: .manual,
            originalText: id,
            place: SavedPlace(
                id: placeID ?? id,
                name: id,
                latitude: 0,
                longitude: 0,
                locality: city,
                region: region,
                country: country
            ),
            enrichment: ArtifactEnrichment(
                summary: nil,
                category: category,
                interests: [interest],
                source: .savedText,
                confidence: 0.8,
                generatedAt: now
            ),
            enrichmentState: .processed,
            processingState: .processed,
            capturedAt: now
        )
    }
}
