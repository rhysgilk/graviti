import Foundation
import SwiftUI
import Combine
import MapKit

@MainActor
final class ArtifactLibrary: ObservableObject {
    @Published private(set) var artifacts: [Artifact] = []
    @Published private(set) var loadError: String?

    private let repository: any ArtifactRepository
    private let placeResolver: MapPlaceResolver
    private var processingIDs: Set<UUID> = []
    private var enrichingIDs: Set<UUID> = []
    private var extractingTextIDs: Set<UUID> = []
    private var isImportingSharedArtifacts = false

    init(repository: any ArtifactRepository, placeResolver: MapPlaceResolver? = nil) {
        self.repository = repository
        self.placeResolver = placeResolver ?? MapPlaceResolver(
            searchProvider: MapKitPlaceSearchProvider(),
            linkExpander: URLSessionMapLinkExpander()
        )
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
        if shouldProcess(artifact) {
            Task { await process(artifact.id) }
        }
        if shouldEnrich(artifact) {
            Task { await enrich(artifact.id) }
        }
        if shouldExtractText(artifact) {
            Task { await extractText(artifact.id) }
        }
    }

    func processPendingEnrichment() {
        for artifact in artifacts where shouldEnrich(artifact) {
            Task { await enrich(artifact.id) }
        }
    }

    func processPendingTextExtraction() {
        for artifact in artifacts where shouldExtractText(artifact) || artifact.textExtractionState == .processing {
            Task { await extractText(artifact.id) }
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
        for artifact in artifacts where shouldProcess(artifact) ||
            (artifact.processingState == .processing && artifact.place == nil && artifact.sourceURL.map { MapLinkMetadata.provider(for: $0) != nil } == true) {
            await process(artifact.id)
        }
    }

    func retryProcessing(_ id: UUID) async {
        guard let artifact = artifacts.first(where: { $0.id == id }),
              !processingIDs.contains(id),
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
        processPendingEnrichment()
    }

    func deleteArtifact(_ id: UUID) async throws {
        guard let artifact = artifacts.first(where: { $0.id == id }) else { return }
        try await repository.delete(id)
        artifacts.removeAll { $0.id == id }
        if let mediaKey = artifact.mediaKey {
            try? SharedMediaStore.remove(mediaKey)
        }
    }

    func deleteArtifacts(_ ids: Set<UUID>) async throws {
        for id in ids where artifacts.contains(where: { $0.id == id }) {
            try await deleteArtifact(id)
        }
    }

    private func process(_ id: UUID) async {
        guard let artifact = artifacts.first(where: { $0.id == id }),
              shouldProcess(artifact) || artifact.processingState == .processing else { return }
        guard processingIDs.insert(id).inserted else { return }
        defer { processingIDs.remove(id) }

        do {
            try await update(artifact.withResolution(place: nil, state: .processing))
            let result = try await placeResolver.resolve(artifact)
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

    private func shouldProcess(_ artifact: Artifact) -> Bool {
        artifact.processingState == .saved && artifact.place == nil &&
            artifact.sourceURL.map { MapLinkMetadata.provider(for: $0) != nil } == true
    }

    private func shouldEnrich(_ artifact: Artifact) -> Bool {
        artifact.enrichment == nil &&
            [.pending, .processing, .failed].contains(artifact.enrichmentState) &&
            (artifact.place != nil || artifact.originalText != nil || artifact.userNote != nil || artifact.extractedText != nil) &&
            artifact.sourceURL.map(MapLinkMetadata.isCollectionLink) != true
    }

    private func shouldExtractText(_ artifact: Artifact) -> Bool {
        artifact.kind == .photo && artifact.mediaKey != nil &&
            [.pending, .failed].contains(artifact.textExtractionState)
    }

    private func extractText(_ id: UUID) async {
        guard let artifact = artifacts.first(where: { $0.id == id }),
              (shouldExtractText(artifact) || artifact.textExtractionState == .processing),
              let mediaKey = artifact.mediaKey,
              extractingTextIDs.insert(id).inserted else { return }
        defer { extractingTextIDs.remove(id) }

        do {
            try await update(artifact.withExtractedText(
                artifact.extractedText,
                source: artifact.extractedTextSource,
                state: .processing
            ))
            let imageURL = try SharedMediaStore.url(for: mediaKey)
            let text = try await VisionTextRecognizer().recognizeText(at: imageURL)
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
              force || shouldEnrich(artifact),
              enrichingIDs.insert(id).inserted else { return }
        defer { enrichingIDs.remove(id) }

        do {
            if artifact.enrichment == nil {
                try await update(artifact.withEnrichmentState(.processing))
            }
            let enrichment = try await ArtifactEnricher().enrich(artifact)
            guard let current = artifacts.first(where: { $0.id == id }),
                  current.place?.id == artifact.place?.id,
                  current.originalText == artifact.originalText,
                  current.userNote == artifact.userNote else { return }
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
        if shouldEnrich(artifact) {
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
            for fileURL in try SharedArtifactInbox.pendingFiles() {
                let envelope = try SharedArtifactInbox.read(fileURL)
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
                try SharedArtifactInbox.remove(fileURL)
            }
            loadError = nil
        } catch {
            loadError = error.localizedDescription
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
        let parsed = try GoogleSavedCSVParser.parse(text)

        struct ImportKey: Hashable {
            let url: String
            let title: String
            let note: String?
        }
        var seen = Set(artifacts.compactMap { artifact -> ImportKey? in
            guard let url = artifact.sourceURL,
                  let title = artifact.originalText else { return nil }
            return ImportKey(url: url, title: title, note: artifact.userNote)
        })
        var newArtifacts: [Artifact] = []
        var duplicateCount = 0
        for row in parsed.rows {
            let key = ImportKey(url: row.url, title: row.title, note: row.note)
            guard seen.insert(key).inserted else {
                duplicateCount += 1
                continue
            }
            newArtifacts.append(Artifact(
                kind: .url,
                sourceURL: row.url,
                originalText: row.title,
                userNote: row.note
            ))
        }

        if !newArtifacts.isEmpty {
            try await repository.saveMany(newArtifacts)
            artifacts.insert(contentsOf: newArtifacts, at: 0)
            Task { await processPendingMaps() }
            processPendingEnrichment()
        }
        return CSVImportSummary(
            imported: newArtifacts.count,
            duplicates: duplicateCount,
            skipped: parsed.skippedRows,
            importedIDs: newArtifacts.map(\.id)
        )
    }

    func importMapsLinkFile(from fileURL: URL) async throws -> String {
        let hasAccess = fileURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { fileURL.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: fileURL)
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let rawURL = plist["URL"] as? String,
              let url = URLComponents(string: rawURL),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              MapLinkMetadata.provider(for: rawURL) != nil else {
            throw MapsLinkFileError.invalidFile
        }

        if artifacts.contains(where: { $0.sourceURL == rawURL }) {
            return rawURL
        }
        try await save(Artifact(
            kind: .url,
            sourceURL: rawURL,
            originalText: MapLinkMetadata.placeName(from: rawURL)
        ))
        return rawURL
    }

    func importAppleGuidePlaces(from rawURL: String) async throws -> AppleGuideImportSummary {
        let expanded = await URLSessionMapLinkExpander().expandedURL(for: rawURL)
        let guide = try AppleMapsGuideParser.parse(expanded)
        var existingURLs = Set(artifacts.compactMap(\.sourceURL))
        var additions: [Artifact] = []
        var duplicates = 0
        var failed = 0

        for rawIdentifier in guide.placeIdentifiers {
            let placeURL = "https://maps.apple.com/place?place-id=\(rawIdentifier)"
            guard existingURLs.insert(placeURL).inserted else {
                duplicates += 1
                continue
            }
            guard let identifier = MKMapItem.Identifier(rawValue: rawIdentifier) else {
                failed += 1
                continue
            }
            do {
                let item = try await MKMapItemRequest(mapItemIdentifier: identifier).mapItem
                guard let name = item.name, !name.isEmpty else {
                    failed += 1
                    continue
                }
                let coordinate = item.location.coordinate
                let place = SavedPlace(
                    id: item.identifier?.rawValue ?? rawIdentifier,
                    name: name,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    locality: item.addressRepresentations?.cityName,
                    region: nil,
                    country: item.addressRepresentations?.regionName
                )
                additions.append(Artifact(
                    kind: .url,
                    sourceURL: placeURL,
                    originalText: name,
                    place: place,
                    processingState: .processed
                ))
            } catch {
                failed += 1
            }
        }

        if !additions.isEmpty {
            try await repository.saveMany(additions)
            artifacts.insert(contentsOf: additions, at: 0)
            processPendingEnrichment()
        }
        return AppleGuideImportSummary(
            title: guide.title,
            imported: additions.count,
            duplicates: duplicates,
            skipped: failed,
            countries: Set(additions.compactMap { $0.place?.country }).count,
            cities: Set(additions.compactMap { $0.place?.locality }).count
        )
    }
}

struct AppleGuideImportSummary {
    let title: String
    let imported: Int
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

private enum CSVImportError: LocalizedError {
    case invalidEncoding

    var errorDescription: String? { "This CSV isn't UTF-8 text." }
}

private enum MapsLinkFileError: LocalizedError {
    case invalidFile

    var errorDescription: String? {
        switch self {
        case .invalidFile: "This file doesn't contain an Apple Maps or Google Maps link."
        }
    }
}
