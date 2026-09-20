import Foundation
import SwiftUI
import Combine

@MainActor
final class ArtifactLibrary: ObservableObject {
    @Published private(set) var artifacts: [Artifact] = []
    @Published private(set) var loadError: String?
    @Published private(set) var shareImportError: String?

    private let repository: any ArtifactRepository
    private let processor: ArtifactProcessingCoordinator
    private let sharedInbox: SharedArtifactInboxClient
    private var isImportingSharedArtifacts = false

    init(
        repository: any ArtifactRepository,
        placeResolver: MapPlaceResolver? = nil,
        sharedInbox: SharedArtifactInboxClient? = nil
    ) {
        self.repository = repository
        self.sharedInbox = sharedInbox ?? .live
        let resolver = placeResolver ?? MapPlaceResolver(
            searchProvider: MapKitPlaceSearchProvider(),
            linkExpander: URLSessionMapLinkExpander()
        )
        self.processor = ArtifactProcessingCoordinator(placeResolver: resolver)
    }

    func load() async {
        do {
            artifacts = try await repository.artifacts()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    func save(_ artifact: Artifact) async throws {
        try await repository.save(artifact)
        artifacts.insert(artifact, at: 0)
        if ArtifactProcessingCoordinator.shouldResolvePlace(artifact) {
            Task { await process(artifact.id) }
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

    func saveEditedDetails(_ details: ArtifactUserDetails?, note: String?, for id: UUID) async throws {
        guard let artifact = artifacts.first(where: { $0.id == id }) else { return }
        try await update(artifact.withEditedDetails(details, note: note))
    }

    func processPendingMaps() async {
        for artifact in artifacts where ArtifactProcessingCoordinator.shouldResolvePlace(artifact) ||
            (artifact.processingState == .processing && artifact.place == nil && artifact.sourceURL.map { MapLinkMetadata.provider(for: $0) != nil } == true) {
            await process(artifact.id)
        }
    }

    func retryProcessing(_ id: UUID) async {
        guard let artifact = artifacts.first(where: { $0.id == id }),
              !processor.isResolving(id),
              artifact.place == nil,
              artifact.sourceURL.map({ MapLinkMetadata.provider(for: $0) != nil }) == true else { return }
        do {
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
        await processPendingEnrichment()
    }

    func deleteArtifact(_ id: UUID) async throws {
        try await deleteArtifacts([id])
    }

    func deleteArtifacts(_ ids: Set<UUID>) async throws {
        let removed = artifacts.filter { ids.contains($0.id) }
        guard !removed.isEmpty else { return }
        try await repository.deleteMany(Set(removed.map(\.id)))
        artifacts.removeAll { ids.contains($0.id) }
        for mediaKey in removed.compactMap(\.mediaKey) {
            try? SharedMediaStore.remove(mediaKey)
        }
    }

    func backupData() throws -> Data {
        try LibraryBackupService.encode(artifacts)
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
            duplicates: archive.artifacts.count - additions.count
        )
    }

    private func process(_ id: UUID) async {
        guard let artifact = artifacts.first(where: { $0.id == id }),
              ArtifactProcessingCoordinator.shouldResolvePlace(artifact) || artifact.processingState == .processing else { return }
        guard processor.beginResolving(id) else { return }
        defer { processor.finishResolving(id) }

        do {
            try await update(artifact.withResolution(place: nil, state: .processing))
            let result = try await processor.resolvePlace(for: artifact)
            guard let current = artifacts.first(where: { $0.id == id }),
                  current.processingState == .processing else { return }
            switch result {
            case .matched(let place):
                try await update(current.withResolution(place: place, state: .processed))
            case .needsReview:
                try await update(current.withResolution(place: nil, state: .needsReview))
            case .collection:
                try await update(current.withResolution(place: nil, state: .processed))
            }
        } catch {
            guard let current = artifacts.first(where: { $0.id == id }),
                  current.processingState == .processing else { return }
            let state: ArtifactProcessingState = error is CancellationError ? .saved : .failed
            try? await update(current.withResolution(place: nil, state: state))
        }
    }

    private func fetchLinkMetadata(_ id: UUID) async {
        guard let artifact = artifacts.first(where: { $0.id == id }),
              (ArtifactProcessingCoordinator.shouldFetchLinkMetadata(artifact) || artifact.linkMetadataState == .processing),
              let sourceURL = artifact.sourceURL,
              processor.beginFetchingLinkMetadata(id) else { return }
        defer { processor.finishFetchingLinkMetadata(id) }
        do {
            try await update(artifact.withLinkMetadata(artifact.linkMetadata, state: .processing))
            let metadata = try await processor.fetchLinkMetadata(for: sourceURL)
            guard let current = artifacts.first(where: { $0.id == id }), current.sourceURL == sourceURL else { return }
            try await update(current.withLinkMetadata(metadata, state: metadata == nil ? .unavailable : .processed))
        } catch is CancellationError {
            if let current = artifacts.first(where: { $0.id == id }) {
                try? await update(current.withLinkMetadata(current.linkMetadata, state: .pending))
            }
        } catch {
            if let current = artifacts.first(where: { $0.id == id }) {
                try? await update(current.withLinkMetadata(current.linkMetadata, state: .failed))
            }
        }
    }

    private func extractText(_ id: UUID) async {
        guard let artifact = artifacts.first(where: { $0.id == id }),
              (ArtifactProcessingCoordinator.shouldExtractText(artifact) || artifact.textExtractionState == .processing),
              let mediaKey = artifact.mediaKey,
              processor.beginExtractingText(id) else { return }
        defer { processor.finishExtractingText(id) }

        do {
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
        } catch is CancellationError {
            if let current = artifacts.first(where: { $0.id == id }) {
                try? await update(current.withExtractedText(
                    current.extractedText,
                    source: current.extractedTextSource,
                    state: .pending
                ))
            }
        } catch {
            if let current = artifacts.first(where: { $0.id == id }) {
                try? await update(current.withExtractedText(
                    current.extractedText,
                    source: current.extractedTextSource,
                    state: .failed
                ))
            }
        }
    }

    private func enrich(_ id: UUID, force: Bool = false) async {
        guard let artifact = artifacts.first(where: { $0.id == id }),
              force || ArtifactProcessingCoordinator.shouldEnrich(artifact),
              processor.beginEnriching(id) else { return }
        defer { processor.finishEnriching(id) }

        do {
            if artifact.enrichment == nil {
                try await update(artifact.withEnrichmentState(.processing))
            }
            let enrichment = try await processor.enrich(artifact)
            guard let current = artifacts.first(where: { $0.id == id }),
                  current.place?.id == artifact.place?.id,
                  current.originalText == artifact.originalText,
                  current.userNote == artifact.userNote,
                  current.extractedText == artifact.extractedText,
                  current.linkMetadata == artifact.linkMetadata else { return }
            if let enrichment {
                try await update(current.withEnrichment(enrichment))
            } else if current.enrichment != nil {
                try await update(current.withEnrichmentState(.processed))
            } else {
                try await update(current.withEnrichmentState(.unavailable))
            }
        } catch is CancellationError {
            if let current = artifacts.first(where: { $0.id == id }) {
                try? await update(current.withEnrichmentState(.pending))
            }
        } catch {
            if let current = artifacts.first(where: { $0.id == id }) {
                let state: ArtifactEnrichmentState = current.enrichment == nil ? .failed : .processed
                try? await update(current.withEnrichmentState(state))
            }
            loadError = error.localizedDescription
        }
    }

    private func update(_ artifact: Artifact) async throws {
        try await repository.update(artifact)
        guard let index = artifacts.firstIndex(where: { $0.id == artifact.id }) else { return }
        artifacts[index] = artifact
        if ArtifactProcessingCoordinator.shouldEnrich(artifact) {
            Task { await enrich(artifact.id) }
        }
    }

    func savePlace(_ candidate: PlaceCandidate) async throws {
        try await save(Artifact(
            kind: .url,
            sourceURL: candidate.sourceURL,
            originalText: candidate.place.name,
            place: candidate.place,
            processingState: .processed
        ))
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
                        originalText: envelope.originalText ?? envelope.sourceURL.flatMap(MapLinkMetadata.placeName),
                        userNote: envelope.userNote,
                        mediaKey: envelope.mediaKey,
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
