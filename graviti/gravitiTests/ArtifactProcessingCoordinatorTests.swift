import XCTest
@testable import graviti

@MainActor
final class ArtifactProcessingCoordinatorTests: XCTestCase {
    func testMapsLinkIsEligibleForPlaceResolution() {
        let artifact = Artifact(kind: .url, sourceURL: "https://maps.apple.com/?q=Acadia")

        XCTAssertTrue(ArtifactProcessingCoordinator.shouldResolvePlace(artifact))
        XCTAssertTrue(ArtifactProcessingCoordinator.shouldResolvePlace(
            artifact.withResolution(place: nil, state: .failed)
        ))
        XCTAssertFalse(ArtifactProcessingCoordinator.shouldResolvePlace(
            artifact.withResolution(place: nil, state: .needsReview)
        ))
    }

    func testInstagramBecomesEligibleWhenCaptionHasExplicitPlaceSignal() {
        let url = "https://www.instagram.com/reel/example/"
        let artifact = Artifact(kind: .url, sourceURL: url)
        XCTAssertFalse(ArtifactProcessingCoordinator.shouldResolvePlace(artifact))

        let withCaption = artifact.withLinkMetadata(
            ArtifactLinkMetadata(
                title: "Boston sandwiches",
                summary: "Worth a visit 📍South End — @calistosdeli 682 Tremont St Boston, MA 02118",
                siteName: "Instagram",
                imageData: nil,
                resolvedURL: url,
                fetchedAt: .now
            ),
            state: .processed
        )

        XCTAssertTrue(ArtifactProcessingCoordinator.shouldResolvePlace(withCaption))
    }

    func testPhotoWithStoredMediaIsEligibleForTextExtraction() {
        let artifact = Artifact(kind: .photo, mediaKey: "photo.jpg")

        XCTAssertTrue(ArtifactProcessingCoordinator.shouldExtractText(artifact))
        XCTAssertFalse(ArtifactProcessingCoordinator.shouldExtractText(
            artifact.withExtractedText(nil, source: nil, state: .unavailable)
        ))
    }

    func testURLIsEligibleForLinkMetadataUntilUnavailable() {
        let artifact = Artifact(kind: .url, sourceURL: "https://example.com/place")

        XCTAssertTrue(ArtifactProcessingCoordinator.shouldFetchLinkMetadata(artifact))
        XCTAssertFalse(ArtifactProcessingCoordinator.shouldFetchLinkMetadata(
            artifact.withLinkMetadata(nil, state: .unavailable)
        ))
    }

    func testLegacyInstagramMetadataIsRefetchedForCleanup() {
        let artifact = Artifact(
            kind: .url,
            sourceURL: "https://www.instagram.com/reel/example/",
            linkMetadata: ArtifactLinkMetadata(
                title: "Creator on Instagram: \"A useful caption\"",
                summary: "1,287 likes, 46 comments - creator on August 18, 2026: \"A useful caption\"",
                siteName: "Instagram",
                imageData: nil,
                resolvedURL: "https://www.instagram.com/reel/example/",
                fetchedAt: .now
            ),
            linkMetadataState: .processed
        )

        XCTAssertTrue(ArtifactProcessingCoordinator.shouldFetchLinkMetadata(artifact))
        XCTAssertFalse(ArtifactProcessingCoordinator.shouldFetchLinkMetadata(
            artifact.withLinkMetadata(
                ArtifactLinkMetadata(
                    title: "A useful caption",
                    summary: "A useful caption about a Boston restaurant.",
                    siteName: "Instagram",
                    imageData: nil,
                    resolvedURL: "https://www.instagram.com/reel/example/",
                    fetchedAt: .now
                ),
                state: .processed
            )
        ))
    }

    func testSavedContextIsEligibleForEnrichment() {
        let artifact = Artifact(kind: .manual, userNote: "Quiet forest trails")

        XCTAssertTrue(ArtifactProcessingCoordinator.shouldEnrich(artifact))
        XCTAssertFalse(ArtifactProcessingCoordinator.shouldEnrich(
            artifact.withEnrichmentState(.unavailable)
        ))
    }

    func testURLWaitsForLinkDetailsBeforeEnrichment() {
        let artifact = Artifact(
            kind: .url,
            sourceURL: "https://www.instagram.com/reel/example/",
            originalText: "Instagram reel"
        )

        XCTAssertFalse(ArtifactProcessingCoordinator.shouldEnrich(artifact))
        XCTAssertTrue(ArtifactProcessingCoordinator.shouldEnrich(
            artifact.withLinkMetadata(
                ArtifactLinkMetadata(
                    title: "Boston sandwich shop",
                    summary: "Crispy chicken sandwiches in Boston.",
                    siteName: "Instagram",
                    imageData: nil,
                    resolvedURL: "https://www.instagram.com/reel/example/",
                    fetchedAt: .now
                ),
                state: .processed
            )
        ))
    }

    func testCollectionLinkIsNotEligibleForEnrichment() {
        let artifact = Artifact(
            kind: .url,
            sourceURL: "https://maps.apple.com/guides/weekend",
            originalText: "Weekend guide"
        )

        XCTAssertFalse(ArtifactProcessingCoordinator.shouldEnrich(artifact))
        XCTAssertFalse(ArtifactProcessingCoordinator.isResolvedMapCollection(artifact))
        XCTAssertTrue(ArtifactProcessingCoordinator.isResolvedMapCollection(
            artifact.withResolution(place: nil, state: .processed)
        ))
    }
}
