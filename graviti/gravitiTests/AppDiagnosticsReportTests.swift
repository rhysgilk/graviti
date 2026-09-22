import XCTest
@testable import graviti

final class AppDiagnosticsReportTests: XCTestCase {
    func testReportUsesAggregateStateCounts() {
        let place = SavedPlace(
            id: "private-place-id",
            name: "Private place",
            latitude: 41.8,
            longitude: -71.4,
            locality: "Private city",
            region: "Private region",
            country: "United States"
        )
        let artifacts = [
            Artifact(kind: .url, sourceURL: "https://secret.example", originalText: "Private note", place: place, processingState: .processed),
            Artifact(kind: .photo, mediaKey: "private.jpg", processingState: .needsReview),
            Artifact(kind: .manual, processingState: .failed),
            Artifact(kind: .manual, processingState: .processing)
        ]

        let report = AppDiagnosticsReport(
            artifacts: artifacts,
            appVersion: "1.2",
            buildNumber: "34",
            operatingSystem: "iOS Test",
            deviceFamily: "iPhone",
            backupSchemaVersion: 3,
            destinationCatalogVersion: "catalog-test"
        )

        XCTAssertEqual(report.savedItemCount, 4)
        XCTAssertEqual(report.distinctPlaceCount, 1)
        XCTAssertEqual(report.needsReviewCount, 1)
        XCTAssertEqual(report.failedProcessingCount, 1)
        XCTAssertEqual(report.pendingProcessingCount, 1)
        XCTAssertEqual(report.photoCount, 1)
        XCTAssertTrue(report.text.contains("App: 1.2 (34)"))
        XCTAssertTrue(report.text.contains("Destination catalog: catalog-test"))
    }

    func testReportExcludesSavedContentAndIdentifiers() {
        let privateID = UUID()
        let artifact = Artifact(
            id: privateID,
            kind: .url,
            sourceURL: "https://private.example/secret",
            sourceCollectionTitle: "Private collection",
            originalText: "Secret itinerary",
            userNote: "Do not share",
            mediaKey: "private-photo.jpg"
        )
        let report = AppDiagnosticsReport(
            artifacts: [artifact],
            appVersion: "1",
            buildNumber: "1",
            operatingSystem: "iOS Test",
            deviceFamily: "iPhone"
        ).text

        XCTAssertFalse(report.contains(privateID.uuidString))
        XCTAssertFalse(report.contains("private.example"))
        XCTAssertFalse(report.contains("Private collection"))
        XCTAssertFalse(report.contains("Secret itinerary"))
        XCTAssertFalse(report.contains("Do not share"))
        XCTAssertFalse(report.contains("private-photo.jpg"))
    }
}
