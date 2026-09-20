import Foundation
import SwiftData

@Model
final class StoredArtifact {
    @Attribute(.unique) var id: UUID
    var kindRawValue: String
    var sourceURL: String?
    var sourceCollectionTitle: String?
    var additionalSourceCollectionTitlesJSON: Data?
    var originalText: String?
    var userNote: String?
    var mediaKey: String?
    var extractedText: String?
    var extractedTextSourceRawValue: String?
    var textExtractionStateRawValue: String?
    var linkMetadataJSON: Data?
    var linkMetadataStateRawValue: String?
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
        sourceCollectionTitle = artifact.sourceCollectionTitle
        additionalSourceCollectionTitlesJSON = try? artifact.additionalSourceCollectionTitles.map {
            try JSONEncoder().encode($0)
        }
        originalText = artifact.originalText
        userNote = artifact.userNote
        mediaKey = artifact.mediaKey
        extractedText = artifact.extractedText
        extractedTextSourceRawValue = artifact.extractedTextSource?.rawValue
        textExtractionStateRawValue = artifact.textExtractionState.rawValue
        linkMetadataJSON = try? artifact.linkMetadata.map { try JSONEncoder().encode($0) }
        linkMetadataStateRawValue = artifact.linkMetadataState.rawValue
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
            sourceCollectionTitle: sourceCollectionTitle,
            additionalSourceCollectionTitles: additionalSourceCollectionTitlesJSON.flatMap {
                try? JSONDecoder().decode([String].self, from: $0)
            },
            originalText: originalText,
            userNote: userNote,
            mediaKey: mediaKey,
            extractedText: extractedText,
            extractedTextSource: extractedTextSourceRawValue.flatMap(ArtifactTextSource.init(rawValue:)),
            textExtractionState: textExtractionState,
            linkMetadata: linkMetadataJSON.flatMap { try? JSONDecoder().decode(ArtifactLinkMetadata.self, from: $0) },
            linkMetadataState: linkMetadataState,
            place: try placeJSON.map { try JSONDecoder().decode(SavedPlace.self, from: $0) },
            enrichment: enrichmentJSON.flatMap { try? JSONDecoder().decode(ArtifactEnrichment.self, from: $0) },
            enrichmentState: enrichmentState,
            userDetails: userDetailsJSON.flatMap { try? JSONDecoder().decode(ArtifactUserDetails.self, from: $0) },
            processingState: state,
            capturedAt: capturedAt
        )
    }

    @MainActor func apply(_ artifact: Artifact) throws {
        sourceURL = artifact.sourceURL
        sourceCollectionTitle = artifact.sourceCollectionTitle
        additionalSourceCollectionTitlesJSON = try artifact.additionalSourceCollectionTitles.map {
            try JSONEncoder().encode($0)
        }
        originalText = artifact.originalText
        placeJSON = try artifact.place.map { try JSONEncoder().encode($0) }
        enrichmentJSON = try artifact.enrichment.map { try JSONEncoder().encode($0) }
        enrichmentStateRawValue = artifact.enrichmentState.rawValue
        userDetailsJSON = try artifact.userDetails.map { try JSONEncoder().encode($0) }
        userNote = artifact.userNote
        extractedText = artifact.extractedText
        extractedTextSourceRawValue = artifact.extractedTextSource?.rawValue
        textExtractionStateRawValue = artifact.textExtractionState.rawValue
        linkMetadataJSON = try artifact.linkMetadata.map { try JSONEncoder().encode($0) }
        linkMetadataStateRawValue = artifact.linkMetadataState.rawValue
        processingStateRawValue = artifact.processingState.rawValue
    }

    private var enrichmentState: ArtifactEnrichmentState {
        enrichmentStateRawValue.flatMap(ArtifactEnrichmentState.init(rawValue:))
            ?? (enrichmentJSON == nil ? .pending : .processed)
    }

    private var textExtractionState: ArtifactTextExtractionState {
        textExtractionStateRawValue.flatMap(ArtifactTextExtractionState.init(rawValue:))
            ?? (mediaKey == nil ? .unavailable : (extractedText == nil ? .pending : .processed))
    }

    private var linkMetadataState: ArtifactLinkMetadataState {
        linkMetadataStateRawValue.flatMap(ArtifactLinkMetadataState.init(rawValue:))
            ?? (sourceURL == nil ? .unavailable : (linkMetadataJSON == nil ? .pending : .processed))
    }
}

private enum StoredArtifactError: Error {
    case unknownValue
}
