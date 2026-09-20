import XCTest
@testable import graviti

final class ArtifactImportCoordinatorTests: XCTestCase {
    func testGooglePlanSkipsExistingAndRepeatedRows() throws {
        let existing = Artifact(
            kind: .url,
            sourceURL: "https://maps.google.com/?cid=1",
            originalText: "Existing",
            userNote: "Note"
        )
        let csv = """
        Title,URL,Note
        Existing,https://maps.google.com/?cid=1,Note
        New place,https://maps.google.com/?cid=2,Try lunch
        New place,https://maps.google.com/?cid=2,Try lunch
        """

        let plan = try ArtifactImportCoordinator.googleCSV(csv, existingArtifacts: [existing])

        XCTAssertEqual(plan.artifacts.count, 1)
        XCTAssertEqual(plan.artifacts.first?.originalText, "New place")
        XCTAssertEqual(plan.duplicates, 2)
        XCTAssertEqual(plan.skipped, 0)
    }

    func testMapsLinkPlanReturnsNilArtifactForExistingURL() throws {
        let rawURL = "https://maps.apple.com/?q=Acadia"
        let data = try PropertyListSerialization.data(
            fromPropertyList: ["URL": rawURL], format: .xml, options: 0
        )
        let existing = Artifact(kind: .url, sourceURL: rawURL, originalText: "Acadia")

        let plan = try ArtifactImportCoordinator.mapsLinkFile(data, existingArtifacts: [existing])

        XCTAssertEqual(plan.rawURL, rawURL)
        XCTAssertNil(plan.artifact)
    }
}
