import Foundation

struct ArtifactLinkMetadata: Codable, Hashable {
    let title: String?
    let summary: String?
    let siteName: String
    let imageData: Data?
    let resolvedURL: String
    let fetchedAt: Date
}

enum ArtifactLinkMetadataState: String, Codable {
    case pending
    case processing
    case processed
    case unavailable
    case failed
}
