import Foundation

@MainActor
final class ArtifactProcessingCoordinator {
    private let placeResolver: MapPlaceResolver
    private var resolvingIDs: Set<UUID> = []
    private var enrichingIDs: Set<UUID> = []
    private var extractingTextIDs: Set<UUID> = []
    private var fetchingLinkMetadataIDs: Set<UUID> = []

    init(placeResolver: MapPlaceResolver) {
        self.placeResolver = placeResolver
    }

    static func shouldResolvePlace(_ artifact: Artifact) -> Bool {
        [.saved, .failed].contains(artifact.processingState) && artifact.place == nil &&
            artifact.sourceURL.map { MapLinkMetadata.provider(for: $0) != nil } == true
    }

    static func isResolvedMapCollection(_ artifact: Artifact) -> Bool {
        artifact.processingState == .processed && artifact.place == nil &&
            artifact.sourceURL.map { MapLinkMetadata.provider(for: $0) != nil } == true
    }

    static func shouldEnrich(_ artifact: Artifact) -> Bool {
        artifact.enrichment == nil &&
            [.pending, .processing, .failed].contains(artifact.enrichmentState) &&
            (artifact.place != nil || artifact.originalText != nil || artifact.userNote != nil || artifact.extractedText != nil || artifact.linkMetadata != nil) &&
            artifact.sourceURL.map(MapLinkMetadata.isCollectionLink) != true
    }

    static func shouldExtractText(_ artifact: Artifact) -> Bool {
        artifact.kind == .photo && artifact.mediaKey != nil &&
            [.pending, .failed].contains(artifact.textExtractionState)
    }

    static func shouldFetchLinkMetadata(_ artifact: Artifact) -> Bool {
        artifact.kind == .url && artifact.sourceURL != nil &&
            [.pending, .failed].contains(artifact.linkMetadataState)
    }

    func isResolving(_ id: UUID) -> Bool {
        resolvingIDs.contains(id)
    }

    func beginResolving(_ id: UUID) -> Bool {
        resolvingIDs.insert(id).inserted
    }

    func finishResolving(_ id: UUID) {
        resolvingIDs.remove(id)
    }

    func beginEnriching(_ id: UUID) -> Bool {
        enrichingIDs.insert(id).inserted
    }

    func finishEnriching(_ id: UUID) {
        enrichingIDs.remove(id)
    }

    func beginExtractingText(_ id: UUID) -> Bool {
        extractingTextIDs.insert(id).inserted
    }

    func finishExtractingText(_ id: UUID) {
        extractingTextIDs.remove(id)
    }

    func beginFetchingLinkMetadata(_ id: UUID) -> Bool {
        fetchingLinkMetadataIDs.insert(id).inserted
    }

    func finishFetchingLinkMetadata(_ id: UUID) {
        fetchingLinkMetadataIDs.remove(id)
    }

    func resolvePlace(for artifact: Artifact) async throws -> MapPlaceResolution {
        try await placeResolver.resolve(artifact)
    }

    func fetchLinkMetadata(for rawURL: String) async throws -> ArtifactLinkMetadata? {
        try await LinkMetadataFetcher().fetch(rawURL)
    }

    func extractText(for mediaKey: String) async throws -> String? {
        let imageURL = try SharedMediaStore.url(for: mediaKey)
        return try await VisionTextRecognizer().recognizeText(at: imageURL)
    }

    func enrich(_ artifact: Artifact) async throws -> ArtifactEnrichment? {
        try await ArtifactEnricher().enrich(artifact)
    }
}
