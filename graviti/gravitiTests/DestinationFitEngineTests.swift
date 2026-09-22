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

    func testExcludedDestinationDoesNotReturnInLaterRecommendations() {
        let artifacts = (0..<4).map { index in
            artifact(
                interests: ["Forests", "Hiking"],
                place: place("forest-\(index)", locality: "Woodland \(index)", region: "Vermont")
            )
        }
        let profile = InterestProfileBuilder.build(from: artifacts)
        let initial = DestinationFitEngine.recommendations(from: profile, artifacts: artifacts, limit: 20)
        let excluded = initial.first?.id
        XCTAssertNotNil(excluded)

        let preferences = ExplorePreferences(excludedDestinationIDs: Set([excluded].compactMap { $0 }))
        let updated = DestinationFitEngine.recommendations(
            from: profile, artifacts: artifacts, preferences: preferences, limit: 20
        )

        XCTAssertFalse(updated.contains { $0.id == excluded })
    }

    func testFitGuideUsesTheUsersStrongestMatchingPatterns() throws {
        let artifacts = (0..<4).map { index in
            artifact(
                interests: ["Museums", "Coffee", "Matcha", "Desserts"],
                place: place("ny-pattern-\(index)", locality: "Providence", region: "Rhode Island")
            )
        }
        let profile = InterestProfileBuilder.build(from: artifacts)

        let guide = try XCTUnwrap(DestinationFitEngine.fitGuide(
            for: "New York City, United States",
            from: profile
        ))

        XCTAssertEqual(guide.destination.name, "New York City")
        XCTAssertEqual(Set(guide.interests), Set(["Museums", "Coffee", "Matcha", "Desserts"]))
    }

    func testFineGrainedMotifsGeneralizeToSpecificDestinations() {
        let desert = (0..<4).map { index in
            artifact(interests: ["Desert hiking", "Hiking"], place: place("desert-\(index)", locality: "Trail \(index)", region: "Arizona"))
        }
        let forestCoast = (0..<4).map { index in
            artifact(interests: ["Forest hiking", "Rocky coast"], place: place("coast-\(index)", locality: "Coast \(index)", region: "Oregon"))
        }
        let pho = (0..<4).map { index in
            artifact(interests: ["Pho", "Food"], place: place("pho-\(index)", locality: "Neighborhood \(index)", region: "Massachusetts"))
        }

        XCTAssertEqual(recommendations(desert).first?.name, "Sedona")
        XCTAssertEqual(recommendations(forestCoast).first?.name, "Olympic Peninsula")
        XCTAssertEqual(recommendations(pho).first?.name, "Hanoi")
    }

    func testDestinationKnowledgeConfidenceCapsDisplayedCertainty() throws {
        let artifacts = (0..<8).map { index in
            artifact(interests: ["Museums"], place: place("museum-\(index)", locality: "City \(index)", region: "State \(index)"))
        }
        let source = DestinationKnowledgeSource(
            title: "Reviewed source",
            url: try XCTUnwrap(URL(string: "https://example.com/source")),
            reviewedAt: "2026-09-20"
        )
        let catalog = DestinationKnowledgeCatalog(
            schemaVersion: 1,
            catalogVersion: "test",
            reviewedAt: "2026-09-20",
            destinations: [
                DestinationKnowledge(
                    name: "Low confidence city",
                    country: "Test",
                    region: .anywhere,
                    searchSpan: 1,
                    dataConfidence: 0.35,
                    strengths: ["Museums": 1],
                    sources: [source]
                )
            ]
        )

        let result = try XCTUnwrap(DestinationFitEngine.recommendations(
            from: InterestProfileBuilder.build(from: artifacts),
            artifacts: artifacts,
            limit: 1,
            catalog: catalog
        ).first)

        XCTAssertEqual(result.knowledgeConfidencePercent, 35)
        XCTAssertLessThanOrEqual(result.confidencePercent, 35)
        XCTAssertEqual(result.confidence, .early)
        XCTAssertLessThan(result.fitPercent, 70)
    }

    func testReviewedCatalogIsBundledAndVersioned() {
        let catalog = DestinationKnowledgeCatalogLoader.bundled

        XCTAssertEqual(catalog.schemaVersion, 1)
        XCTAssertFalse(catalog.catalogVersion.isEmpty)
        XCTAssertGreaterThanOrEqual(catalog.destinations.count, 20)
        XCTAssertTrue(catalog.destinations.allSatisfy { !$0.sources.isEmpty })
    }

    func testUserNotesCarryMoreSignalThanACollectionTitle() throws {
        let noteEvidence = (0..<4).map { index in
            artifact(
                interests: ["Historic architecture", "Coffee"],
                place: place("note-\(index)", locality: "City \(index)", region: "State \(index)"),
                evidenceSources: ["Historic architecture": .userNote, "Coffee": .collectionTitle]
            )
        }
        let collectionEvidence = (0..<4).map { index in
            artifact(
                interests: ["Historic architecture", "Coffee"],
                place: place("collection-\(index)", locality: "City \(index)", region: "State \(index)"),
                evidenceSources: ["Historic architecture": .collectionTitle, "Coffee": .userNote]
            )
        }

        let noteResult = try XCTUnwrap(recommendations(noteEvidence, limit: 20).first { $0.name == "Kyoto" })
        let collectionResult = try XCTUnwrap(recommendations(collectionEvidence, limit: 20).first { $0.name == "Kyoto" })
        XCTAssertGreaterThan(noteResult.relevancePercent, collectionResult.relevancePercent)
    }

    func testOneImportedCollectionIsDiscountedAgainstIndependentSources() throws {
        let oneCollectionMuseums = (0..<4).map { index in
            artifact(
                interests: ["Museums"],
                place: place("one-collection-museum-\(index)", locality: "Museum city \(index)", region: "State \(index)"),
                sourceCollectionTitle: "One imported guide"
            )
        }
        let independentMuseums = (0..<4).map { index in
            artifact(
                interests: ["Museums"],
                place: place("independent-museum-\(index)", locality: "Museum city \(index)", region: "State \(index)"),
                sourceCollectionTitle: "Guide \(index)"
            )
        }
        let independentCoffee = (0..<4).map { index in
            artifact(
                interests: ["Coffee"],
                place: place("coffee-\(index)", locality: "Coffee city \(index)", region: "Region \(index)"),
                sourceCollectionTitle: "Coffee source \(index)"
            )
        }
        let source = DestinationKnowledgeSource(
            title: "Reviewed source",
            url: try XCTUnwrap(URL(string: "https://example.com/source")),
            reviewedAt: "2026-09-20"
        )
        let catalog = DestinationKnowledgeCatalog(
            schemaVersion: 1,
            catalogVersion: "test",
            reviewedAt: "2026-09-20",
            destinations: [DestinationKnowledge(
                name: "Museum destination",
                country: "Test",
                region: .anywhere,
                searchSpan: 1,
                dataConfidence: 0.9,
                strengths: ["Museums": 1],
                sources: [source]
            )]
        )

        let correlated = oneCollectionMuseums + independentCoffee
        let independent = independentMuseums + independentCoffee
        let correlatedResult = try XCTUnwrap(DestinationFitEngine.recommendations(
            from: InterestProfileBuilder.build(from: correlated), artifacts: correlated, limit: 1, catalog: catalog
        ).first)
        let independentResult = try XCTUnwrap(DestinationFitEngine.recommendations(
            from: InterestProfileBuilder.build(from: independent), artifacts: independent, limit: 1, catalog: catalog
        ).first)

        XCTAssertGreaterThan(independentResult.relevancePercent, correlatedResult.relevancePercent)
    }

    func testVisitedLikedFeedbackAddsConservativeSignalsAndHidesVisitedDestination() throws {
        let source = DestinationKnowledgeSource(
            title: "Reviewed source",
            url: try XCTUnwrap(URL(string: "https://example.com/source")),
            reviewedAt: "2026-09-21"
        )
        let catalog = DestinationKnowledgeCatalog(
            schemaVersion: 1,
            catalogVersion: "feedback-test",
            reviewedAt: "2026-09-21",
            destinations: [
                DestinationKnowledge(
                    name: "Visited tea city", country: "Test", region: .anywhere,
                    searchSpan: 1, dataConfidence: 0.9,
                    strengths: ["Tea": 1, "Gardens": 0.9], sources: [source]
                ),
                DestinationKnowledge(
                    name: "New tea city", country: "Test", region: .anywhere,
                    searchSpan: 1, dataConfidence: 0.9,
                    strengths: ["Tea": 0.95, "Gardens": 0.85], sources: [source]
                ),
                DestinationKnowledge(
                    name: "Museum city", country: "Test", region: .anywhere,
                    searchSpan: 1, dataConfidence: 0.9,
                    strengths: ["Museums": 1], sources: [source]
                )
            ]
        )
        let preferences = ExplorePreferences(
            visitedLikedDestinationIDs: ["Visited tea city, Test"]
        )

        let results = DestinationFitEngine.recommendations(
            from: InterestProfile(interests: [], categories: []),
            artifacts: [],
            preferences: preferences,
            limit: 10,
            catalog: catalog
        )

        let recommendation = try XCTUnwrap(results.first)
        XCTAssertEqual(recommendation.name, "New tea city")
        XCTAssertFalse(results.contains { $0.name == "Visited tea city" })
        XCTAssertEqual(Set(recommendation.visitedLikedMatches), Set(["Tea", "Gardens"]))
        XCTAssertEqual(recommendation.confidence, .early)
        XCTAssertLessThan(recommendation.fitPercent, 70)
        XCTAssertTrue(recommendation.supportingArtifacts.isEmpty)
    }

    func testVisitedNotFitFeedbackExcludesDestinationWithoutInventingInterests() {
        let preferences = ExplorePreferences(
            visitedNotFitDestinationIDs: ["Kyoto, Japan"]
        )

        let results = DestinationFitEngine.recommendations(
            from: InterestProfile(interests: [], categories: []),
            artifacts: [],
            preferences: preferences,
            limit: 10
        )

        XCTAssertTrue(results.isEmpty)
    }

    private func recommendations(_ artifacts: [Artifact], limit: Int = 3) -> [DestinationRecommendation] {
        DestinationFitEngine.recommendations(from: InterestProfileBuilder.build(from: artifacts), artifacts: artifacts, limit: limit)
    }

    private func artifact(
        interests: [String],
        place: SavedPlace,
        note: String? = nil,
        sourceCollectionTitle: String? = nil,
        evidenceSources: [String: ArtifactEvidenceSource] = [:]
    ) -> Artifact {
        Artifact(
            kind: .manual,
            sourceCollectionTitle: sourceCollectionTitle,
            originalText: note ?? interests.joined(separator: " and "),
            userNote: note,
            place: place,
            enrichment: ArtifactEnrichment(
                summary: note,
                category: .other,
                interests: interests,
                source: .savedText,
                confidence: 0.8,
                generatedAt: .now,
                interestEvidence: evidenceSources.isEmpty ? nil : interests.compactMap { interest in
                    evidenceSources[interest].map { source in
                        ArtifactInterestEvidence(interest: interest, source: source, confidence: 0.8)
                    }
                }
            ),
            enrichmentState: .processed,
            processingState: .processed
        )
    }

    private func place(_ id: String, locality: String, region: String) -> SavedPlace {
        SavedPlace(id: id, name: id, latitude: 0, longitude: 0, locality: locality, region: region, country: "United States")
    }
}
