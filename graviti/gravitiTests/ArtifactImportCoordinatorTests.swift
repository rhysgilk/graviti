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

    func testGoogleMapsListPlanPreservesNotesAndSkipsExistingPlaces() throws {
        let existingPlace = GoogleMapsListPlace(
            title: "Existing",
            address: "1 Main St",
            note: nil,
            latitude: 1,
            longitude: 2,
            featureIdentifiers: ["1", "2"]
        )
        let newPlace = GoogleMapsListPlace(
            title: "New place",
            address: "2 Main St",
            note: "Scenic roof",
            latitude: 3,
            longitude: 4,
            featureIdentifiers: ["3", "4"]
        )
        var legacyComponents = try XCTUnwrap(URLComponents(string: existingPlace.sourceURL))
        legacyComponents.queryItems = nil
        let existing = Artifact(
            kind: .url,
            sourceURL: legacyComponents.url?.absoluteString,
            originalText: existingPlace.title
        )

        let plan = ArtifactImportCoordinator.googleMapsList(
            GoogleMapsList(title: "Shared list", places: [existingPlace, newPlace]),
            existingArtifacts: [existing]
        )

        XCTAssertEqual(plan.title, "Shared list")
        XCTAssertEqual(plan.duplicates, 1)
        XCTAssertEqual(plan.artifacts.count, 1)
        XCTAssertEqual(plan.artifacts.first?.originalText, "New place")
        XCTAssertEqual(plan.artifacts.first?.userNote, "Scenic roof")
        XCTAssertEqual(plan.updatedArtifacts.count, 1)
        XCTAssertEqual(plan.updatedArtifacts.first?.id, existing.id)
        XCTAssertEqual(plan.updatedArtifacts.first?.sourceURL, existingPlace.sourceURL)
        XCTAssertEqual(plan.updatedArtifacts.first?.processingState, .saved)
        XCTAssertEqual(existingPlace.importIdentity, legacyComponents.url?.absoluteString)
    }

    func testGoogleMapsListDoesNotRefreshAUserMatchedPlace() throws {
        let place = GoogleMapsListPlace(
            title: "Tea House",
            address: "1 Main St",
            note: nil,
            latitude: 1,
            longitude: 2,
            featureIdentifiers: ["1", "2"]
        )
        var legacyComponents = try XCTUnwrap(URLComponents(string: place.sourceURL))
        legacyComponents.queryItems = nil
        let matchedPlace = SavedPlace(
            id: "user-match",
            name: "Tea House",
            latitude: 1,
            longitude: 2,
            locality: "Boston",
            region: "Massachusetts",
            country: "United States"
        )
        let existing = Artifact(
            kind: .url,
            sourceURL: legacyComponents.url?.absoluteString,
            originalText: place.title,
            place: matchedPlace,
            processingState: .processed
        )

        let plan = ArtifactImportCoordinator.googleMapsList(
            GoogleMapsList(title: "Shared list", places: [place]),
            existingArtifacts: [existing]
        )

        XCTAssertEqual(plan.duplicates, 1)
        XCTAssertTrue(plan.artifacts.isEmpty)
        XCTAssertTrue(plan.updatedArtifacts.isEmpty)
    }
}
