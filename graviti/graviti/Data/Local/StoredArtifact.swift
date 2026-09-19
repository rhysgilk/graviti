import Foundation
import SwiftData

@Model
final class StoredArtifact {
    @Attribute(.unique) var id: UUID
    var kindRawValue: String
    var sourceURL: String?
    var originalText: String?
    var userNote: String?
    var mediaKey: String?
    var placeJSON: Data?
    var enrichmentJSON: Data?
    var enrichmentStateRawValue: String?
    var userDetailsJSON: Data?
    var processingStateRawValue: String
    var capturedAt: Date

    @MainActor init(_ artifact: Artifact) {
        id = artifact.id
        kindRawValue = artifact.kind.rawValue
        sourceURL = artifact.sourceURL
        originalText = artifact.originalText
        userNote = artifact.userNote
        mediaKey = artifact.mediaKey
        placeJSON = try? artifact.place.map { try JSONEncoder().encode($0) }
        enrichmentJSON = try? artifact.enrichment.map { try JSONEncoder().encode($0) }
        enrichmentStateRawValue = artifact.enrichmentState.rawValue
        userDetailsJSON = try? artifact.userDetails.map { try JSONEncoder().encode($0) }
        processingStateRawValue = artifact.processingState.rawValue
        capturedAt = artifact.capturedAt
    }

    @MainActor func asArtifact() throws -> Artifact {
        guard let kind = ArtifactKind(rawValue: kindRawValue),
              let state = ArtifactProcessingState(rawValue: processingStateRawValue) else {
            throw StoredArtifactError.unknownValue
        }
        return Artifact(
            id: id,
            kind: kind,
            sourceURL: sourceURL,
            originalText: originalText,
            userNote: userNote,
            mediaKey: mediaKey,
            place: try placeJSON.map { try JSONDecoder().decode(SavedPlace.self, from: $0) },
            enrichment: enrichmentJSON.flatMap { try? JSONDecoder().decode(ArtifactEnrichment.self, from: $0) },
            enrichmentState: enrichmentState,
            userDetails: userDetailsJSON.flatMap { try? JSONDecoder().decode(ArtifactUserDetails.self, from: $0) },
            processingState: state,
            capturedAt: capturedAt
        )
    }

    @MainActor func applyResolution(_ artifact: Artifact) throws {
        placeJSON = try artifact.place.map { try JSONEncoder().encode($0) }
        enrichmentJSON = try artifact.enrichment.map { try JSONEncoder().encode($0) }
        enrichmentStateRawValue = artifact.enrichmentState.rawValue
        userDetailsJSON = try artifact.userDetails.map { try JSONEncoder().encode($0) }
        userNote = artifact.userNote
        processingStateRawValue = artifact.processingState.rawValue
    }

    private var enrichmentState: ArtifactEnrichmentState {
        enrichmentStateRawValue.flatMap(ArtifactEnrichmentState.init(rawValue:))
            ?? (enrichmentJSON == nil ? .pending : .processed)
    }
}

private enum StoredArtifactError: Error {
    case unknownValue
}
