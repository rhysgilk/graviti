import Foundation

enum ArtifactKind: String, Codable, CaseIterable {
    case url
    case manual
    case photo
}

enum ArtifactProcessingState: String, Codable {
    case saved
    case processing
    case processed
    case needsReview
    case failed
}

enum ArtifactEnrichmentState: String, Codable {
    case pending
    case processing
    case processed
    case unavailable
    case failed
}

enum ArtifactTextExtractionState: String, Codable {
    case pending
    case processing
    case processed
    case unavailable
    case failed
}

enum ArtifactTextSource: String, Codable {
    case appleVision

    var displayName: String {
        switch self {
        case .appleVision: String(localized: "Text detected on this device")
        }
    }
}

struct Artifact: Identifiable, Hashable, Codable {
    let id: UUID
    let kind: ArtifactKind
    let sourceURL: String?
    let originalText: String?
    let userNote: String?
    let mediaKey: String?
    let extractedText: String?
    let extractedTextSource: ArtifactTextSource?
    let textExtractionState: ArtifactTextExtractionState
    let linkMetadata: ArtifactLinkMetadata?
    let linkMetadataState: ArtifactLinkMetadataState
    let place: SavedPlace?
    let enrichment: ArtifactEnrichment?
    let enrichmentState: ArtifactEnrichmentState
    let userDetails: ArtifactUserDetails?
    let processingState: ArtifactProcessingState
    let capturedAt: Date

    init(
        id: UUID = UUID(),
        kind: ArtifactKind,
        sourceURL: String? = nil,
        originalText: String? = nil,
        userNote: String? = nil,
        mediaKey: String? = nil,
        extractedText: String? = nil,
        extractedTextSource: ArtifactTextSource? = nil,
        textExtractionState: ArtifactTextExtractionState = .pending,
        linkMetadata: ArtifactLinkMetadata? = nil,
        linkMetadataState: ArtifactLinkMetadataState = .pending,
        place: SavedPlace? = nil,
        enrichment: ArtifactEnrichment? = nil,
        enrichmentState: ArtifactEnrichmentState = .pending,
        userDetails: ArtifactUserDetails? = nil,
        processingState: ArtifactProcessingState = .saved,
        capturedAt: Date = .now
    ) {
        self.id = id
        self.kind = kind
        self.sourceURL = sourceURL
        self.originalText = originalText
        self.userNote = userNote
        self.mediaKey = mediaKey
        self.extractedText = extractedText
        self.extractedTextSource = extractedTextSource
        self.textExtractionState = textExtractionState
        self.linkMetadata = linkMetadata
        self.linkMetadataState = linkMetadataState
        self.place = place
        self.enrichment = enrichment
        self.enrichmentState = enrichmentState
        self.userDetails = userDetails
        self.processingState = processingState
        self.capturedAt = capturedAt
    }

    func withResolution(place: SavedPlace?, state: ArtifactProcessingState) -> Artifact {
        Artifact(
            id: id,
            kind: kind,
            sourceURL: sourceURL,
            originalText: originalText,
            userNote: userNote,
            mediaKey: mediaKey,
            extractedText: extractedText,
            extractedTextSource: extractedTextSource,
            textExtractionState: textExtractionState,
            linkMetadata: linkMetadata,
            linkMetadataState: linkMetadataState,
            place: place,
            enrichment: place?.id == self.place?.id ? enrichment : nil,
            enrichmentState: place?.id == self.place?.id ? enrichmentState : .pending,
            userDetails: userDetails,
            processingState: state,
            capturedAt: capturedAt
        )
    }

    func withEnrichment(_ enrichment: ArtifactEnrichment) -> Artifact {
        Artifact(
            id: id,
            kind: kind,
            sourceURL: sourceURL,
            originalText: originalText,
            userNote: userNote,
            mediaKey: mediaKey,
            extractedText: extractedText,
            extractedTextSource: extractedTextSource,
            textExtractionState: textExtractionState,
            linkMetadata: linkMetadata,
            linkMetadataState: linkMetadataState,
            place: place,
            enrichment: enrichment,
            enrichmentState: .processed,
            userDetails: userDetails,
            processingState: processingState,
            capturedAt: capturedAt
        )
    }

    func withEditedDetails(_ details: ArtifactUserDetails?, note: String?) -> Artifact {
        Artifact(
            id: id,
            kind: kind,
            sourceURL: sourceURL,
            originalText: originalText,
            userNote: note,
            mediaKey: mediaKey,
            extractedText: extractedText,
            extractedTextSource: extractedTextSource,
            textExtractionState: textExtractionState,
            linkMetadata: linkMetadata,
            linkMetadataState: linkMetadataState,
            place: place,
            enrichment: enrichment,
            enrichmentState: enrichmentState,
            userDetails: details,
            processingState: processingState,
            capturedAt: capturedAt
        )
    }

    func withEnrichmentState(_ state: ArtifactEnrichmentState) -> Artifact {
        Artifact(
            id: id,
            kind: kind,
            sourceURL: sourceURL,
            originalText: originalText,
            userNote: userNote,
            mediaKey: mediaKey,
            extractedText: extractedText,
            extractedTextSource: extractedTextSource,
            textExtractionState: textExtractionState,
            linkMetadata: linkMetadata,
            linkMetadataState: linkMetadataState,
            place: place,
            enrichment: enrichment,
            enrichmentState: state,
            userDetails: userDetails,
            processingState: processingState,
            capturedAt: capturedAt
        )
    }

    func withExtractedText(
        _ text: String?,
        source: ArtifactTextSource?,
        state: ArtifactTextExtractionState
    ) -> Artifact {
        Artifact(
            id: id,
            kind: kind,
            sourceURL: sourceURL,
            originalText: originalText,
            userNote: userNote,
            mediaKey: mediaKey,
            extractedText: text,
            extractedTextSource: source,
            textExtractionState: state,
            linkMetadata: linkMetadata,
            linkMetadataState: linkMetadataState,
            place: place,
            enrichment: text == extractedText ? enrichment : nil,
            enrichmentState: text == extractedText ? enrichmentState : .pending,
            userDetails: userDetails,
            processingState: processingState,
            capturedAt: capturedAt
        )
    }

    func withLinkMetadata(_ metadata: ArtifactLinkMetadata?, state: ArtifactLinkMetadataState) -> Artifact {
        Artifact(
            id: id,
            kind: kind,
            sourceURL: sourceURL,
            originalText: originalText,
            userNote: userNote,
            mediaKey: mediaKey,
            extractedText: extractedText,
            extractedTextSource: extractedTextSource,
            textExtractionState: textExtractionState,
            linkMetadata: metadata,
            linkMetadataState: state,
            place: place,
            enrichment: metadata == linkMetadata ? enrichment : nil,
            enrichmentState: metadata == linkMetadata ? enrichmentState : .pending,
            userDetails: userDetails,
            processingState: processingState,
            capturedAt: capturedAt
        )
    }

    func withSourceURL(_ sourceURL: String, processingState: ArtifactProcessingState) -> Artifact {
        Artifact(
            id: id,
            kind: kind,
            sourceURL: sourceURL,
            originalText: originalText,
            userNote: userNote,
            mediaKey: mediaKey,
            extractedText: extractedText,
            extractedTextSource: extractedTextSource,
            textExtractionState: textExtractionState,
            linkMetadata: linkMetadata,
            linkMetadataState: linkMetadataState,
            place: place,
            enrichment: enrichment,
            enrichmentState: enrichmentState,
            userDetails: userDetails,
            processingState: processingState,
            capturedAt: capturedAt
        )
    }

    func withMediaKey(_ mediaKey: String?) -> Artifact {
        Artifact(
            id: id,
            kind: kind,
            sourceURL: sourceURL,
            originalText: originalText,
            userNote: userNote,
            mediaKey: mediaKey,
            extractedText: extractedText,
            extractedTextSource: extractedTextSource,
            textExtractionState: textExtractionState,
            linkMetadata: linkMetadata,
            linkMetadataState: linkMetadataState,
            place: place,
            enrichment: enrichment,
            enrichmentState: enrichmentState,
            userDetails: userDetails,
            processingState: processingState,
            capturedAt: capturedAt
        )
    }

    var effectiveSummary: String? { userDetails == nil ? enrichment?.summary : userDetails?.summary }
    var effectiveCategory: ExperienceCategory? { userDetails == nil ? enrichment?.category : userDetails?.category }
    var effectiveInterests: [String] { userDetails?.interests ?? enrichment?.interests ?? [] }
}
