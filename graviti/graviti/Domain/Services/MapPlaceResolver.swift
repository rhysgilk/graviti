import Foundation

enum MapPlaceResolution {
    case matched(SavedPlace)
    case needsReview
    case collection
    case unmatched
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
    let socialHintProvider: any SocialPlaceHintProviding

    init(
        searchProvider: any PlaceSearchProviding,
        linkExpander: any MapLinkExpanding,
        socialHintProvider: (any SocialPlaceHintProviding)? = nil
    ) {
        self.searchProvider = searchProvider
        self.linkExpander = linkExpander
        self.socialHintProvider = socialHintProvider ?? DefaultSocialPlaceHintProvider()
    }

    func resolve(_ artifact: Artifact) async throws -> MapPlaceResolution {
        guard let rawURL = artifact.sourceURL else { return .unmatched }
        if MapLinkMetadata.provider(for: rawURL) == nil {
            return try await resolveSocialPlace(artifact)
        }
        if MapLinkMetadata.isCollectionLink(rawURL) { return .collection }

        let expanded = await linkExpander.expandedURL(for: rawURL)
        if MapLinkMetadata.isCollectionLink(expanded) { return .collection }

        let name = MapLinkMetadata.placeName(from: expanded)
            ?? artifact.originalText?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let name, name.count >= 3 else { return .needsReview }

        let richQuery = MapLinkMetadata.searchQuery(from: expanded)
        let queries = searchQueries(richQuery: richQuery, name: name)
        let expectedNames = Set(nameVariants(name).map(normalized).filter { !$0.isEmpty })
        let hint = MapLinkMetadata.coordinateHint(from: expanded)
        var accumulated = [String: SavedPlace]()

        for query in queries {
            let candidates = try await searchProvider.search(query)
            let unique = Dictionary(
                candidates.map { ($0.place.id, $0.place) },
                uniquingKeysWith: { first, _ in first }
            )
            for (id, place) in unique { accumulated[id] = place }

            let exact = unique.values.filter { expectedNames.contains(normalized($0.name)) }
            if exact.count == 1, let place = exact.first {
                return .matched(place)
            }

            if let hint,
               let place = unambiguousNearbyMatch(
                   among: Array(unique.values),
                   expectedName: name,
                   hint: hint
               ) {
                return .matched(place)
            }

            let contextual = unique.values.filter {
                namesAreCompatible(name, $0.name) && locationMatches($0, query: richQuery ?? query)
            }
            if contextual.count == 1, let place = contextual.first {
                return .matched(place)
            }
        }

        if let hint,
           let place = unambiguousNearbyMatch(
               among: Array(accumulated.values),
               expectedName: name,
               hint: hint
           ) {
            return .matched(place)
        }
        return .needsReview
    }

    private func resolveSocialPlace(_ artifact: Artifact) async throws -> MapPlaceResolution {
        guard let hint = socialHintProvider.hint(for: artifact) else { return .unmatched }
        var matches = [String: SavedPlace]()
        for query in hint.queries.prefix(3) {
            for candidate in try await searchProvider.search(query) {
                if socialHintProvider.namesAreCompatible(hint.expectedName, candidate.place.name) {
                    matches[candidate.place.id] = candidate.place
                }
            }
            if matches.count == 1, let match = matches.values.first {
                return .matched(match)
            }
        }
        return .unmatched
    }

    private func searchQueries(richQuery: String?, name: String) -> [String] {
        var seen = Set<String>()
        return Array(([richQuery].compactMap { $0 } + nameVariants(name))
            .map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
            .filter { $0.count >= 2 && seen.insert(normalized($0)).inserted }
            .prefix(4))
    }

    private func nameVariants(_ name: String) -> [String] {
        var variants = [name]
        let withoutBrackets = name.replacingOccurrences(
            of: #"\s*[\(\[\{][^\)\]\}]+[\)\]\}]\s*"#,
            with: " ",
            options: .regularExpression
        )
        variants.append(withoutBrackets)

        let latinOnly = withoutBrackets.unicodeScalars.map { scalar -> String in
            if CharacterSet.letters.contains(scalar), scalar.value > 0x024F { return " " }
            if CharacterSet.controlCharacters.contains(scalar) { return " " }
            return String(scalar)
        }.joined()
        variants.append(latinOnly)

        if let transliterated = withoutBrackets.applyingTransform(.toLatin, reverse: false) {
            variants.append(transliterated)
        }
        return variants
    }

    private func unambiguousNearbyMatch(
        among candidates: [SavedPlace],
        expectedName: String,
        hint: MapLinkMetadata.Coordinate
    ) -> SavedPlace? {
        let nearby = candidates
            .map { ($0, distance(from: hint, to: $0)) }
            .filter { $0.1 <= 250 && namesAreCompatible(expectedName, $0.0.name) }
            .sorted { $0.1 < $1.1 }
        guard let best = nearby.first,
              nearby.count == 1 || nearby[1].1 - best.1 >= 25 else { return nil }
        return best.0
    }

    private func locationMatches(_ place: SavedPlace, query: String) -> Bool {
        let normalizedQuery = normalized(query)
        return [place.locality, place.region, place.country]
            .compactMap { $0 }
            .map(normalized)
            .contains { !$0.isEmpty && normalizedQuery.contains($0) }
    }

    private func normalized(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: " ")
    }

    private func namesAreCompatible(_ expected: String, _ candidate: String) -> Bool {
        let expectedName = normalized(expected)
        let candidateName = normalized(candidate)
        let compactExpected = expectedName.replacingOccurrences(of: " ", with: "")
        let compactCandidate = candidateName.replacingOccurrences(of: " ", with: "")
        if compactExpected == compactCandidate { return true }
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
