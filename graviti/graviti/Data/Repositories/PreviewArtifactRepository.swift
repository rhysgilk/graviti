import Foundation

@MainActor
final class PreviewArtifactRepository: ArtifactRepository {
    private var stored: [Artifact] = []

    func save(_ artifact: Artifact) async throws {
        try await saveMany([artifact])
    }

    func saveMany(_ artifacts: [Artifact]) async throws {
        stored.insert(contentsOf: artifacts, at: 0)
    }

    func artifacts() async throws -> [Artifact] {
        stored
    }
}
