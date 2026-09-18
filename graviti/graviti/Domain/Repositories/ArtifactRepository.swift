import Foundation

@MainActor
protocol ArtifactRepository {
    func save(_ artifact: Artifact) async throws
    func saveMany(_ artifacts: [Artifact]) async throws
    func artifacts() async throws -> [Artifact]
}
