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

    func update(_ artifact: Artifact) async throws {
        guard let index = stored.firstIndex(where: { $0.id == artifact.id }) else { return }
        stored[index] = artifact
    }

    func updateMany(_ artifacts: [Artifact]) async throws {
        for artifact in artifacts { try await update(artifact) }
    }

    func delete(_ id: UUID) async throws {
        try await deleteMany([id])
    }

    func deleteMany(_ ids: Set<UUID>) async throws {
        stored.removeAll { ids.contains($0.id) }
    }
}
