import XCTest
@testable import graviti

@MainActor
final class DurableInfrastructureTests: XCTestCase {
    func testProcessingJobsPersistAndRecoverInterruptedWorkWithBoundedRetry() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        let artifact = Artifact(kind: .url, sourceURL: "https://example.com/place", originalText: "A place")
        var firstStore = ProcessingJobStore(fileURL: fileURL)

        var jobs = try firstStore.reconcile(with: [artifact], now: Date(timeIntervalSince1970: 100))
        XCTAssertEqual(jobs.first(where: { $0.kind == .linkMetadata })?.status, .pending)
        XCTAssertEqual(
            jobs.first(where: { $0.kind == .enrichment })?.dependencyKinds,
            [.linkMetadata]
        )

        try firstStore.markRunning(
            artifactID: artifact.id,
            kind: .linkMetadata,
            now: Date(timeIntervalSince1970: 101)
        )

        var resumedStore = ProcessingJobStore(fileURL: fileURL)
        jobs = try resumedStore.reconcile(with: [artifact], now: Date(timeIntervalSince1970: 102))
        var metadataJob = try XCTUnwrap(jobs.first { $0.kind == .linkMetadata })
        XCTAssertEqual(metadataJob.status, .waitingForRetry)
        XCTAssertEqual(metadataJob.attemptCount, 1)
        XCTAssertEqual(metadataJob.nextRetryAt, Date(timeIntervalSince1970: 102))

        let error = TestProcessingError.offline
        try resumedStore.markFailed(
            artifactID: artifact.id,
            kind: .linkMetadata,
            error: error,
            now: Date(timeIntervalSince1970: 103)
        )
        for index in 2...ProcessingRetryPolicy.maximumAttempts {
            try resumedStore.markRunning(
                artifactID: artifact.id,
                kind: .linkMetadata,
                now: Date(timeIntervalSince1970: TimeInterval(103 + index))
            )
            try resumedStore.markFailed(
                artifactID: artifact.id,
                kind: .linkMetadata,
                error: error,
                now: Date(timeIntervalSince1970: TimeInterval(104 + index))
            )
        }
        let loadedJobs = try resumedStore.load()
        metadataJob = try XCTUnwrap(loadedJobs.first { $0.kind == .linkMetadata })
        XCTAssertEqual(metadataJob.status, .cancelled)
        XCTAssertEqual(metadataJob.attemptCount, ProcessingRetryPolicy.maximumAttempts)
        XCTAssertNil(metadataJob.nextRetryAt)
        XCTAssertEqual(metadataJob.lastError, error.localizedDescription)
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testDerivedIndexCanBeDeletedAndRebuiltIncludingGuideMemberships() throws {
        let place = SavedPlace(
            id: "acadia",
            name: "Acadia National Park",
            latitude: 44.3386,
            longitude: -68.2733,
            locality: "Bar Harbor",
            region: "Maine",
            country: "United States"
        )
        let artifact = Artifact(
            kind: .manual,
            originalText: "Rocky coastline and mountain trails",
            userNote: "Sunrise viewpoint",
            place: place,
            enrichment: ArtifactEnrichment(
                summary: "A national park with a rocky coast.",
                category: .sceneryAndNature,
                interests: ["National parks", "Rocky coast"],
                source: .savedText,
                confidence: 0.9,
                generatedAt: .now
            ),
            enrichmentState: .processed,
            processingState: .processed
        )
        let membership = FitGuideMembership(
            guideID: "maine-guide",
            artifactID: artifact.id,
            interest: "National parks",
            addedAt: .now
        )
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        var store = LibraryDerivedIndexStore(fileURL: fileURL)

        let built = LibraryDerivedIndex.build(from: [artifact], guideMemberships: [membership])
        XCTAssertEqual(built.placeToArtifactIDs[place.id], [artifact.id])
        XCTAssertEqual(built.destinationToPlaceIDs["maine"], [place.id])
        XCTAssertEqual(built.interestToArtifactIDs["national parks"], [artifact.id])
        XCTAssertEqual(built.guideToArtifactIDs["maine-guide"], [artifact.id])
        XCTAssertEqual(built.candidateArtifactIDs(for: "rocky coast"), Set([artifact.id]))

        var rawGuide = ""
        let guide = FitGuide(id: "maine-guide", destination: SavedDestination(name: "Maine", country: "United States"), interests: [])
        FitGuideLibraryStore.ensureGuide(guide, in: &rawGuide)
        FitGuideLibraryStore.addMembership(guideID: guide.id, artifactID: artifact.id, interest: "National parks", to: &rawGuide)
        let persisted = try store.rebuild(from: [artifact], guideLibraryJSON: rawGuide)
        XCTAssertEqual(store.load(), persisted)

        try store.removePersistedIndex()
        XCTAssertEqual(store.load(), .empty)
        let rebuilt = try store.rebuild(from: [artifact], guideLibraryJSON: rawGuide)
        XCTAssertEqual(rebuilt.guideToArtifactIDs[guide.id], [artifact.id])
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testGeneratedDataProvenanceIsBackwardCompatible() throws {
        let legacy = #"{"summary":"Scenic","category":"sceneryAndNature","interests":["Nature"],"source":"savedText","confidence":0.8,"generatedAt":100,"interestEvidence":null}"#
        let decoded = try JSONDecoder().decode(ArtifactEnrichment.self, from: Data(legacy.utf8))
        XCTAssertNil(decoded.provenance)

        let current = ArtifactEnrichment(
            summary: "Scenic",
            category: .sceneryAndNature,
            interests: ["Nature"],
            source: .savedText,
            confidence: 0.8,
            generatedAt: .now,
            provenance: GeneratedDataProvenance(producer: "ArtifactEnricher", version: 2)
        )
        let roundTrip = try JSONDecoder().decode(ArtifactEnrichment.self, from: JSONEncoder().encode(current))
        XCTAssertEqual(roundTrip.provenance?.producer, "ArtifactEnricher")
        XCTAssertEqual(roundTrip.provenance?.version, 2)
    }

    func testSavedFilterCombinesIndependentRulesAndRoundTrips() throws {
        let place = SavedPlace(
            id: "matcha",
            name: "Tea House",
            latitude: 42.36,
            longitude: -71.05,
            locality: "Boston",
            region: "Massachusetts",
            country: "United States"
        )
        let matching = Artifact(
            kind: .url,
            sourceURL: "https://www.instagram.com/reel/example",
            userNote: "Try the ceremonial matcha.",
            place: place,
            enrichment: ArtifactEnrichment(
                summary: "A matcha tea house.",
                category: .foodAndDrink,
                interests: ["Matcha"],
                source: .savedText,
                confidence: 0.9,
                generatedAt: .now
            ),
            enrichmentState: .processed,
            userDetails: ArtifactUserDetails(
                summary: nil,
                category: nil,
                interests: [],
                placeStatus: .shortlisted,
                isHighPriority: true
            ),
            processingState: .processed
        )
        let filter = SavedLibraryFilter(
            id: UUID(),
            name: "Boston matcha shortlist",
            category: .foodAndDrink,
            placeQuery: "Boston",
            interestQuery: "matcha",
            noteRule: .withNote,
            sourceRule: .instagram,
            lifecycle: .shortlisted,
            recentlyAdded: true,
            needsDescription: false,
            highPriorityOnly: true
        )
        XCTAssertTrue(filter.matches(matching))
        XCTAssertFalse(filter.matches(matching.withPlaceStatus(.visited)))

        let raw = SavedLibraryFilterStore.encode([filter])
        XCTAssertEqual(SavedLibraryFilterStore.decode(raw), [filter])
    }
}

private enum TestProcessingError: LocalizedError {
    case offline
    var errorDescription: String? { "Offline" }
}
