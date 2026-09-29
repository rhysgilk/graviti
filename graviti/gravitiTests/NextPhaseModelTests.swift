import XCTest
import CoreLocation
@testable import graviti

final class NextPhaseModelTests: XCTestCase {
    func testRecommendationFeedbackCanBeChangedAndRemoved() throws {
        let event = RecommendationFeedbackEvent(
            id: UUID(),
            recommendationID: "kyoto",
            prompt: "Should gardens influence future recommendations?",
            response: .notSure,
            createdAt: Date(timeIntervalSince1970: 100)
        )

        let saved = RecommendationFeedbackStore.appending(event, to: "")
        let changed = RecommendationFeedbackStore.replacingResponse(for: event.id, with: .yes, in: saved)

        XCTAssertEqual(RecommendationFeedbackStore.decode(changed).first?.response, .yes)
        XCTAssertEqual(RecommendationFeedbackStore.decode(changed).first?.createdAt, event.createdAt)
        XCTAssertTrue(RecommendationFeedbackStore.decode(
            RecommendationFeedbackStore.removing(event.id, from: changed)
        ).isEmpty)
    }

    func testRecommendationFeedbackKeepsMostRecentFiveHundredEvents() {
        var stored = ""
        for index in 0..<505 {
            stored = RecommendationFeedbackStore.appending(
                RecommendationFeedbackEvent(
                    id: UUID(),
                    recommendationID: "destination-\(index)",
                    prompt: "Prompt \(index)",
                    response: .yes,
                    createdAt: Date(timeIntervalSince1970: TimeInterval(index))
                ),
                to: stored
            )
        }

        let events = RecommendationFeedbackStore.decode(stored)
        XCTAssertEqual(events.count, 500)
        XCTAssertEqual(events.first?.recommendationID, "destination-5")
        XCTAssertEqual(events.last?.recommendationID, "destination-504")
    }

    func testRecommendationOutcomesDeduplicateDailyExposureAndKeepActions() {
        let recommendation = DestinationRecommendation(
            name: "Kyoto",
            country: "Japan",
            fitPercent: 72,
            relevancePercent: 88,
            confidence: .developing,
            confidencePercent: 61,
            knowledgeConfidencePercent: 90,
            knowledgeSources: [],
            matchedInterests: ["Temples", "Tea"],
            supportingArtifacts: [],
            explicitMatches: [],
            visitedLikedMatches: []
        )
        let firstDate = Date(timeIntervalSince1970: 100)
        var raw = RecommendationOutcomeStore.recording(.shown, recommendation: recommendation, in: "", now: firstDate)
        raw = RecommendationOutcomeStore.recording(.shown, recommendation: recommendation, in: raw, now: firstDate.addingTimeInterval(60))
        raw = RecommendationOutcomeStore.recording(.opened, recommendation: recommendation, in: raw, now: firstDate.addingTimeInterval(61))

        let events = RecommendationOutcomeStore.decode(raw)
        XCTAssertEqual(events.map(\.kind), [.shown, .opened])
        XCTAssertEqual(events.first?.score, 72)
        XCTAssertEqual(events.first?.matchedInterests, ["Temples", "Tea"])
    }

    func testRecommendationPromptCanBeDismissedAndIsRateLimited() {
        let now = Date(timeIntervalSince1970: 100)
        let prompt = "Should tea influence future recommendations?"
        XCTAssertTrue(RecommendationPromptStore.shouldShow(recommendationID: "kyoto", prompt: prompt, in: "", now: now))
        var raw = RecommendationPromptStore.markingShown(recommendationID: "kyoto", prompt: prompt, in: "", now: now)
        XCTAssertFalse(RecommendationPromptStore.shouldShow(recommendationID: "kyoto", prompt: prompt, in: raw, now: now.addingTimeInterval(86_400)))
        XCTAssertTrue(RecommendationPromptStore.shouldShow(recommendationID: "kyoto", prompt: prompt, in: raw, now: now.addingTimeInterval(8 * 86_400)))
        raw = RecommendationPromptStore.dismissing(recommendationID: "kyoto", prompt: prompt, in: raw, now: now.addingTimeInterval(9 * 86_400))
        XCTAssertFalse(RecommendationPromptStore.shouldShow(recommendationID: "kyoto", prompt: prompt, in: raw, now: now.addingTimeInterval(30 * 86_400)))
    }

    func testFitGuideMetadataRoundTripsAndOlderPayloadUsesDefaults() throws {
        let coverID = UUID()
        let artifactID = UUID()
        var data = Data()
        let expected = FitGuideMetadata(
            customTitle: "Kyoto spring",
            note: "Prioritize quiet gardens.",
            archived: true,
            coverArtifactID: coverID,
            shortlistPlaceIDs: ["garden"],
            orderedArtifactIDs: [artifactID],
            updatedAt: Date(timeIntervalSince1970: 200)
        )

        FitGuideMetadataStore.update(expected, for: "kyoto", in: &data)
        XCTAssertEqual(FitGuideMetadataStore.metadata(for: "kyoto", in: data), expected)

        let legacy = Data(#"{"kyoto":{"customTitle":"Old Kyoto"}}"#.utf8)
        let decoded = FitGuideMetadataStore.metadata(for: "kyoto", in: legacy)
        XCTAssertEqual(decoded.customTitle, "Old Kyoto")
        XCTAssertFalse(decoded.archived)
        XCTAssertTrue(decoded.shortlistPlaceIDs.isEmpty)
        XCTAssertTrue(decoded.orderedArtifactIDs.isEmpty)
    }

    func testCompletenessFindsEveryMissingDetailAndAcceptsFilledSave() {
        let emptyURL = Artifact(kind: .url, sourceURL: "https://example.com")
        XCTAssertEqual(Set(emptyURL.completeness.gaps), Set(ArtifactCompleteness.Gap.allCases))

        let place = SavedPlace(
            id: "museum",
            name: "City Museum",
            latitude: 40.7,
            longitude: -74,
            locality: "New York",
            region: "New York",
            country: "United States"
        )
        let filled = Artifact(
            kind: .url,
            sourceURL: "https://example.com/museum",
            originalText: "City Museum",
            userNote: "The architecture caught my eye.",
            linkMetadata: ArtifactLinkMetadata(
                title: "City Museum",
                summary: "A museum in the city.",
                siteName: "Example",
                imageData: nil,
                resolvedURL: "https://example.com/museum",
                fetchedAt: .now
            ),
            linkMetadataState: .processed,
            place: place,
            enrichment: ArtifactEnrichment(
                summary: "A museum known for modern architecture.",
                category: .artsAndCulture,
                interests: ["museums", "architecture"],
                source: .linkMetadata,
                confidence: 0.9,
                generatedAt: .now
            ),
            enrichmentState: .processed,
            processingState: .processed
        )

        XCTAssertTrue(filled.completeness.isComplete)
        XCTAssertEqual(filled.completeness.score, ArtifactCompleteness.Gap.allCases.count)
    }

    func testRemovingGuideMembershipRetainsOtherCollections() {
        let artifact = Artifact(
            kind: .url,
            sourceCollectionTitle: "Kyoto Fit Guide · Gardens",
            additionalSourceCollectionTitles: ["Japan ideas", "Kyoto Fit Guide · Museums"]
        )

        let updated = artifact.removingSourceCollectionTitles { $0.hasPrefix("Kyoto Fit Guide") }

        XCTAssertEqual(updated.sourceCollectionTitles, ["Japan ideas"])
    }

    func testFitGuideMigrationAndDuplicationUseIndependentMemberships() {
        let destination = SavedDestination(name: "Kyoto", country: "Japan")
        let guide = FitGuide(destination: destination, interests: ["gardens", "museums"])
        let garden = Artifact(
            kind: .url,
            sourceCollectionTitle: guide.collectionTitle(for: "gardens"),
            originalText: "Quiet garden"
        )
        let museum = Artifact(
            kind: .url,
            sourceCollectionTitle: guide.collectionTitle(for: "museums"),
            originalText: "City museum"
        )
        var raw = ""

        FitGuideLibraryStore.migrateLegacyMemberships(for: guide, artifacts: [garden, museum], in: &raw)
        let duplicate = FitGuideLibraryStore.duplicate(guide: guide, in: &raw)

        XCTAssertNotEqual(duplicate.id, guide.id)
        XCTAssertEqual(Set(FitGuideLibraryStore.memberships(for: guide.id, in: raw).map(\.artifactID)), [garden.id, museum.id])
        XCTAssertEqual(Set(FitGuideLibraryStore.memberships(for: duplicate.id, in: raw).map(\.artifactID)), [garden.id, museum.id])

        FitGuideLibraryStore.removeMembership(guideID: duplicate.id, artifactID: garden.id, from: &raw)
        XCTAssertEqual(FitGuideLibraryStore.memberships(for: duplicate.id, in: raw).map(\.artifactID), [museum.id])
        XCTAssertEqual(Set(FitGuideLibraryStore.memberships(for: guide.id, in: raw).map(\.artifactID)), [garden.id, museum.id])

        let removed = FitGuideMembership(
            guideID: duplicate.id,
            artifactID: garden.id,
            interest: "gardens",
            addedAt: Date(timeIntervalSince1970: 300)
        )
        FitGuideLibraryStore.restoreMembership(removed, in: &raw)
        XCTAssertEqual(Set(FitGuideLibraryStore.memberships(for: duplicate.id, in: raw).map(\.artifactID)), [garden.id, museum.id])
    }

    func testImportAttemptPersistsDuplicateAndRetryStatesWithoutAnArtifact() throws {
        var raw = ""
        let duplicateID = ImportAttemptStore.beginning(
            kind: .googleList,
            label: "Shared list",
            sourceURL: "https://maps.app.goo.gl/example",
            in: &raw
        )
        ImportAttemptStore.completing(
            duplicateID,
            title: "New York 2026",
            imported: 0,
            duplicates: 8,
            skipped: 0,
            in: &raw
        )

        var attempts = ImportAttemptStore.decode(raw)
        XCTAssertEqual(attempts.first?.status, .duplicate)
        XCTAssertEqual(attempts.first?.duplicates, 8)

        let failedID = ImportAttemptStore.beginning(
            kind: .appleGuide,
            label: "Apple Maps guide",
            sourceURL: "https://maps.apple.com/guide/example",
            in: &raw
        )
        ImportAttemptStore.failing(failedID, message: "Offline", in: &raw)
        XCTAssertEqual(ImportAttemptStore.decode(raw).last?.status, .failed)

        ImportAttemptStore.markProcessing(failedID, in: &raw)
        attempts = ImportAttemptStore.decode(raw)
        XCTAssertEqual(attempts.last?.status, .processing)
        XCTAssertNil(attempts.last?.message)
    }

    func testNearbyPlacesAreOrderedByRealDistance() {
        let current = CLLocation(latitude: 42.3601, longitude: -71.0589)
        let nearby = SavedPlace(
            id: "nearby",
            name: "Nearby",
            latitude: 42.361,
            longitude: -71.059,
            locality: "Boston",
            region: "Massachusetts",
            country: "United States"
        )
        let farther = SavedPlace(
            id: "farther",
            name: "Farther",
            latitude: 42.39,
            longitude: -71.10,
            locality: "Somerville",
            region: "Massachusetts",
            country: "United States"
        )

        XCTAssertEqual(NearbyPlaceSorter.sort([farther, nearby], from: current).map(\.id), ["nearby", "farther"])
        XCTAssertLessThan(
            NearbyPlaceSorter.distance(from: current, to: nearby),
            NearbyPlaceSorter.distance(from: current, to: farther)
        )
    }
}

@MainActor
final class NextPhaseLibraryUndoTests: XCTestCase {
    func testSampleLibraryCanBeAddedAndRemovedWithoutTouchingRealSaves() async throws {
        let real = Artifact(kind: .manual, originalText: "My real save")
        let repository = PreviewArtifactRepository()
        try await repository.save(real)
        let library = ArtifactLibrary(repository: repository)
        await library.load()

        let added = try await library.addSampleLibrary()
        XCTAssertEqual(added, SampleLibrarySeeder.artifacts.count)
        XCTAssertTrue(library.hasSampleLibrary)
        XCTAssertTrue(library.artifacts.contains(real))
        let secondAddition = try await library.addSampleLibrary()
        XCTAssertEqual(secondAddition, 0)

        let removed = try await library.removeSampleLibrary()
        XCTAssertEqual(removed, SampleLibrarySeeder.artifacts.count)
        XCTAssertEqual(library.artifacts, [real])
        let persisted = try await repository.artifacts()
        XCTAssertEqual(persisted, [real])
    }

    func testStagedArtifactDeletionCanBeRestoredExactly() async throws {
        let repository = PreviewArtifactRepository()
        let artifact = Artifact(kind: .manual, originalText: "Quiet forest trail", userNote: "Go in autumn")
        try await repository.save(artifact)
        let library = ArtifactLibrary(repository: repository)
        await library.load()

        let stagedValue = try await library.stageArtifactDeletion(artifact.id)
        let staged = try XCTUnwrap(stagedValue)
        XCTAssertTrue(library.artifacts.isEmpty)
        let stagedRepositoryArtifacts = try await repository.artifacts()
        XCTAssertTrue(stagedRepositoryArtifacts.isEmpty)

        try await library.restoreArtifactDeletion(staged)
        XCTAssertEqual(library.artifacts, [artifact])
        let restoredRepositoryArtifacts = try await repository.artifacts()
        XCTAssertEqual(restoredRepositoryArtifacts, [artifact])
    }

    func testStagedPlaceRemovalCanRestoreEverySourceSave() async throws {
        let place = SavedPlace(
            id: "acadia",
            name: "Acadia National Park",
            latitude: 44.3,
            longitude: -68.2,
            locality: "Bar Harbor",
            region: "Maine",
            country: "United States"
        )
        let originals = [
            Artifact(kind: .url, originalText: "Acadia", place: place, processingState: .processed),
            Artifact(kind: .manual, originalText: "Ocean Path", place: place, processingState: .processed)
        ]
        let repository = PreviewArtifactRepository()
        try await repository.saveMany(originals)
        let library = ArtifactLibrary(repository: repository)
        await library.load()

        let staged = try await library.stagePlaceRemoval(place.id)
        XCTAssertEqual(staged.count, 2)
        XCTAssertTrue(library.artifacts.allSatisfy { $0.place == nil && $0.processingState == .needsReview })

        try await library.restorePlaceRemoval(staged)
        XCTAssertEqual(Set(library.artifacts), Set(originals))
        let restoredRepositoryArtifacts = try await repository.artifacts()
        XCTAssertEqual(Set(restoredRepositoryArtifacts), Set(originals))
    }
}
