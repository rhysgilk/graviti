import Foundation
import SwiftUI
import Combine

@MainActor
final class ArtifactLibrary: ObservableObject {
    @Published private(set) var artifacts: [Artifact] = []
    @Published private(set) var processingJobs: [ArtifactProcessingJob] = []
    @Published private(set) var derivedIndex: LibraryDerivedIndex = .empty
    @Published private(set) var loadError: String?
    @Published private(set) var shareImportError: String?

    private let repository: any ArtifactRepository
    private let processor: ArtifactProcessingCoordinator
    private let geographyRepairProvider: (any PlaceGeographyRepairing)?
    private let sharedInbox: SharedArtifactInboxClient
    private var processingJobStore: ProcessingJobStore
    private var derivedIndexStore: LibraryDerivedIndexStore
    private var isImportingSharedArtifacts = false
    private var isProcessingPlaceQueue = false
    private var pendingPlaceRetryIDs: Set<UUID> = []
    private var placeRetryTask: Task<Void, Never>?
    private var durableRetryTask: Task<Void, Never>?
    private var placeRetryAttempt = 0
    private var isRepairingPlaceGeography = false

    init(
        repository: any ArtifactRepository,
        placeResolver: MapPlaceResolver? = nil,
        geographyRepairProvider: (any PlaceGeographyRepairing)? = nil,
        sharedInbox: SharedArtifactInboxClient? = nil,
        processingJobStore: ProcessingJobStore? = nil,
        derivedIndexStore: LibraryDerivedIndexStore? = nil
    ) {
        self.repository = repository
        self.geographyRepairProvider = geographyRepairProvider
        self.sharedInbox = sharedInbox ?? .live
        self.processingJobStore = processingJobStore ?? .live()
        self.derivedIndexStore = derivedIndexStore ?? .live()
        let resolver = placeResolver ?? MapPlaceResolver(
            searchProvider: MapKitPlaceSearchProvider(),
            linkExpander: URLSessionMapLinkExpander()
        )
        self.processor = ArtifactProcessingCoordinator(placeResolver: resolver)
    }

    func load() async {
        do {
            artifacts = try await repository.artifacts()
            refreshDurableState()
            scheduleDurableRetry()
            loadError = nil
            Task { await repairMissingPlaceRegions() }
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func repairMissingPlaceRegions() async {
        guard let geographyRepairProvider, !isRepairingPlaceGeography else { return }
        isRepairingPlaceGeography = true
        defer { isRepairingPlaceGeography = false }

        var seenPlaceIDs = Set<String>()
        let places = artifacts.compactMap(\.place).filter { place in
            place.region?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false &&
                place.locality != nil && place.country != nil && seenPlaceIDs.insert(place.id).inserted
        }
        for place in places {
            guard !Task.isCancelled else { return }
            do {
                guard let repaired = try await geographyRepairProvider.repairedPlace(place),
                      repaired.region?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { continue }
                let affected = artifacts.filter { artifact in
                    artifact.place?.id == place.id &&
                        (artifact.place?.region?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                }
                for artifact in affected {
                    try await update(artifact.withResolution(place: repaired, state: artifact.processingState))
                }
            } catch {
                continue
            }
            try? await Task.sleep(for: .milliseconds(150))
        }
    }

    func save(_ artifact: Artifact) async throws {
        try await repository.save(artifact)
        artifacts.insert(artifact, at: 0)
        refreshDurableState()
        if ArtifactProcessingCoordinator.shouldResolvePlace(artifact) {
            Task { await processPendingMaps() }
        }
        if ArtifactProcessingCoordinator.shouldEnrich(artifact) {
            Task { await enrich(artifact.id) }
        }
        if ArtifactProcessingCoordinator.shouldExtractText(artifact) {
            Task { await extractText(artifact.id) }
        }
        if ArtifactProcessingCoordinator.shouldFetchLinkMetadata(artifact) {
            Task { await fetchLinkMetadata(artifact.id) }
        }
    }

    func processPendingEnrichment() async {
        for artifact in artifacts where ArtifactProcessingCoordinator.shouldEnrich(artifact) {
            await enrich(artifact.id)
        }
    }

    func processPendingTextExtraction() {
        for artifact in artifacts where ArtifactProcessingCoordinator.shouldExtractText(artifact) || artifact.textExtractionState == .processing {
            Task { await extractText(artifact.id) }
        }
    }

    func processPendingLinkMetadata() {
        for artifact in artifacts where ArtifactProcessingCoordinator.shouldFetchLinkMetadata(artifact) || artifact.linkMetadataState == .processing {
            Task { await fetchLinkMetadata(artifact.id) }
        }
    }

    func refreshEnrichment(_ id: UUID) async {
        await enrich(id, force: true)
    }

    func retryTextExtraction(_ id: UUID) async {
        guard let artifact = artifacts.first(where: { $0.id == id }),
              artifact.kind == .photo,
              artifact.mediaKey != nil else { return }
        do {
            try? processingJobStore.markPending(artifactID: id, kind: .textExtraction)
            try await update(artifact.withExtractedText(
                artifact.extractedText,
                source: artifact.extractedTextSource,
                state: .pending
            ))
            await extractText(id)
        } catch {
            loadError = error.localizedDescription
        }
    }

    func retryLinkMetadata(_ id: UUID) async {
        guard let artifact = artifacts.first(where: { $0.id == id }),
              artifact.kind == .url,
              artifact.sourceURL != nil else { return }
        do {
            try? processingJobStore.markPending(artifactID: id, kind: .linkMetadata)
            try await update(artifact.withLinkMetadata(artifact.linkMetadata, state: .pending))
            await fetchLinkMetadata(id)
        } catch {
            loadError = error.localizedDescription
        }
    }

    func saveEditedDetails(_ details: ArtifactUserDetails?, note: String?, for id: UUID) async throws {
        guard let artifact = artifacts.first(where: { $0.id == id }) else { return }
        try await update(artifact.withEditedDetails(details, note: note))
    }

    func processPendingMaps() async {
        guard !isProcessingPlaceQueue else { return }
        isProcessingPlaceQueue = true
        var attemptedIDs = Set<UUID>()

        while true {
            let candidates = artifacts.filter { artifact in
                !attemptedIDs.contains(artifact.id) && (
                    ArtifactProcessingCoordinator.shouldResolvePlace(artifact) ||
                    (artifact.processingState == .processing && artifact.place == nil && ArtifactProcessingCoordinator.isPlaceResolutionSource(artifact)) ||
                    ArtifactProcessingCoordinator.shouldRepairSocialPlace(artifact)
                )
            }
            guard !candidates.isEmpty else { break }

            for artifact in candidates {
                attemptedIDs.insert(artifact.id)
                if ArtifactProcessingCoordinator.shouldRepairSocialPlace(artifact) {
                    try? await update(artifact.withResolution(place: nil, state: .saved))
                }
                await process(artifact.id)
                if candidates.last?.id != artifact.id {
                    try? await Task.sleep(for: .milliseconds(350))
                }
            }
        }
        isProcessingPlaceQueue = false
        if !pendingPlaceRetryIDs.isEmpty { schedulePlaceRetry() }
    }

    func retryProcessing(_ id: UUID) async {
        guard let artifact = artifacts.first(where: { $0.id == id }),
              !processor.isResolving(id),
              artifact.place == nil,
              artifact.sourceURL.map({ MapLinkMetadata.provider(for: $0) != nil }) == true else { return }
        do {
            try? processingJobStore.markPending(artifactID: id, kind: .placeIdentification)
            try await update(artifact.withResolution(place: nil, state: .saved))
            await process(id)
        } catch {
            loadError = error.localizedDescription
        }
    }

    func assignPlace(_ place: SavedPlace, to artifactID: UUID) async throws {
        guard let artifact = artifacts.first(where: { $0.id == artifactID }) else { return }
        try await update(artifact.withResolution(place: place, state: .processed))
    }

    func removePlaceMatch(from artifactID: UUID) async throws {
        guard let artifact = artifacts.first(where: { $0.id == artifactID }) else { return }
        try await update(artifact.withResolution(place: nil, state: .needsReview))
    }

    func removePlaceFromLibrary(_ placeID: String) async throws {
        try await removePlacesFromLibrary([placeID])
    }

    func stagePlaceRemoval(_ placeID: String) async throws -> [Artifact] {
        let originals = artifacts.filter { $0.place?.id == placeID }
        guard !originals.isEmpty else { return [] }
        let changed = originals.map { $0.withResolution(place: nil, state: .needsReview) }
        try await repository.updateMany(changed)
        let replacements = Dictionary(uniqueKeysWithValues: changed.map { ($0.id, $0) })
        artifacts = artifacts.map { replacements[$0.id] ?? $0 }
        refreshDurableState()
        return originals
    }

    func restorePlaceRemoval(_ originals: [Artifact]) async throws {
        guard !originals.isEmpty else { return }
        try await repository.updateMany(originals)
        let replacements = Dictionary(uniqueKeysWithValues: originals.map { ($0.id, $0) })
        artifacts = artifacts.map { replacements[$0.id] ?? $0 }
        refreshDurableState()
    }

    func placeStatus(for placeID: String) -> PlaceLifecycleStatus {
        artifacts.lazy
            .filter { $0.place?.id == placeID }
            .compactMap { $0.userDetails?.placeStatus }
            .first ?? .saved
    }

    func setPlaceStatus(_ status: PlaceLifecycleStatus, for placeID: String) async throws {
        let changed = artifacts
            .filter { $0.place?.id == placeID && $0.userDetails?.placeStatus != status }
            .map { $0.withPlaceStatus(status) }
        guard !changed.isEmpty else { return }
        try await repository.updateMany(changed)
        let replacements = Dictionary(uniqueKeysWithValues: changed.map { ($0.id, $0) })
        artifacts = artifacts.map { replacements[$0.id] ?? $0 }
        refreshDurableState()
    }

    func removePlacesFromLibrary(_ placeIDs: Set<String>) async throws {
        let changed = artifacts
            .filter { artifact in
                artifact.place.map { placeIDs.contains($0.id) } ?? false
            }
            .map { $0.withResolution(place: nil, state: .needsReview) }
        guard !changed.isEmpty else { return }
        try await repository.updateMany(changed)
        let replacements = Dictionary(uniqueKeysWithValues: changed.map { ($0.id, $0) })
        artifacts = artifacts.map { replacements[$0.id] ?? $0 }
        refreshDurableState()
        await processPendingEnrichment()
    }

    func deleteArtifact(_ id: UUID) async throws {
        try await deleteArtifacts([id])
    }

    func stageArtifactDeletion(_ id: UUID) async throws -> Artifact? {
        guard let removed = artifacts.first(where: { $0.id == id }) else { return nil }
        try await repository.delete(id)
        artifacts.removeAll { $0.id == id }
        pendingPlaceRetryIDs.remove(id)
        try? processingJobStore.removeJobs(for: [id])
        refreshDurableState()
        return removed
    }

    func restoreArtifactDeletion(_ artifact: Artifact) async throws {
        guard !artifacts.contains(where: { $0.id == artifact.id }) else { return }
        try await repository.save(artifact)
        artifacts.append(artifact)
        artifacts.sort { $0.capturedAt > $1.capturedAt }
        refreshDurableState()
    }

    func finalizeArtifactDeletion(_ artifact: Artifact) {
        if let mediaKey = artifact.mediaKey { try? SharedMediaStore.remove(mediaKey) }
    }

    func deleteArtifacts(_ ids: Set<UUID>) async throws {
        let removed = artifacts.filter { ids.contains($0.id) }
        guard !removed.isEmpty else { return }
        try await repository.deleteMany(Set(removed.map(\.id)))
        artifacts.removeAll { ids.contains($0.id) }
        pendingPlaceRetryIDs.subtract(ids)
        try? processingJobStore.removeJobs(for: ids)
        refreshDurableState()
        for mediaKey in removed.compactMap(\.mediaKey) {
            try? SharedMediaStore.remove(mediaKey)
        }
    }

    var hasSampleLibrary: Bool {
        artifacts.contains(where: SampleLibrarySeeder.isSample)
    }

    @discardableResult
    func addSampleLibrary() async throws -> Int {
        let existingIDs = Set(artifacts.map(\.id))
        let additions = SampleLibrarySeeder.artifacts.filter { !existingIDs.contains($0.id) }
        guard !additions.isEmpty else { return 0 }
        try await repository.saveMany(additions)
        artifacts.insert(contentsOf: additions.sorted { $0.capturedAt > $1.capturedAt }, at: 0)
        refreshDurableState()
        return additions.count
    }

    @discardableResult
    func removeSampleLibrary() async throws -> Int {
        let samples = artifacts.filter(SampleLibrarySeeder.isSample)
        guard !samples.isEmpty else { return 0 }
        let ids = Set(samples.map(\.id))
        try await repository.deleteMany(ids)
        artifacts.removeAll { ids.contains($0.id) }
        pendingPlaceRetryIDs.subtract(ids)
        try? processingJobStore.removeJobs(for: ids)
        refreshDurableState()
        return samples.count
    }

    func backupData(preferences: LibraryBackupPreferences? = nil) throws -> Data {
        try LibraryBackupService.encode(artifacts, preferences: preferences)
    }

    func restoreBackup(_ data: Data) async throws -> LibraryRestoreSummary {
        let archive = try LibraryBackupService.decode(data)
        let existingIDs = Set(artifacts.map(\.id))
        let additions = archive.artifacts.filter { !existingIDs.contains($0.artifact.id) }
        var restoredArtifacts = [Artifact]()
        var createdMediaKeys = [String]()
        do {
            for entry in additions {
                if let mediaData = entry.mediaData, let fileExtension = entry.mediaFileExtension {
                    let key = try SharedMediaStore.store(mediaData, id: entry.artifact.id, fileExtension: fileExtension)
                    createdMediaKeys.append(key)
                    restoredArtifacts.append(entry.artifact.withMediaKey(key))
                } else {
                    restoredArtifacts.append(entry.artifact.withMediaKey(nil))
                }
            }
            if !restoredArtifacts.isEmpty {
                try await repository.saveMany(restoredArtifacts)
                artifacts.insert(contentsOf: restoredArtifacts.sorted { $0.capturedAt > $1.capturedAt }, at: 0)
                refreshDurableState()
                Task { await processPendingMaps() }
                processPendingTextExtraction()
                processPendingLinkMetadata()
                await processPendingEnrichment()
            }
        } catch {
            for key in createdMediaKeys { try? SharedMediaStore.remove(key) }
            throw error
        }
        return LibraryRestoreSummary(
            imported: restoredArtifacts.count,
            duplicates: archive.artifacts.count - additions.count,
            preferences: archive.preferences
        )
    }

    private func process(_ id: UUID) async {
        guard let artifact = artifacts.first(where: { $0.id == id }),
              ArtifactProcessingCoordinator.shouldResolvePlace(artifact) || artifact.processingState == .processing,
              jobCanRun(artifactID: id, kind: .placeIdentification) || artifact.processingState == .failed else { return }
        guard processor.beginResolving(id) else { return }
        defer { processor.finishResolving(id) }

        do {
            try processingJobStore.markRunning(artifactID: id, kind: .placeIdentification)
            reloadProcessingJobs()
            try await update(artifact.withResolution(place: nil, state: .processing))
            let result = try await processor.resolvePlace(for: artifact)
            guard let current = artifacts.first(where: { $0.id == id }),
                  current.processingState == .processing else { return }
            switch result {
            case .matched(let place):
                try await update(current.withResolution(place: place, state: .processed))
                try? processingJobStore.markCompleted(
                    artifactID: id,
                    kind: .placeIdentification,
                    outputSummary: place.name,
                    outputProvenance: GeneratedDataProvenance(
                        producer: "MapPlaceResolver",
                        version: ArtifactProcessingJobKind.placeIdentification.currentVersion
                    )
                )
                finishPlaceRetry(id)
            case .needsReview:
                try await update(current.withResolution(place: nil, state: .needsReview))
                try? processingJobStore.markCompleted(
                    artifactID: id,
                    kind: .placeIdentification,
                    outputSummary: SocialPlaceHintExtractor.hint(for: artifact)?.expectedName,
                    outputProvenance: GeneratedDataProvenance(
                        producer: "SocialPlaceHintExtractor",
                        version: ArtifactProcessingJobKind.placeIdentification.currentVersion
                    )
                )
                finishPlaceRetry(id)
            case .collection:
                try await update(current.withResolution(place: nil, state: .processed))
                try? processingJobStore.markCompleted(artifactID: id, kind: .placeIdentification, unavailable: true)
                finishPlaceRetry(id)
            case .unmatched:
                try await update(current.withResolution(place: nil, state: .processed))
                try? processingJobStore.markCompleted(
                    artifactID: id,
                    kind: .placeIdentification,
                    unavailable: true,
                    outputSummary: SocialPlaceHintExtractor.hint(for: artifact)?.expectedName,
                    outputProvenance: GeneratedDataProvenance(
                        producer: "SocialPlaceHintExtractor",
                        version: ArtifactProcessingJobKind.placeIdentification.currentVersion
                    )
                )
                finishPlaceRetry(id)
            }
            reloadProcessingJobs()
        } catch {
            guard let current = artifacts.first(where: { $0.id == id }),
                  current.processingState == .processing else { return }
            let isSocialAttempt = ArtifactProcessingCoordinator.isSocialPlaceResolutionSource(artifact)
            let state: ArtifactProcessingState = error is CancellationError || isSocialAttempt ? .saved : .failed
            try? await update(current.withResolution(place: nil, state: state))
            if error is CancellationError {
                try? processingJobStore.markPending(artifactID: id, kind: .placeIdentification)
            } else {
                try? processingJobStore.markFailed(artifactID: id, kind: .placeIdentification, error: error)
            }
            reloadProcessingJobs()
            if !(error is CancellationError) {
                pendingPlaceRetryIDs.insert(id)
                schedulePlaceRetry()
                scheduleDurableRetry()
            }
        }
    }

    private func fetchLinkMetadata(_ id: UUID) async {
        guard let artifact = artifacts.first(where: { $0.id == id }),
              (ArtifactProcessingCoordinator.shouldFetchLinkMetadata(artifact) || artifact.linkMetadataState == .processing),
              let sourceURL = artifact.sourceURL,
              jobCanRun(artifactID: id, kind: .linkMetadata),
              processor.beginFetchingLinkMetadata(id) else { return }
        defer { processor.finishFetchingLinkMetadata(id) }
        do {
            try processingJobStore.markRunning(artifactID: id, kind: .linkMetadata)
            reloadProcessingJobs()
            try await update(artifact.withLinkMetadata(artifact.linkMetadata, state: .processing))
            let metadata = try await processor.fetchLinkMetadata(for: sourceURL)
            guard let current = artifacts.first(where: { $0.id == id }), current.sourceURL == sourceURL else { return }
            var updated = current.withLinkMetadata(metadata, state: metadata == nil ? .unavailable : .processed)
            if let title = metadata?.title,
               current.originalText == nil || isInstagramURL(sourceURL) {
                updated = updated.withOriginalText(title)
            }
            try await update(updated)
            try? processingJobStore.markCompleted(
                artifactID: id,
                kind: .linkMetadata,
                unavailable: metadata == nil,
                outputSummary: metadata?.title,
                outputProvenance: metadata?.provenance
            )
            reloadProcessingJobs()
        } catch is CancellationError {
            if let current = artifacts.first(where: { $0.id == id }) {
                try? await update(current.withLinkMetadata(current.linkMetadata, state: .pending))
            }
            try? processingJobStore.markPending(artifactID: id, kind: .linkMetadata)
            reloadProcessingJobs()
        } catch {
            if let current = artifacts.first(where: { $0.id == id }) {
                try? await update(current.withLinkMetadata(current.linkMetadata, state: .failed))
            }
            try? processingJobStore.markFailed(artifactID: id, kind: .linkMetadata, error: error)
            reloadProcessingJobs()
            scheduleDurableRetry()
        }
    }

    private func extractText(_ id: UUID) async {
        guard let artifact = artifacts.first(where: { $0.id == id }),
              (ArtifactProcessingCoordinator.shouldExtractText(artifact) || artifact.textExtractionState == .processing),
              let mediaKey = artifact.mediaKey,
              jobCanRun(artifactID: id, kind: .textExtraction),
              processor.beginExtractingText(id) else { return }
        defer { processor.finishExtractingText(id) }

        do {
            try processingJobStore.markRunning(artifactID: id, kind: .textExtraction)
            reloadProcessingJobs()
            try await update(artifact.withExtractedText(
                artifact.extractedText,
                source: artifact.extractedTextSource,
                state: .processing
            ))
            let text = try await processor.extractText(for: mediaKey)
            guard let current = artifacts.first(where: { $0.id == id }),
                  current.mediaKey == mediaKey else { return }
            try await update(current.withExtractedText(
                text,
                source: text == nil ? nil : .appleVision,
                state: text == nil ? .unavailable : .processed
            ))
            try? processingJobStore.markCompleted(
                artifactID: id,
                kind: .textExtraction,
                unavailable: text == nil,
                outputSummary: text.map { String($0.prefix(160)) },
                outputProvenance: GeneratedDataProvenance(
                    producer: "AppleVision",
                    version: ArtifactProcessingJobKind.textExtraction.currentVersion
                )
            )
            reloadProcessingJobs()
        } catch is CancellationError {
            if let current = artifacts.first(where: { $0.id == id }) {
                try? await update(current.withExtractedText(
                    current.extractedText,
                    source: current.extractedTextSource,
                    state: .pending
                ))
            }
            try? processingJobStore.markPending(artifactID: id, kind: .textExtraction)
            reloadProcessingJobs()
        } catch {
            if let current = artifacts.first(where: { $0.id == id }) {
                try? await update(current.withExtractedText(
                    current.extractedText,
                    source: current.extractedTextSource,
                    state: .failed
                ))
            }
            try? processingJobStore.markFailed(artifactID: id, kind: .textExtraction, error: error)
            reloadProcessingJobs()
            scheduleDurableRetry()
        }
    }

    private func enrich(_ id: UUID, force: Bool = false) async {
        var shouldRestart = false
        guard let artifact = artifacts.first(where: { $0.id == id }),
              force || ArtifactProcessingCoordinator.shouldEnrich(artifact),
              force || jobCanRun(artifactID: id, kind: .enrichment),
              processor.beginEnriching(id) else { return }
        defer {
            processor.finishEnriching(id)
            if shouldRestart { Task { await enrich(id) } }
        }

        do {
            if force { try? processingJobStore.markPending(artifactID: id, kind: .enrichment) }
            try processingJobStore.markRunning(artifactID: id, kind: .enrichment)
            reloadProcessingJobs()
            if artifact.enrichment == nil {
                try await update(artifact.withEnrichmentState(.processing))
            }
            let enrichment = try await processor.enrich(artifact)
            guard let current = artifacts.first(where: { $0.id == id }) else { return }
            guard current.place?.id == artifact.place?.id,
                  current.originalText == artifact.originalText,
                  current.userNote == artifact.userNote,
                  current.extractedText == artifact.extractedText,
                  current.linkMetadata == artifact.linkMetadata else {
                try? await update(current.withEnrichmentState(.pending))
                shouldRestart = true
                return
            }
            if let enrichment {
                try await update(current.withEnrichment(enrichment))
                try? processingJobStore.markCompleted(
                    artifactID: id,
                    kind: .enrichment,
                    outputSummary: enrichment.summary,
                    outputProvenance: enrichment.provenance
                )
            } else if current.enrichment != nil {
                try await update(current.withEnrichmentState(.processed))
                try? processingJobStore.markCompleted(artifactID: id, kind: .enrichment)
            } else {
                try await update(current.withEnrichmentState(.unavailable))
                try? processingJobStore.markCompleted(artifactID: id, kind: .enrichment, unavailable: true)
            }
            reloadProcessingJobs()
        } catch is CancellationError {
            if let current = artifacts.first(where: { $0.id == id }) {
                try? await update(current.withEnrichmentState(.pending))
            }
            try? processingJobStore.markPending(artifactID: id, kind: .enrichment)
            reloadProcessingJobs()
        } catch {
            if let current = artifacts.first(where: { $0.id == id }) {
                let state: ArtifactEnrichmentState = current.enrichment == nil ? .failed : .processed
                try? await update(current.withEnrichmentState(state))
            }
            try? processingJobStore.markFailed(artifactID: id, kind: .enrichment, error: error)
            reloadProcessingJobs()
            scheduleDurableRetry()
            loadError = error.localizedDescription
        }
    }

    private func isInstagramURL(_ rawURL: String) -> Bool {
        guard let host = URLComponents(string: rawURL)?.host?.lowercased() else { return false }
        return host == "instagram.com" || host.hasSuffix(".instagram.com")
    }

    private func update(_ artifact: Artifact) async throws {
        try await repository.update(artifact)
        guard let index = artifacts.firstIndex(where: { $0.id == artifact.id }) else { return }
        let gainedPlaceHint = !ArtifactProcessingCoordinator.isPlaceResolutionSource(artifacts[index]) &&
            ArtifactProcessingCoordinator.shouldResolvePlace(artifact)
        artifacts[index] = artifact
        refreshDurableState()
        if gainedPlaceHint {
            Task { await processPendingMaps() }
        }
        if ArtifactProcessingCoordinator.shouldEnrich(artifact) {
            Task { await enrich(artifact.id) }
        }
    }

    private func finishPlaceRetry(_ id: UUID) {
        pendingPlaceRetryIDs.remove(id)
        if pendingPlaceRetryIDs.isEmpty {
            placeRetryAttempt = 0
            placeRetryTask?.cancel()
            placeRetryTask = nil
        }
    }

    private func jobCanRun(artifactID: UUID, kind: ArtifactProcessingJobKind, now: Date = .now) -> Bool {
        guard let job = processingJobs.first(where: { $0.artifactID == artifactID && $0.kind == kind }) else {
            return true
        }
        if job.status == .running { return true }
        return job.isReady(at: now, in: processingJobs)
    }

    private func refreshDurableState() {
        do {
            processingJobs = try processingJobStore.reconcile(with: artifacts)
            let guideJSON = UserDefaults.standard.string(forKey: "fitGuide.library.v1") ?? ""
            derivedIndex = try derivedIndexStore.rebuild(from: artifacts, guideLibraryJSON: guideJSON)
            for artifact in artifacts {
                try? processingJobStore.markCompleted(
                    artifactID: artifact.id,
                    kind: .profileIndexing,
                    outputSummary: derivedIndex.sourceFingerprint,
                    outputProvenance: GeneratedDataProvenance(
                        producer: "LibraryDerivedIndex",
                        version: LibraryDerivedIndex.currentSchemaVersion,
                        generatedAt: derivedIndex.builtAt,
                        inputFingerprint: derivedIndex.sourceFingerprint
                    )
                )
            }
            reloadProcessingJobs()
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func reloadProcessingJobs() {
        processingJobs = (try? processingJobStore.load()) ?? processingJobs
    }

    private func scheduleDurableRetry(now: Date = .now) {
        durableRetryTask?.cancel()
        guard let retryAt = processingJobs.compactMap({ job -> Date? in
            guard job.status == .waitingForRetry,
                  job.dependenciesAreComplete(in: processingJobs) else { return nil }
            return job.nextRetryAt
        }).min() else {
            durableRetryTask = nil
            return
        }
        let delay = max(0, retryAt.timeIntervalSince(now))
        durableRetryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            self.durableRetryTask = nil
            await self.processPendingMaps()
            self.processPendingTextExtraction()
            self.processPendingLinkMetadata()
            await self.processPendingEnrichment()
            self.scheduleDurableRetry()
        }
    }

    private func schedulePlaceRetry() {
        guard !pendingPlaceRetryIDs.isEmpty,
              placeRetryTask == nil,
              placeRetryAttempt < 5 else { return }
        let delays: [Duration] = [.seconds(2), .seconds(5), .seconds(12), .seconds(30), .seconds(60)]
        let delay = delays[placeRetryAttempt]
        placeRetryAttempt += 1
        placeRetryTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            self.placeRetryTask = nil
            await self.processPendingMaps()
        }
    }

    @discardableResult
    func savePlace(_ candidate: PlaceCandidate, sourceCollectionTitle: String? = nil) async throws -> UUID {
        if let sourceCollectionTitle,
           let existing = artifacts.first(where: { $0.place?.id == candidate.place.id }) {
            guard !existing.sourceCollectionTitles.contains(sourceCollectionTitle) else { return existing.id }
            try await update(existing.withSourceCollectionTitle(sourceCollectionTitle))
            return existing.id
        }
        if sourceCollectionTitle == nil,
           let existing = artifacts.first(where: { $0.place?.id == candidate.place.id }) {
            return existing.id
        }
        let artifact = Artifact(
            kind: .url,
            sourceURL: candidate.sourceURL,
            sourceCollectionTitle: sourceCollectionTitle,
            originalText: candidate.place.name,
            place: candidate.place,
            processingState: .processed
        )
        try await save(artifact)
        return artifact.id
    }

    func removeArtifact(_ artifactID: UUID, from guide: FitGuide) async throws {
        guard let artifact = artifacts.first(where: { $0.id == artifactID }) else { return }
        let updated = artifact.removingSourceCollectionTitles { title in
            title == guide.collectionTitle || title.hasPrefix("\(guide.collectionTitle) · ")
        }
        guard updated != artifact else { return }
        try await update(updated)
    }

    func savePhoto(_ data: Data, fileExtension: String, note: String?) async throws {
        let id = UUID()
        let key = try SharedMediaStore.store(data, id: id, fileExtension: fileExtension)
        do {
            try await save(Artifact(
                id: id,
                kind: .photo,
                userNote: note,
                mediaKey: key
            ))
        } catch {
            try? SharedMediaStore.remove(key)
            throw error
        }
    }

    @discardableResult
    func importSharedArtifacts() async -> Int {
        guard !isImportingSharedArtifacts else { return 0 }
        isImportingSharedArtifacts = true
        defer { isImportingSharedArtifacts = false }
        var importedCount = 0
        do {
            for fileURL in try sharedInbox.pendingFiles() {
                let envelope = try sharedInbox.read(fileURL)
                if !artifacts.contains(where: { $0.id == envelope.id }) {
                    let artifact = Artifact(
                        id: envelope.id,
                        kind: envelope.mediaKey != nil ? .photo : (envelope.sourceURL == nil ? .manual : .url),
                        sourceURL: envelope.sourceURL,
                        sourceCollectionTitle: envelope.sourceCollectionTitle,
                        originalText: envelope.originalText ?? envelope.sourceURL.flatMap(MapLinkMetadata.placeName),
                        userNote: envelope.userNote,
                        mediaKey: envelope.mediaKey,
                        userDetails: envelope.isHighPriority || !envelope.tags.isEmpty
                            ? ArtifactUserDetails(
                                summary: nil,
                                category: nil,
                                interests: [],
                                isHighPriority: envelope.isHighPriority,
                                tags: envelope.tags
                            ) : nil,
                        processingState: envelope.skipPlaceIdentification ? .processed : .saved,
                        capturedAt: envelope.capturedAt
                    )
                    try await save(artifact)
                    importedCount += 1
                }
                try sharedInbox.remove(fileURL)
            }
            shareImportError = nil
        } catch {
            shareImportError = error.localizedDescription
        }
        return importedCount
    }

    func importGoogleSavedCSV(from fileURL: URL) async throws -> CSVImportSummary {
        let hasAccess = fileURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { fileURL.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: fileURL)
        guard let text = String(data: data, encoding: .utf8) else {
            throw CSVImportError.invalidEncoding
        }
        return try await importGoogleSavedCSV(text)
    }

    func importGoogleSavedCSV(_ text: String) async throws -> CSVImportSummary {
        let plan = try ArtifactImportCoordinator.googleCSV(text, existingArtifacts: artifacts)

        if !plan.artifacts.isEmpty {
            try await repository.saveMany(plan.artifacts)
            artifacts.insert(contentsOf: plan.artifacts, at: 0)
            refreshDurableState()
            Task { await processPendingMaps() }
            await processPendingEnrichment()
        }
        return CSVImportSummary(
            imported: plan.artifacts.count,
            duplicates: plan.duplicates,
            skipped: plan.skipped,
            importedIDs: plan.artifacts.map(\.id)
        )
    }

    func importMapsLinkFile(from fileURL: URL) async throws -> String {
        let hasAccess = fileURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { fileURL.stopAccessingSecurityScopedResource() } }

        let plan = try ArtifactImportCoordinator.mapsLinkFile(
            Data(contentsOf: fileURL), existingArtifacts: artifacts
        )
        if let artifact = plan.artifact {
            try await save(artifact)
        }
        return plan.rawURL
    }

    func importAppleGuidePlaces(from rawURL: String) async throws -> AppleGuideImportSummary {
        let plan = try await ArtifactImportCoordinator.appleGuide(rawURL, existingArtifacts: artifacts)
        try await applyCollectionTitle(plan.title, sourceURL: rawURL)

        if !plan.updatedArtifacts.isEmpty {
            try await repository.updateMany(plan.updatedArtifacts)
            let replacements = Dictionary(uniqueKeysWithValues: plan.updatedArtifacts.map { ($0.id, $0) })
            artifacts = artifacts.map { replacements[$0.id] ?? $0 }
        }
        if !plan.artifacts.isEmpty {
            try await repository.saveMany(plan.artifacts)
            artifacts.insert(contentsOf: plan.artifacts, at: 0)
        }
        if !plan.artifacts.isEmpty || !plan.updatedArtifacts.isEmpty {
            refreshDurableState()
            await processPendingEnrichment()
        }
        let affectedArtifacts = plan.artifacts + plan.updatedArtifacts
        return AppleGuideImportSummary(
            title: plan.title,
            imported: plan.artifacts.count,
            refreshed: plan.updatedArtifacts.count,
            duplicates: plan.duplicates,
            skipped: plan.skipped,
            countries: Set(affectedArtifacts.compactMap { $0.place?.country }).count,
            cities: Set(affectedArtifacts.compactMap { $0.place?.locality }).count
        )
    }

    func importGoogleMapsListPlaces(from rawURL: String) async throws -> GoogleMapsListImportSummary {
        let list = try await GoogleMapsListImporter.load(rawURL)
        // Build the plan after the network request so background processing that
        // completed while the list loaded is not overwritten by a stale snapshot.
        let plan = ArtifactImportCoordinator.googleMapsList(list, existingArtifacts: artifacts)
        try await applyCollectionTitle(plan.title, sourceURL: rawURL)

        if !plan.updatedArtifacts.isEmpty {
            try await repository.updateMany(plan.updatedArtifacts)
            let replacements = Dictionary(uniqueKeysWithValues: plan.updatedArtifacts.map { ($0.id, $0) })
            artifacts = artifacts.map { replacements[$0.id] ?? $0 }
        }
        if !plan.artifacts.isEmpty {
            try await repository.saveMany(plan.artifacts)
            artifacts.insert(contentsOf: plan.artifacts, at: 0)
        }
        if !plan.artifacts.isEmpty || !plan.updatedArtifacts.isEmpty {
            refreshDurableState()
            Task {
                await processPendingMaps()
                await processPendingEnrichment()
            }
        }
        return GoogleMapsListImportSummary(
            title: plan.title,
            imported: plan.artifacts.count,
            refreshed: plan.updatedArtifacts.count,
            duplicates: plan.duplicates,
            skipped: plan.skipped
        )
    }

    private func applyCollectionTitle(_ title: String, sourceURL: String) async throws {
        guard let index = artifacts.firstIndex(where: { $0.sourceURL == sourceURL }),
              artifacts[index].originalText != title else { return }
        let updated = artifacts[index].withOriginalText(title)
        try await repository.update(updated)
        artifacts[index] = updated
        refreshDurableState()
    }
}

struct AppleGuideImportSummary {
    let title: String
    let imported: Int
    let refreshed: Int
    let duplicates: Int
    let skipped: Int
    let countries: Int
    let cities: Int
}

struct CSVImportSummary {
    let imported: Int
    let duplicates: Int
    let skipped: Int
    let importedIDs: [UUID]
}

struct GoogleMapsListImportSummary {
    let title: String
    let imported: Int
    let refreshed: Int
    let duplicates: Int
    let skipped: Int
}
