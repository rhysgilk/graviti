import XCTest
@testable import graviti

final class DestinationFitEngineTests: XCTestCase {
    func testSparseEvidenceNeverClaimsHighFit() {
        let artifacts = [artifact(interests: ["Matcha"], place: place("one", locality: "Providence", region: "Rhode Island"))]
        let results = recommendations(artifacts)

        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy { $0.confidence == .early })
        XCTAssertTrue(results.allSatisfy { $0.fitPercent < 70 })
    }

    func testMatchaEvidenceFavorsJapanAndNotSavedGeography() {
        let artifacts = (0..<6).map { index in
            artifact(
                interests: ["Matcha", "Tea"],
                place: place("matcha-\(index)", locality: index.isMultiple(of: 2) ? "Providence" : "Newport", region: "Rhode Island"),
                note: "Saved for ceremonial matcha, tea craft, and traditional preparation."
            )
        }
        let results = recommendations(artifacts, limit: 5)

        XCTAssertEqual(results.first?.name, "Uji")
        XCTAssertTrue(results.prefix(3).contains { $0.country == "Japan" })
        XCTAssertFalse(results.contains { $0.name == "Rhode Island" })
        XCTAssertTrue(results.allSatisfy { $0.fitPercent < 90 })
    }

    func testForestEvidenceRanksSpecificForestDestinationsAboveCalifornia() throws {
        let artifacts = (0..<6).map { index in
            artifact(
                interests: ["Forests", "Hiking"],
                place: place("forest-\(index)", locality: "Woodland \(index)", region: index.isMultiple(of: 2) ? "Rhode Island" : "Massachusetts"),
                note: "Quiet shaded trail through dense woods with moss, streams, and old-growth trees."
            )
        }
        let results = recommendations(artifacts, limit: 10)
        let california = try XCTUnwrap(results.firstIndex { $0.name == "California" })
        let vermont = try XCTUnwrap(results.firstIndex { $0.name == "Vermont" })
        let seattle = try XCTUnwrap(results.firstIndex { $0.name == "Seattle" })

        XCTAssertLessThan(vermont, california)
        XCTAssertLessThan(seattle, california)
    }

    func testIndependentPlacesIncreaseConfidenceOverRepeatedSaves() throws {
        let repeated = (0..<6).map { _ in artifact(interests: ["Seafood"], place: place("same", locality: "Boston", region: "Massachusetts")) }
        let independent = (0..<6).map { index in
            artifact(interests: ["Seafood"], place: place("place-\(index)", locality: "Coast \(index)", region: "State \(index)"))
        }

        let repeatedMaine = try XCTUnwrap(recommendations(repeated).first { $0.name == "Maine" })
        let independentMaine = try XCTUnwrap(recommendations(independent).first { $0.name == "Maine" })
        XCTAssertGreaterThan(independentMaine.confidencePercent, repeatedMaine.confidencePercent)
        XCTAssertGreaterThan(independentMaine.fitPercent, repeatedMaine.fitPercent)
    }

    func testAvoidedInterestRemovesCandidatesKnownForIt() {
        let artifacts = [artifact(interests: ["Forests", "Hiking"], place: place("trail", locality: "Trail", region: "Vermont"))]
        let profile = InterestProfileBuilder.build(from: artifacts)
        let preferences = ExplorePreferences(avoidedInterests: ["Forests"])
        let results = DestinationFitEngine.recommendations(from: profile, artifacts: artifacts, preferences: preferences, limit: 20)

        XCTAssertFalse(results.contains { $0.name == "Vermont" || $0.name == "Seattle" })
    }

    private func recommendations(_ artifacts: [Artifact], limit: Int = 3) -> [DestinationRecommendation] {
        DestinationFitEngine.recommendations(from: InterestProfileBuilder.build(from: artifacts), artifacts: artifacts, limit: limit)
    }

    private func artifact(interests: [String], place: SavedPlace, note: String? = nil) -> Artifact {
        Artifact(
            kind: .manual,
            originalText: note ?? interests.joined(separator: " and "),
            userNote: note,
            place: place,
            enrichment: ArtifactEnrichment(
                summary: note,
                category: .other,
                interests: interests,
                source: .savedText,
                confidence: 0.8,
                generatedAt: .now
            ),
            enrichmentState: .processed,
            processingState: .processed
        )
    }

    private func place(_ id: String, locality: String, region: String) -> SavedPlace {
        SavedPlace(id: id, name: id, latitude: 0, longitude: 0, locality: locality, region: region, country: "United States")
    }
}
