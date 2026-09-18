import Foundation
import SwiftData

@Model
final class StoredArtifact {
    @Attribute(.unique) var id: UUID
    var kindRawValue: String
    var sourceURL: String?
    var originalText: String?
    var userNote: String?
    var processingStateRawValue: String
    var capturedAt: Date

    init(_ artifact: Artifact) {
        id = artifact.id
        kindRawValue = artifact.kind.rawValue
        sourceURL = artifact.sourceURL
        originalText = artifact.originalText
        userNote = artifact.userNote
        processingStateRawValue = artifact.processingState.rawValue
        capturedAt = artifact.capturedAt
    }

    func asArtifact() throws -> Artifact {
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
            processingState: state,
            capturedAt: capturedAt
        )
    }
}

private enum StoredArtifactError: Error {
    case unknownValue
}
