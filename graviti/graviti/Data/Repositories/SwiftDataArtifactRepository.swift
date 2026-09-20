import Foundation
import SwiftData

@MainActor
final class SwiftDataArtifactRepository: ArtifactRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func save(_ artifact: Artifact) async throws {
        try await saveMany([artifact])
    }

    func saveMany(_ artifacts: [Artifact]) async throws {
        for artifact in artifacts {
            context.insert(StoredArtifact(artifact))
        }
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

    func update(_ artifact: Artifact) async throws {
        try await updateMany([artifact])
    }

    func updateMany(_ artifacts: [Artifact]) async throws {
        do {
            for artifact in artifacts {
                let id = artifact.id
                let descriptor = FetchDescriptor<StoredArtifact>(predicate: #Predicate { $0.id == id })
                guard let stored = try context.fetch(descriptor).first else {
                    throw ArtifactRepositoryError.notFound
                }
                try stored.applyResolution(artifact)
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func delete(_ id: UUID) async throws {
        try await deleteMany([id])
    }

    func deleteMany(_ ids: Set<UUID>) async throws {
        guard !ids.isEmpty else { return }
        do {
            for id in ids {
                let descriptor = FetchDescriptor<StoredArtifact>(predicate: #Predicate { $0.id == id })
                guard let stored = try context.fetch(descriptor).first else {
                    throw ArtifactRepositoryError.notFound
                }
                context.delete(stored)
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}

private enum ArtifactRepositoryError: LocalizedError {
    case notFound

    var errorDescription: String? { String(localized: "This save is no longer in the Library.") }
}
