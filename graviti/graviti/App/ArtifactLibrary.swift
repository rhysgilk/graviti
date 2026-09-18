import Foundation
import SwiftUI
import Combine

@MainActor
final class ArtifactLibrary: ObservableObject {
    @Published private(set) var artifacts: [Artifact] = []
    @Published private(set) var loadError: String?

    private let repository: any ArtifactRepository

    init(repository: any ArtifactRepository) {
        self.repository = repository
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
    }

    func savePlace(_ candidate: PlaceCandidate) async throws {
        try await save(Artifact(
            kind: .url,
            sourceURL: candidate.sourceURL,
            originalText: candidate.place.name,
            place: candidate.place
        ))
    }

    func importSharedArtifacts() async {
        do {
            for fileURL in try SharedArtifactInbox.pendingFiles() {
                let envelope = try SharedArtifactInbox.read(fileURL)
                if !artifacts.contains(where: { $0.id == envelope.id }) {
                    let artifact = Artifact(
                        id: envelope.id,
                        kind: envelope.sourceURL == nil ? .manual : .url,
                        sourceURL: envelope.sourceURL,
                        originalText: envelope.originalText ?? envelope.sourceURL.flatMap(MapLinkMetadata.placeName),
                        userNote: envelope.userNote,
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
        }
        return CSVImportSummary(
            imported: newArtifacts.count,
            skipped: parsed.skippedRows + duplicateCount
        )
    }

    func importMapsLinkFile(from fileURL: URL) async throws {
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

        guard !artifacts.contains(where: { $0.sourceURL == rawURL }) else {
            throw MapsLinkFileError.alreadySaved
        }
        try await save(Artifact(
            kind: .url,
            sourceURL: rawURL,
            originalText: MapLinkMetadata.placeName(from: rawURL)
        ))
    }
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
    case alreadySaved

    var errorDescription: String? {
        switch self {
        case .invalidFile: "This file doesn't contain an Apple Maps or Google Maps link."
        case .alreadySaved: "This Maps link is already in your Library."
        }
    }
}
