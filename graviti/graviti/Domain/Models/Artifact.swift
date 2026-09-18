import Foundation

enum ArtifactKind: String, Codable, CaseIterable {
    case url
    case manual
}

enum ArtifactProcessingState: String, Codable {
    case saved
    case processing
    case processed
    case needsReview
    case failed
}

struct Artifact: Identifiable, Hashable {
    let id: UUID
    let kind: ArtifactKind
    let sourceURL: String?
    let originalText: String?
    let userNote: String?
    let processingState: ArtifactProcessingState
    let capturedAt: Date

    init(
        id: UUID = UUID(),
        kind: ArtifactKind,
        sourceURL: String? = nil,
        originalText: String? = nil,
        userNote: String? = nil,
        processingState: ArtifactProcessingState = .saved,
        capturedAt: Date = .now
    ) {
        self.id = id
        self.kind = kind
        self.sourceURL = sourceURL
        self.originalText = originalText
        self.userNote = userNote
        self.processingState = processingState
        self.capturedAt = capturedAt
    }
}
