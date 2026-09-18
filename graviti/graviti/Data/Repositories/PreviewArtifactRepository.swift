import Foundation

@MainActor
final class PreviewArtifactRepository: ArtifactRepository {
    private var stored: [Artifact] = []

    func save(_ artifact: Artifact) async throws {
        stored.insert(artifact, at: 0)
    }

    func artifacts() async throws -> [Artifact] {
        stored
    }
}
