import Foundation

enum MapPlaceResolution {
    case matched(SavedPlace)
    case needsReview
    case collection
}

@MainActor
protocol MapLinkExpanding {
    func expandedURL(for rawURL: String) async -> String
}

@MainActor
struct URLSessionMapLinkExpander: MapLinkExpanding {
    func expandedURL(for rawURL: String) async -> String {
        guard let url = URL(string: rawURL),
              let host = url.host?.lowercased(),
              ["maps.apple", "maps.app.goo.gl", "goo.gl"].contains(host) else {
            return rawURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return response.url?.absoluteString ?? rawURL
        } catch {
            return rawURL
        }
    }
}

@MainActor
struct MapPlaceResolver {
    let searchProvider: any PlaceSearchProviding
    let linkExpander: any MapLinkExpanding

    func resolve(_ artifact: Artifact) async throws -> MapPlaceResolution {
        guard let rawURL = artifact.sourceURL,
              MapLinkMetadata.provider(for: rawURL) != nil else {
            return .needsReview
        }
        if MapLinkMetadata.isCollectionLink(rawURL) { return .collection }

        let expanded = await linkExpander.expandedURL(for: rawURL)
        if MapLinkMetadata.isCollectionLink(expanded) { return .collection }

        let name = MapLinkMetadata.placeName(from: expanded)
            ?? artifact.originalText?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let name, name.count >= 3 else { return .needsReview }

        let candidates = try await searchProvider.search(name)
        let exact = candidates.filter { normalized($0.place.name) == normalized(name) }
        let unique = Dictionary(exact.map { ($0.place.id, $0.place) }, uniquingKeysWith: { first, _ in first })
        guard unique.count == 1, let place = unique.values.first else { return .needsReview }
        return .matched(place)
    }

    private func normalized(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: " ")
    }
}
