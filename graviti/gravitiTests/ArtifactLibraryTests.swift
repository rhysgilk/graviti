import XCTest
@testable import graviti

@MainActor
final class ArtifactLibraryTests: XCTestCase {
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
}

private enum TestInboxError: LocalizedError {
    case unavailable

    var errorDescription: String? { "Shared inbox unavailable for this test." }
}
