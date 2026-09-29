import Foundation

@MainActor
final class ArtifactProcessingCoordinator {
    private let placeResolver: MapPlaceResolver
    private let linkMetadataProvider: any LinkMetadataProviding
    private var resolvingIDs: Set<UUID> = []
    private var enrichingIDs: Set<UUID> = []
    private var extractingTextIDs: Set<UUID> = []
    private var fetchingLinkMetadataIDs: Set<UUID> = []

    init(
        placeResolver: MapPlaceResolver,
        linkMetadataProvider: (any LinkMetadataProviding)? = nil
    ) {
        self.placeResolver = placeResolver
        self.linkMetadataProvider = linkMetadataProvider ?? LinkMetadataFetcher()
    }

    static func shouldResolvePlace(_ artifact: Artifact) -> Bool {
        [.saved, .failed].contains(artifact.processingState) && artifact.place == nil &&
            isPlaceResolutionSource(artifact)
    }

    static func isPlaceResolutionSource(_ artifact: Artifact) -> Bool {
        artifact.sourceURL.map { MapLinkMetadata.provider(for: $0) != nil } == true ||
            SocialPlaceHintExtractor.hint(for: artifact) != nil
    }

    static func isSocialPlaceResolutionSource(_ artifact: Artifact) -> Bool {
        guard let sourceURL = artifact.sourceURL,
              MapLinkMetadata.provider(for: sourceURL) == nil else { return false }
        return SocialPlaceHintExtractor.hint(for: artifact) != nil
    }

    static func shouldRepairSocialPlace(_ artifact: Artifact) -> Bool {
        guard let place = artifact.place,
              let hint = SocialPlaceHintExtractor.hint(for: artifact) else { return false }
        return !SocialPlaceHintExtractor.namesAreCompatible(hint.expectedName, place.name)
    }

    static func isResolvedMapCollection(_ artifact: Artifact) -> Bool {
        artifact.processingState == .processed && artifact.place == nil &&
            artifact.sourceURL.map { MapLinkMetadata.provider(for: $0) != nil } == true
    }

    static func shouldEnrich(_ artifact: Artifact) -> Bool {
        let linkDetailsReady = artifact.kind != .url || artifact.sourceURL == nil ||
            ![.pending, .processing].contains(artifact.linkMetadataState)
        return linkDetailsReady && artifact.enrichment == nil &&
            [.pending, .processing, .failed].contains(artifact.enrichmentState) &&
            (artifact.place != nil || artifact.originalText != nil || artifact.userNote != nil || artifact.extractedText != nil || artifact.linkMetadata != nil) &&
            artifact.sourceURL.map(MapLinkMetadata.isCollectionLink) != true
    }

    static func shouldExtractText(_ artifact: Artifact) -> Bool {
        artifact.kind == .photo && artifact.mediaKey != nil &&
            [.pending, .failed].contains(artifact.textExtractionState)
    }

    static func shouldFetchLinkMetadata(_ artifact: Artifact) -> Bool {
        guard artifact.kind == .url, let sourceURL = artifact.sourceURL else { return false }
        if [.pending, .failed].contains(artifact.linkMetadataState) { return true }
        guard artifact.linkMetadataState == .processed,
              isInstagramURL(sourceURL),
              let metadata = artifact.linkMetadata else { return false }
        let title = metadata.title?.lowercased() ?? ""
        let summary = metadata.summary?.lowercased() ?? ""
        return title.contains(" on instagram:") ||
            title.contains("• instagram reel") ||
            (summary.contains(" likes,") && summary.contains(" comments -"))
    }

    private static func isInstagramURL(_ rawURL: String) -> Bool {
        guard let host = URLComponents(string: rawURL)?.host?.lowercased() else { return false }
        return host == "instagram.com" || host.hasSuffix(".instagram.com")
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
        try await linkMetadataProvider.fetch(rawURL)
    }

    func extractText(for mediaKey: String) async throws -> String? {
        let imageURL = try SharedMediaStore.url(for: mediaKey)
        return try await VisionTextRecognizer().recognizeText(at: imageURL)
    }

    func enrich(_ artifact: Artifact) async throws -> ArtifactEnrichment? {
        try await ArtifactEnricher().enrich(artifact)
    }
}
