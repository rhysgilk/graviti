import Foundation

struct DestinationRecommendation: Identifiable {
    let name: String
    let country: String
    let fitPercent: Int
    let matchedInterests: [String]
    let supportingArtifacts: [Artifact]
    let explicitMatches: [String]

    var id: String { "\(name), \(country)" }
}

enum RecommendationRegion: String, CaseIterable, Identifiable {
    case anywhere
    case asia
    case europe
    case northAmerica

    var id: Self { self }

    var displayName: String {
        switch self {
        case .anywhere: "Anywhere"
        case .asia: "Asia"
        case .europe: "Europe"
        case .northAmerica: "North America"
        }
    }
}

struct ExplorePreferences: Equatable {
    var region: RecommendationRegion = .anywhere
    var preferredInterests: Set<String> = []
    var avoidedInterests: Set<String> = []
}

enum DestinationFitEngine {
    private struct Candidate {
        let name: String
        let country: String
        let region: RecommendationRegion
        let interests: Set<String>
    }

    private static let candidates: [Candidate] = [
        Candidate(name: "Kyoto", country: "Japan", region: .asia, interests: ["Matcha", "Tea", "Gardens", "Architecture", "Museums"]),
        Candidate(name: "Taipei", country: "Taiwan", region: .asia, interests: ["Matcha", "Tea", "Coffee", "Desserts", "Hiking"]),
        Candidate(name: "Uji", country: "Japan", region: .asia, interests: ["Matcha", "Tea", "Gardens", "Architecture"]),
        Candidate(name: "Madeira", country: "Portugal", region: .europe, interests: ["Scenic views", "Hiking", "Nature", "Gardens"]),
        Candidate(name: "Copenhagen", country: "Denmark", region: .europe, interests: ["Architecture", "Coffee", "Museums", "Shopping"]),
        Candidate(name: "Mexico City", country: "Mexico", region: .northAmerica, interests: ["Architecture", "Museums", "Coffee", "Desserts", "Shopping"]),
        Candidate(name: "Vancouver", country: "Canada", region: .northAmerica, interests: ["Scenic views", "Hiking", "Nature", "Coffee"]),
        Candidate(name: "Seoul", country: "South Korea", region: .asia, interests: ["Tea", "Coffee", "Desserts", "Architecture", "Shopping"]),
        Candidate(name: "Lisbon", country: "Portugal", region: .europe, interests: ["Scenic views", "Architecture", "Coffee", "Museums"]),
        Candidate(name: "Kauai", country: "United States", region: .northAmerica, interests: ["Scenic views", "Hiking", "Nature", "Beaches"])
    ]

    static func recommendations(from profile: InterestProfile, artifacts: [Artifact], preferences: ExplorePreferences = ExplorePreferences(), limit: Int = 3) -> [DestinationRecommendation] {
        var weighted = Dictionary(uniqueKeysWithValues: profile.interests.map { pattern in
            (pattern.name, Double(pattern.saveCount) + Double(pattern.areaCount) * 1.5)
        })
        for interest in preferences.preferredInterests {
            weighted[interest, default: 0] += 8
        }
        guard !weighted.isEmpty else { return [] }
        let strongestWeight = weighted.values.max() ?? 1
        let savedAreas = Set(artifacts.compactMap(\.place).flatMap { place in
            [place.locality, place.region, place.country].compactMap { $0?.foldedKey }
        })

        return candidates.compactMap { candidate -> DestinationRecommendation? in
            guard !savedAreas.contains(candidate.name.foldedKey) else { return nil }
            guard preferences.region == .anywhere || candidate.region == preferences.region else { return nil }
            guard candidate.interests.isDisjoint(with: preferences.avoidedInterests) else { return nil }
            let matches = candidate.interests.compactMap { interest -> (String, Double)? in
                weighted[interest].map { (interest, $0) }
            }.sorted { $0.1 > $1.1 }
            guard !matches.isEmpty else { return nil }
            let matchWeight = matches.reduce(0) { $0 + $1.1 }
            let coverage = min(1, matchWeight / max(strongestWeight * 2.2, 1))
            let breadth = min(1, Double(matches.count) / 3)
            let fit = Int((55 + coverage * 28 + breadth * 12).rounded())
            let matchedNames = matches.prefix(3).map(\.0)
            let evidence = artifacts.filter { artifact in
                !Set(artifact.effectiveInterests).isDisjoint(with: matchedNames)
            }
            let explicitMatches = matchedNames.filter { preferences.preferredInterests.contains($0) }
            return DestinationRecommendation(
                name: candidate.name,
                country: candidate.country,
                fitPercent: min(fit, 95),
                matchedInterests: matchedNames,
                supportingArtifacts: evidence,
                explicitMatches: explicitMatches
            )
        }
        .sorted {
            if $0.fitPercent != $1.fitPercent { return $0.fitPercent > $1.fitPercent }
            return $0.name < $1.name
        }
        .prefix(limit)
        .map { $0 }
    }
}

private extension String {
    var foldedKey: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
