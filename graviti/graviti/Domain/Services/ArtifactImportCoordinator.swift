import Foundation
import MapKit

struct ArtifactImportPlan {
    let artifacts: [Artifact]
    let duplicates: Int
    let skipped: Int
}

struct MapsLinkImportPlan {
    let rawURL: String
    let artifact: Artifact?
}

struct AppleGuideImportPlan {
    let title: String
    let artifacts: [Artifact]
    let duplicates: Int
    let skipped: Int
}

enum ArtifactImportCoordinator {
    static func googleCSV(_ text: String, existingArtifacts: [Artifact]) throws -> ArtifactImportPlan {
        let parsed = try GoogleSavedCSVParser.parse(text)
        struct ImportKey: Hashable {
            let url: String
            let title: String
            let note: String?
        }
        var seen = Set(existingArtifacts.compactMap { artifact -> ImportKey? in
            guard let url = artifact.sourceURL, let title = artifact.originalText else { return nil }
            return ImportKey(url: url, title: title, note: artifact.userNote)
        })
        var additions = [Artifact]()
        var duplicates = 0
        for row in parsed.rows {
            let key = ImportKey(url: row.url, title: row.title, note: row.note)
            guard seen.insert(key).inserted else {
                duplicates += 1
                continue
            }
            additions.append(Artifact(
                kind: .url,
                sourceURL: row.url,
                originalText: row.title,
                userNote: row.note
            ))
        }
        return ArtifactImportPlan(artifacts: additions, duplicates: duplicates, skipped: parsed.skippedRows)
    }

    static func mapsLinkFile(_ data: Data, existingArtifacts: [Artifact]) throws -> MapsLinkImportPlan {
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let rawURL = plist["URL"] as? String,
              let url = URLComponents(string: rawURL),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              MapLinkMetadata.provider(for: rawURL) != nil else {
            throw MapsLinkFileError.invalidFile
        }
        let artifact = existingArtifacts.contains(where: { $0.sourceURL == rawURL }) ? nil : Artifact(
            kind: .url,
            sourceURL: rawURL,
            originalText: MapLinkMetadata.placeName(from: rawURL)
        )
        return MapsLinkImportPlan(rawURL: rawURL, artifact: artifact)
    }

    static func appleGuide(_ rawURL: String, existingArtifacts: [Artifact]) async throws -> AppleGuideImportPlan {
        let expanded = await URLSessionMapLinkExpander().expandedURL(for: rawURL)
        let guide = try AppleMapsGuideParser.parse(expanded)
        var existingURLs = Set(existingArtifacts.compactMap(\.sourceURL))
        var additions = [Artifact]()
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
                guard let place = MapItemPlaceAdapter.savedPlace(from: item, fallbackID: rawIdentifier) else {
                    failed += 1
                    continue
                }
                additions.append(Artifact(
                    kind: .url,
                    sourceURL: placeURL,
                    originalText: place.name,
                    place: place,
                    processingState: .processed
                ))
            } catch {
                failed += 1
            }
        }
        return AppleGuideImportPlan(
            title: guide.title,
            artifacts: additions,
            duplicates: duplicates,
            skipped: failed
        )
    }
}

enum CSVImportError: LocalizedError {
    case invalidEncoding

    var errorDescription: String? { "This CSV isn't UTF-8 text." }
}

enum MapsLinkFileError: LocalizedError {
    case invalidFile

    var errorDescription: String? { "This file doesn't contain an Apple Maps or Google Maps link." }
}
