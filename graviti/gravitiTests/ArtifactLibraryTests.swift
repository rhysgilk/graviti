import XCTest
@testable import graviti

@MainActor
final class ArtifactLibraryTests: XCTestCase {
    func testUnmatchedInstagramPlaceAttemptDoesNotEnterNeedsReview() async throws {
        let url = "https://www.instagram.com/reel/example/"
        let saved = Artifact(
            kind: .url,
            sourceURL: url,
            originalText: "Boston sandwiches",
            linkMetadata: ArtifactLinkMetadata(
                title: "Boston sandwiches",
                summary: "Try this one 📍South End — @calistosdeli",
                siteName: "Instagram",
                imageData: nil,
                resolvedURL: url,
                fetchedAt: .now
            ),
            linkMetadataState: .processed
        )
        let repository = PreviewArtifactRepository()
        try await repository.save(saved)
        let resolver = MapPlaceResolver(
            searchProvider: EmptyPlaceSearchProvider(),
            linkExpander: IdentityMapLinkExpander()
        )
        let library = ArtifactLibrary(repository: repository, placeResolver: resolver)

        await library.load()
        await library.processPendingMaps()

        XCTAssertEqual(library.artifacts.first?.processingState, .processed)
        XCTAssertNil(library.artifacts.first?.place)
    }

    func testIncorrectInstagramCityMatchIsRepairedOnResume() async throws {
        let url = "https://www.instagram.com/reel/example/"
        let boston = SavedPlace(
            id: "boston",
            name: "Boston",
            latitude: 42.36,
            longitude: -71.06,
            locality: "Boston",
            region: "Massachusetts",
            country: "United States"
        )
        let josephine = SavedPlace(
            id: "josephine",
            name: "Josephine",
            latitude: 42.39,
            longitude: -71.10,
            locality: "Somerville",
            region: "Massachusetts",
            country: "United States"
        )
        let saved = Artifact(
            kind: .url,
            sourceURL: url,
            originalText: "Somerville steak and cheese",
            linkMetadata: ArtifactLinkMetadata(
                title: "Somerville steak and cheese",
                summary: "The prime rib melts in your mouth. 📍Josephine, Somerville, ma follow @bostoneatin for more Boston recs",
                siteName: "Instagram",
                imageData: nil,
                resolvedURL: url,
                fetchedAt: .now
            ),
            linkMetadataState: .processed,
            place: boston,
            processingState: .processed
        )
        let repository = PreviewArtifactRepository()
        try await repository.save(saved)
        let resolver = MapPlaceResolver(
            searchProvider: SinglePlaceSearchProvider(place: josephine),
            linkExpander: IdentityMapLinkExpander()
        )
        let library = ArtifactLibrary(repository: repository, placeResolver: resolver)

        await library.load()
        await library.processPendingMaps()

        XCTAssertEqual(library.artifacts.first?.processingState, .processed)
        XCTAssertEqual(library.artifacts.first?.place, josephine)
    }

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

    func testTransientMapFailureRetriesAutomaticallyInBackground() async throws {
        let saved = Artifact(
            kind: .url,
            sourceURL: "https://maps.apple.com/?q=Acadia%20National%20Park",
            originalText: "Acadia National Park"
        )
        let repository = PreviewArtifactRepository()
        try await repository.save(saved)
        let expectedPlace = SavedPlace(
            id: "acadia-background",
            name: "Acadia National Park",
            latitude: 44.3386,
            longitude: -68.2733,
            locality: "Bar Harbor",
            region: "Maine",
            country: "United States"
        )
        let provider = RecoveringPlaceSearchProvider(place: expectedPlace)
        let library = ArtifactLibrary(
            repository: repository,
            placeResolver: MapPlaceResolver(searchProvider: provider, linkExpander: IdentityMapLinkExpander())
        )
        await library.load()

        await library.processPendingMaps()
        XCTAssertEqual(library.artifacts.first?.processingState, .failed)

        for _ in 0..<30 where library.artifacts.first?.place == nil {
            try await Task.sleep(for: .milliseconds(100))
        }

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

    func testBackupRestoreReturnsExplorePreferencesAlongsideArtifacts() async throws {
        let preferences = LibraryBackupPreferences(
            recommendationRegion: RecommendationRegion.europe.rawValue,
            preferredInterests: ["Architecture", "Museums"],
            avoidedInterests: ["Beaches"],
            savedDestinationIDs: ["Copenhagen, Denmark"],
            excludedDestinationIDs: ["Madeira, Portugal"]
        )
        let source = Artifact(kind: .manual, originalText: "Historic architecture")
        let encoded = try LibraryBackupService.encode([source], preferences: preferences)
        let library = ArtifactLibrary(repository: PreviewArtifactRepository())

        let summary = try await library.restoreBackup(encoded)

        XCTAssertEqual(summary.imported, 1)
        XCTAssertEqual(summary.duplicates, 0)
        XCTAssertEqual(summary.preferences, preferences)
        XCTAssertEqual(library.artifacts.map(\.id), [source.id])
    }

    func testPlaceStatusPropagatesAcrossEverySaveForThePlace() async throws {
        let place = SavedPlace(
            id: "josephine",
            name: "Josephine",
            latitude: 42.39,
            longitude: -71.10,
            locality: "Somerville",
            region: "Massachusetts",
            country: "United States"
        )
        let first = Artifact(kind: .url, sourceURL: "https://example.com/one", place: place, processingState: .processed)
        let second = Artifact(kind: .manual, originalText: "Try the prime rib", place: place, processingState: .processed)
        let repository = PreviewArtifactRepository()
        try await repository.saveMany([first, second])
        let library = ArtifactLibrary(repository: repository)
        await library.load()

        try await library.setPlaceStatus(.loved, for: place.id)

        XCTAssertEqual(library.placeStatus(for: place.id), .loved)
        XCTAssertEqual(library.artifacts.compactMap { $0.userDetails?.placeStatus }, [.loved, .loved])
        let persisted = try await repository.artifacts()
        XCTAssertEqual(persisted.compactMap { $0.userDetails?.placeStatus }, [.loved, .loved])
    }

    func testSettingPlaceStatusPreservesGeneratedDetails() async throws {
        let place = SavedPlace(
            id: "park",
            name: "Acadia",
            latitude: 44.3,
            longitude: -68.2,
            locality: nil,
            region: "Maine",
            country: "United States"
        )
        let enrichment = ArtifactEnrichment(
            summary: "A rocky coastal national park.",
            category: .sceneryAndNature,
            interests: ["rocky coast", "national parks"],
            source: .savedText,
            confidence: 0.9,
            generatedAt: .now
        )
        let artifact = Artifact(kind: .url, place: place, enrichment: enrichment, enrichmentState: .processed, processingState: .processed)
        let repository = PreviewArtifactRepository()
        try await repository.save(artifact)
        let library = ArtifactLibrary(repository: repository)
        await library.load()

        try await library.setPlaceStatus(.shortlisted, for: place.id)

        XCTAssertEqual(library.artifacts[0].effectiveSummary, enrichment.summary)
        XCTAssertEqual(library.artifacts[0].effectiveCategory, enrichment.category)
        XCTAssertEqual(library.artifacts[0].effectiveInterests, enrichment.interests)
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

private struct EmptyPlaceSearchProvider: PlaceSearchProviding {
    func search(_ query: String) async throws -> [PlaceCandidate] { [] }
}

private struct SinglePlaceSearchProvider: PlaceSearchProviding {
    let place: SavedPlace

    func search(_ query: String) async throws -> [PlaceCandidate] {
        [PlaceCandidate(place: place, sourceURL: "https://maps.apple.com")]
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
