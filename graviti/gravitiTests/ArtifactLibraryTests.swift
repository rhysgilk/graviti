import XCTest
@testable import graviti

@MainActor
final class ArtifactLibraryTests: XCTestCase {
    func testOfflineMapFailureKeepsOriginalSaveVisible() async throws {
        let saved = Artifact(
            kind: .url,
            sourceURL: "https://maps.apple.com/?q=Acadia%20National%20Park",
            originalText: "Acadia National Park"
        )
        let repository = PreviewArtifactRepository()
        try await repository.save(saved)
        let resolver = MapPlaceResolver(
            searchProvider: OfflinePlaceSearchProvider(),
            linkExpander: IdentityMapLinkExpander()
        )
        let library = ArtifactLibrary(repository: repository, placeResolver: resolver)

        await library.load()
        await library.processPendingMaps()

        let retained = try XCTUnwrap(library.artifacts.first { $0.id == saved.id })
        XCTAssertEqual(retained.sourceURL, saved.sourceURL)
        XCTAssertEqual(retained.processingState, .failed)
        XCTAssertNil(library.loadError)
    }

    func testFailedMapLookupRetriesWhenProcessingResumes() async throws {
        let saved = Artifact(
            kind: .url,
            sourceURL: "https://maps.apple.com/?q=Acadia%20National%20Park",
            originalText: "Acadia National Park"
        )
        let repository = PreviewArtifactRepository()
        try await repository.save(saved)
        let expectedPlace = SavedPlace(
            id: "acadia",
            name: "Acadia National Park",
            latitude: 44.3386,
            longitude: -68.2733,
            locality: "Bar Harbor",
            region: "Maine",
            country: "United States"
        )
        let provider = RecoveringPlaceSearchProvider(place: expectedPlace)
        let resolver = MapPlaceResolver(
            searchProvider: provider,
            linkExpander: IdentityMapLinkExpander()
        )
        let library = ArtifactLibrary(repository: repository, placeResolver: resolver)

        await library.load()
        await library.processPendingMaps()
        XCTAssertEqual(library.artifacts.first?.processingState, .failed)

        await library.processPendingMaps()

        XCTAssertEqual(library.artifacts.first?.processingState, .processed)
        XCTAssertEqual(library.artifacts.first?.place, expectedPlace)
        XCTAssertEqual(provider.searchCount, 2)
    }

    func testUnavailableSharedInboxDoesNotHideLoadedLibrary() async throws {
        let saved = Artifact(kind: .manual, originalText: "Quiet forest trail")
        let repository = PreviewArtifactRepository()
        try await repository.save(saved)
        let library = ArtifactLibrary(
            repository: repository,
            sharedInbox: SharedArtifactInboxClient(
                pendingFiles: { throw TestInboxError.unavailable },
                read: { _ in throw TestInboxError.unavailable },
                remove: { _ in }
            )
        )

        await library.load()
        let imported = await library.importSharedArtifacts()

        XCTAssertEqual(imported, 0)
        XCTAssertEqual(library.artifacts.map(\.id), [saved.id])
        XCTAssertNil(library.loadError)
        XCTAssertEqual(library.shareImportError, TestInboxError.unavailable.localizedDescription)
    }

    func testDeleteArtifactsRemovesEverySelectedSaveFromLibraryAndRepository() async throws {
        let repository = PreviewArtifactRepository()
        let selected = [
            Artifact(kind: .manual),
            Artifact(kind: .manual),
            Artifact(kind: .manual)
        ]
        let retained = Artifact(kind: .manual)
        try await repository.saveMany(selected + [retained])
        let library = ArtifactLibrary(repository: repository)
        await library.load()

        try await library.deleteArtifacts(Set(selected.map(\.id)))

        XCTAssertEqual(library.artifacts.map(\.id), [retained.id])
        let persistedIDs = try await repository.artifacts().map(\.id)
        XCTAssertEqual(persistedIDs, [retained.id])
    }

    func testSavePlaceAddsExistingPlaceToFitGuideWithoutDuplicatingArtifact() async throws {
        let repository = PreviewArtifactRepository()
        let place = SavedPlace(
            id: "museum",
            name: "City Museum",
            latitude: 40.7,
            longitude: -74,
            locality: "New York",
            region: "New York",
            country: "United States"
        )
        let existing = Artifact(
            kind: .url,
            sourceURL: "https://maps.apple.com/?q=museum",
            originalText: place.name,
            place: place,
            processingState: .processed
        )
        try await repository.save(existing)
        let library = ArtifactLibrary(repository: repository)
        await library.load()

        try await library.savePlace(
            PlaceCandidate(place: place, sourceURL: "https://maps.apple.com/?q=museum"),
            sourceCollectionTitle: "New York City Fit Guide · Museums"
        )

        XCTAssertEqual(library.artifacts.count, 1)
        XCTAssertEqual(library.artifacts[0].sourceCollectionTitles, ["New York City Fit Guide · Museums"])
        let persisted = try await repository.artifacts()
        XCTAssertEqual(persisted.count, 1)
        XCTAssertEqual(persisted[0].sourceCollectionTitles, ["New York City Fit Guide · Museums"])
    }
}

private enum TestInboxError: LocalizedError {
    case unavailable

    var errorDescription: String? { "Shared inbox unavailable for this test." }
}

private struct OfflinePlaceSearchProvider: PlaceSearchProviding {
    func search(_ query: String) async throws -> [PlaceCandidate] {
        throw URLError(.notConnectedToInternet)
    }
}

@MainActor
private final class RecoveringPlaceSearchProvider: PlaceSearchProviding {
    let place: SavedPlace
    private(set) var searchCount = 0

    init(place: SavedPlace) {
        self.place = place
    }

    func search(_ query: String) async throws -> [PlaceCandidate] {
        searchCount += 1
        if searchCount == 1 { throw URLError(.notConnectedToInternet) }
        return [PlaceCandidate(place: place, sourceURL: "https://maps.apple.com/?q=Acadia")]
    }
}

private struct IdentityMapLinkExpander: MapLinkExpanding {
    func expandedURL(for rawURL: String) async -> String { rawURL }
}
