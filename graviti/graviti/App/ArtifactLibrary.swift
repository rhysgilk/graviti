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

    private func update(_ artifact: Artifact) async throws {
        try await repository.update(artifact)
        guard let index = artifacts.firstIndex(where: { $0.id == artifact.id }) else { return }
        artifacts[index] = artifact
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

    func importSharedArtifacts() async {
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
                }
                try SharedArtifactInbox.remove(fileURL)
            }
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    func importGoogleSavedCSV(from fileURL: URL) async throws -> CSVImportSummary {
        let hasAccess = fileURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { fileURL.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: fileURL)
        guard let text = String(data: data, encoding: .utf8) else {
            throw CSVImportError.invalidEncoding
        }
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
        }
        return CSVImportSummary(
            imported: newArtifacts.count,
            skipped: parsed.skippedRows + duplicateCount
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
        var skipped = 0

        for rawIdentifier in guide.placeIdentifiers {
            let placeURL = "https://maps.apple.com/place?place-id=\(rawIdentifier)"
            guard existingURLs.insert(placeURL).inserted else {
                skipped += 1
                continue
            }
            guard let identifier = MKMapItem.Identifier(rawValue: rawIdentifier) else {
                skipped += 1
                continue
            }
            do {
                let item = try await MKMapItemRequest(mapItemIdentifier: identifier).mapItem
                guard let name = item.name, !name.isEmpty else {
                    skipped += 1
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
                skipped += 1
            }
        }

        if !additions.isEmpty {
            try await repository.saveMany(additions)
            artifacts.insert(contentsOf: additions, at: 0)
        }
        return AppleGuideImportSummary(
            title: guide.title,
            imported: additions.count,
            skipped: skipped
        )
    }
}

struct AppleGuideImportSummary {
    let title: String
    let imported: Int
    let skipped: Int
}

struct CSVImportSummary {
    let imported: Int
    let skipped: Int
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
