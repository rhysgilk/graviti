import SwiftData
import XCTest
@testable import graviti

@MainActor
final class SwiftDataArtifactRepositoryTests: XCTestCase {
    func testRichArtifactRoundTripsThroughSwiftData() async throws {
        let repository = try makeRepository()
        let artifact = richArtifact()

        try await repository.save(artifact)

        let stored = try await repository.artifacts()
        XCTAssertEqual(stored, [artifact])
    }

    func testBatchUpdateAndDeletePersist() async throws {
        let repository = try makeRepository()
        let first = Artifact(kind: .manual, originalText: "Forest trail")
        let second = Artifact(kind: .manual, originalText: "Historic market")
        try await repository.saveMany([first, second])
        let details = ArtifactUserDetails(
            summary: "A quiet trail through old-growth forest.",
            category: .sceneryAndNature,
            interests: ["Forests", "Hiking"]
        )
        let updatedFirst = first.withEditedDetails(details, note: "Go in autumn")
        let updatedSecond = second.withResolution(
            place: SavedPlace(
                id: "market-1",
                name: "Old Market",
                latitude: 41.0,
                longitude: -71.0,
                locality: "Providence",
                region: "Rhode Island",
                country: "United States"
            ),
            state: .processed
        )

        try await repository.updateMany([updatedFirst, updatedSecond])
        var stored = try await repository.artifacts()
        XCTAssertEqual(Set(stored), Set([updatedFirst, updatedSecond]))

        try await repository.deleteMany([updatedFirst.id])
        stored = try await repository.artifacts()
        XCTAssertEqual(stored, [updatedSecond])
    }

    func testBatchDeleteRollsBackWhenAnyArtifactIsMissing() async throws {
        let repository = try makeRepository()
        let first = Artifact(kind: .manual, originalText: "Keep both on failure")
        let second = Artifact(kind: .manual, originalText: "Also retained")
        try await repository.saveMany([first, second])

        do {
            try await repository.deleteMany([first.id, UUID()])
            XCTFail("Expected a missing artifact error")
        } catch {
            XCTAssertNotNil(error)
        }

        let stored = try await repository.artifacts()
        XCTAssertEqual(Set(stored), Set([first, second]))
    }

    func testSourceURLAndDiscoveredTitleUpdatesPersistAcrossReload() async throws {
        let repository = try makeRepository()
        let original = Artifact(
            kind: .url,
            sourceURL: "https://www.google.com/maps/place/Tea/data=!4m2",
            originalText: "Tea"
        )
        try await repository.save(original)

        let enrichedURL = "https://www.google.com/maps/place/Tea/data=!4m2?q=Tea%20House&ll=40.7,-73.9"
        let updated = original
            .withSourceURL(enrichedURL, processingState: .saved)
            .withOriginalText("Tea House Favorites")
        try await repository.update(updated)

        let artifacts = try await repository.artifacts()
        let stored = try XCTUnwrap(artifacts.first)
        XCTAssertEqual(stored.sourceURL, enrichedURL)
        XCTAssertEqual(stored.originalText, "Tea House Favorites")
        XCTAssertEqual(stored.processingState, .saved)
    }

    private func makeRepository() throws -> SwiftDataArtifactRepository {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: StoredArtifact.self, configurations: configuration)
        return SwiftDataArtifactRepository(context: ModelContext(container))
    }

    private func richArtifact() -> Artifact {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        return Artifact(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            kind: .photo,
            sourceURL: "https://example.com/coastal-trail",
            sourceCollectionTitle: "Coastal scenery",
            additionalSourceCollectionTitles: ["Weekend hikes"],
            originalText: "Coastal trail",
            userNote: "Rocky water views and seafood nearby",
            mediaKey: "photo.jpg",
            extractedText: "COASTAL TRAIL",
            extractedTextSource: .appleVision,
            textExtractionState: .processed,
            linkMetadata: ArtifactLinkMetadata(
                title: "Coastal Trail Guide",
                summary: "Cliffs, ocean views, and a historic lighthouse.",
                siteName: "Example",
                imageData: Data([0x01, 0x02, 0x03]),
                resolvedURL: "https://example.com/coastal-trail",
                fetchedAt: date
            ),
            linkMetadataState: .processed,
            place: SavedPlace(
                id: "coastal-trail-1",
                name: "Coastal Trail",
                latitude: 41.49,
                longitude: -71.31,
                locality: "Newport",
                region: "Rhode Island",
                country: "United States"
            ),
            enrichment: ArtifactEnrichment(
                summary: "A coastal hike with lighthouse views.",
                category: .sceneryAndNature,
                interests: ["Coast & water", "Hiking", "History"],
                source: .mapKitAndDetectedText,
                confidence: 0.9,
                generatedAt: date,
                interestEvidence: [
                    ArtifactInterestEvidence(interest: "Rocky coast", source: .userNote, confidence: 1)
                ]
            ),
            enrichmentState: .processed,
            userDetails: ArtifactUserDetails(
                summary: "A dramatic shoreline walk.",
                category: .sceneryAndNature,
                interests: ["Coast & water", "Hiking"]
            ),
            processingState: .processed,
            capturedAt: date
        )
    }
}
