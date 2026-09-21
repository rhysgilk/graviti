import XCTest
@testable import graviti

@MainActor
final class ArtifactEnricherSemanticTests: XCTestCase {
    func testUserDescriptionOutweighsOriginalTextAndRetainsExactSource() async throws {
        let artifact = Artifact(
            kind: .photo,
            originalText: "Architecture museum",
            userNote: "The handmade tacos are why I saved this",
            mediaKey: "photo.png"
        )

        let result = try await ArtifactEnricher().enrich(artifact)
        let enrichment = try XCTUnwrap(result)

        XCTAssertEqual(enrichment.category, .foodAndDrink)
        XCTAssertEqual(enrichment.interests.first, "Tacos")
        XCTAssertTrue(enrichment.interestEvidence?.contains {
            $0.interest == "Tacos" && $0.source == .userNote && $0.confidence == 0.95
        } == true)
    }

    func testFineGrainedLandscapeMotifsStayDistinct() async throws {
        let forest = Artifact(kind: .manual, originalText: "Mossy forest hiking trail")
        let desert = Artifact(kind: .manual, originalText: "Desert hiking through red canyons")
        let coast = Artifact(kind: .manual, originalText: "Rugged rocky cliffs along the ocean coast, not a beach")

        let forestOutput = try await awaitResult(for: forest)
        let desertOutput = try await awaitResult(for: desert)
        let coastOutput = try await awaitResult(for: coast)
        let forestResult = try XCTUnwrap(forestOutput)
        let desertResult = try XCTUnwrap(desertOutput)
        let coastResult = try XCTUnwrap(coastOutput)

        XCTAssertTrue(forestResult.interests.contains("Forest hiking"))
        XCTAssertFalse(forestResult.interests.contains("Desert hiking"))
        XCTAssertTrue(desertResult.interests.contains("Desert hiking"))
        XCTAssertTrue(coastResult.interests.contains("Rocky coast"))
        XCTAssertFalse(coastResult.interests.contains("Beaches"))
    }

    func testHistoricAndModernArchitectureRemainDistinct() async throws {
        let historic = Artifact(kind: .manual, originalText: "Historic medieval architecture and cathedral")
        let modern = Artifact(kind: .manual, originalText: "Modernist contemporary architecture")

        let historicOutput = try await awaitResult(for: historic)
        let modernOutput = try await awaitResult(for: modern)
        let historicResult = try XCTUnwrap(historicOutput)
        let modernResult = try XCTUnwrap(modernOutput)

        XCTAssertTrue(historicResult.interests.contains("Historic architecture"))
        XCTAssertFalse(historicResult.interests.contains("Modern architecture"))
        XCTAssertTrue(modernResult.interests.contains("Modern architecture"))
        XCTAssertFalse(modernResult.interests.contains("Historic architecture"))
    }

    func testSpecificDishesRemainAvailableAlongsideBroadFoodCategory() async throws {
        let artifact = Artifact(kind: .manual, originalText: "Dim sum, pho, and sushi restaurants")

        let result = try await ArtifactEnricher().enrich(artifact)
        let enrichment = try XCTUnwrap(result)

        XCTAssertEqual(enrichment.category, .foodAndDrink)
        XCTAssertTrue(enrichment.interests.contains("Dim sum"))
        XCTAssertTrue(enrichment.interests.contains("Pho"))
        XCTAssertTrue(enrichment.interests.contains("Sushi"))
    }

    func testLegacyEnrichmentWithoutEvidenceStillDecodes() throws {
        let enrichment = ArtifactEnrichment(
            summary: "A saved museum.",
            category: .artsAndCulture,
            interests: ["Museums"],
            source: .savedText,
            confidence: 0.55,
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let encoded = try JSONEncoder().encode(enrichment)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "interestEvidence")

        let decoded = try JSONDecoder().decode(
            ArtifactEnrichment.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        XCTAssertNil(decoded.interestEvidence)
        XCTAssertEqual(decoded.interests, ["Museums"])
    }

    private func awaitResult(for artifact: Artifact) async throws -> ArtifactEnrichment? {
        try await ArtifactEnricher().enrich(artifact)
    }
}
