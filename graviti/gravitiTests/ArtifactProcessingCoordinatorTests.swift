import XCTest
@testable import graviti

@MainActor
final class ArtifactProcessingCoordinatorTests: XCTestCase {
    func testMapsLinkIsEligibleForPlaceResolution() {
        let artifact = Artifact(kind: .url, sourceURL: "https://maps.apple.com/?q=Acadia")

        XCTAssertTrue(ArtifactProcessingCoordinator.shouldResolvePlace(artifact))
        XCTAssertFalse(ArtifactProcessingCoordinator.shouldResolvePlace(
            artifact.withResolution(place: nil, state: .needsReview)
        ))
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

    func testSavedContextIsEligibleForEnrichment() {
        let artifact = Artifact(kind: .manual, userNote: "Quiet forest trails")

        XCTAssertTrue(ArtifactProcessingCoordinator.shouldEnrich(artifact))
        XCTAssertFalse(ArtifactProcessingCoordinator.shouldEnrich(
            artifact.withEnrichmentState(.unavailable)
        ))
    }

    func testCollectionLinkIsNotEligibleForEnrichment() {
        let artifact = Artifact(
            kind: .url,
            sourceURL: "https://maps.apple.com/guides/weekend",
            originalText: "Weekend guide"
        )

        XCTAssertFalse(ArtifactProcessingCoordinator.shouldEnrich(artifact))
    }
}
