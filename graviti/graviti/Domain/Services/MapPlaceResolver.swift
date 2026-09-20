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

        let query = MapLinkMetadata.searchQuery(from: expanded) ?? name
        let candidates = try await searchProvider.search(query)
        let exact = candidates.filter { normalized($0.place.name) == normalized(name) }
        let unique = Dictionary(exact.map { ($0.place.id, $0.place) }, uniquingKeysWith: { first, _ in first })
        if unique.count == 1, let place = unique.values.first {
            return .matched(place)
        }

        guard let hint = MapLinkMetadata.coordinateHint(from: expanded) else { return .needsReview }
        let nearby = Dictionary(candidates.map { ($0.place.id, $0.place) }, uniquingKeysWith: { first, _ in first })
            .values
            .map { ($0, distance(from: hint, to: $0)) }
            .filter { $0.1 <= 250 && namesAreCompatible(name, $0.0.name) }
            .sorted { $0.1 < $1.1 }
        guard let best = nearby.first,
              nearby.count == 1 || nearby[1].1 - best.1 >= 25 else { return .needsReview }
        return .matched(best.0)
    }

    private func normalized(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: " ")
    }

    private func namesAreCompatible(_ expected: String, _ candidate: String) -> Bool {
        let expectedName = normalized(expected)
        let candidateName = normalized(candidate)
        if expectedName.contains(candidateName) || candidateName.contains(expectedName) { return true }
        let expectedTokens = Set(expectedName.split(separator: " ").map(String.init).filter { $0.count > 1 })
        let candidateTokens = Set(candidateName.split(separator: " ").map(String.init).filter { $0.count > 1 })
        guard !expectedTokens.isEmpty, !candidateTokens.isEmpty else { return false }
        let overlap = expectedTokens.intersection(candidateTokens).count
        return Double(overlap) / Double(min(expectedTokens.count, candidateTokens.count)) >= 0.6
    }

    private func distance(from hint: MapLinkMetadata.Coordinate, to place: SavedPlace) -> Double {
        let earthRadius = 6_371_000.0
        let latitudeDelta = (place.latitude - hint.latitude) * .pi / 180
        let longitudeDelta = (place.longitude - hint.longitude) * .pi / 180
        let startLatitude = hint.latitude * .pi / 180
        let endLatitude = place.latitude * .pi / 180
        let a = sin(latitudeDelta / 2) * sin(latitudeDelta / 2)
            + cos(startLatitude) * cos(endLatitude)
            * sin(longitudeDelta / 2) * sin(longitudeDelta / 2)
        let clamped = min(1, max(0, a))
        return earthRadius * 2 * atan2(sqrt(clamped), sqrt(1 - clamped))
    }
}
