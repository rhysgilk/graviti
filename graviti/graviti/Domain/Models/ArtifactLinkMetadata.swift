import Foundation

struct ArtifactLinkMetadata: Codable, Hashable {
    let title: String?
    let summary: String?
    let siteName: String
    let imageData: Data?
    let resolvedURL: String
    let fetchedAt: Date
    let provenance: GeneratedDataProvenance?

    init(
        title: String?,
        summary: String?,
        siteName: String,
        imageData: Data?,
        resolvedURL: String,
        fetchedAt: Date,
        provenance: GeneratedDataProvenance? = nil
    ) {
        self.title = title
        self.summary = summary
        self.siteName = siteName
        self.imageData = imageData
        self.resolvedURL = resolvedURL
        self.fetchedAt = fetchedAt
        self.provenance = provenance
    }
}

enum ArtifactLinkMetadataState: String, Codable {
    case pending
    case processing
    case processed
    case unavailable
    case failed
}
