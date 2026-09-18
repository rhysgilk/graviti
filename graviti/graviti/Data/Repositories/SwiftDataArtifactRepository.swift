import Foundation
import SwiftData

@MainActor
final class SwiftDataArtifactRepository: ArtifactRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func save(_ artifact: Artifact) async throws {
        context.insert(StoredArtifact(artifact))
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func artifacts() async throws -> [Artifact] {
        let descriptor = FetchDescriptor<StoredArtifact>(
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { try $0.asArtifact() }
    }
}
