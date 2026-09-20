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
    let updatedArtifacts: [Artifact]
    let duplicates: Int
    let skipped: Int
}

struct GoogleMapsListImportPlan {
    let title: String
    let artifacts: [Artifact]
    let updatedArtifacts: [Artifact]
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
        let existingByURL = Dictionary(
            existingArtifacts.compactMap { artifact in artifact.sourceURL.map { ($0, artifact) } },
            uniquingKeysWith: { first, _ in first }
        )
        var existingURLs = Set(existingByURL.keys)
        var additions = [Artifact]()
        var updates = [Artifact]()
        var duplicates = 0
        var failed = 0

        for rawIdentifier in guide.placeIdentifiers {
            let placeURL = "https://maps.apple.com/place?place-id=\(rawIdentifier)"
            guard existingURLs.insert(placeURL).inserted else {
                duplicates += 1
                if let existing = existingByURL[placeURL],
                   !existing.sourceCollectionTitles.contains(where: {
                       $0.caseInsensitiveCompare(guide.title) == .orderedSame
                   }) {
                    updates.append(existing.withSourceCollectionTitle(guide.title))
                }
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
                    sourceCollectionTitle: guide.title,
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
            updatedArtifacts: updates,
            duplicates: duplicates,
            skipped: failed
        )
    }

    static func googleMapsList(
        _ rawURL: String,
        existingArtifacts: [Artifact]
    ) async throws -> GoogleMapsListImportPlan {
        let list = try await GoogleMapsListImporter.load(rawURL)
        return googleMapsList(list, existingArtifacts: existingArtifacts)
    }

    static func googleMapsList(
        _ list: GoogleMapsList,
        existingArtifacts: [Artifact]
    ) -> GoogleMapsListImportPlan {
        var existingByIdentity = [String: Artifact]()
        for artifact in existingArtifacts {
            guard let sourceURL = artifact.sourceURL else { continue }
            existingByIdentity[GoogleMapsListPlace.importIdentity(for: sourceURL)] = artifact
        }
        var seenURLs = Set(existingByIdentity.keys)
        var additions = [Artifact]()
        var updates = [Artifact]()
        var duplicates = 0

        for place in list.places {
            guard seenURLs.insert(place.importIdentity).inserted else {
                duplicates += 1
                if let existing = existingByIdentity[place.importIdentity] {
                    var updated = existing
                    if existing.sourceURL != place.sourceURL,
                       existing.place == nil,
                       [.saved, .needsReview, .failed].contains(existing.processingState) {
                        updated = updated.withSourceURL(place.sourceURL, processingState: .saved)
                    }
                    if !updated.sourceCollectionTitles.contains(where: {
                        $0.caseInsensitiveCompare(list.title) == .orderedSame
                    }) {
                        updated = updated.withSourceCollectionTitle(list.title)
                    }
                    if updated != existing {
                        updates.append(updated)
                    }
                }
                continue
            }
            additions.append(Artifact(
                kind: .url,
                sourceURL: place.sourceURL,
                sourceCollectionTitle: list.title,
                originalText: place.title,
                userNote: place.note
            ))
        }

        return GoogleMapsListImportPlan(
            title: list.title,
            artifacts: additions,
            updatedArtifacts: updates,
            duplicates: duplicates,
            skipped: 0
        )
    }
}

enum CSVImportError: LocalizedError {
    case invalidEncoding

    var errorDescription: String? { String(localized: "This CSV isn't UTF-8 text.") }
}

enum MapsLinkFileError: LocalizedError {
    case invalidFile

    var errorDescription: String? { String(localized: "This file doesn't contain an Apple Maps or Google Maps link.") }
}
