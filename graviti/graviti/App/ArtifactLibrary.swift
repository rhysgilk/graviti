import Foundation
import SwiftUI
import Combine

@MainActor
final class ArtifactLibrary: ObservableObject {
    @Published private(set) var artifacts: [Artifact] = []
    @Published private(set) var loadError: String?

    private let repository: any ArtifactRepository

    init(repository: any ArtifactRepository) {
        self.repository = repository
    }

    func load() async {
        do {
            artifacts = try await repository.artifacts()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    func save(_ artifact: Artifact) async throws {
        try await repository.save(artifact)
        artifacts.insert(artifact, at: 0)
    }
}
