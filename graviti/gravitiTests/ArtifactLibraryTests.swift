import XCTest
@testable import graviti

@MainActor
final class ArtifactLibraryTests: XCTestCase {
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
