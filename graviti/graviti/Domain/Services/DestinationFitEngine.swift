import Foundation

enum FitConfidence: String {
    case early
    case developing
    case strong

    var displayName: String {
        switch self {
        case .early: String(localized: "Early signal")
        case .developing: String(localized: "Developing signal")
        case .strong: String(localized: "Strong signal")
        }
    }
}

struct DestinationRecommendation: Identifiable {
    let name: String
    let country: String
    let fitPercent: Int
    let relevancePercent: Int
    let confidence: FitConfidence
    let confidencePercent: Int
    let matchedInterests: [String]
    let supportingArtifacts: [Artifact]
    let explicitMatches: [String]

    var id: String { "\(name), \(country)" }
    var scoreLabel: String { confidence == .early ? confidence.displayName : "\(fitPercent) FIT" }
}

enum RecommendationRegion: String, CaseIterable, Identifiable {
    case anywhere
    case asia
    case europe
    case northAmerica

    var id: Self { self }
    var displayName: String {
        switch self {
        case .anywhere: String(localized: "Anywhere")
        case .asia: String(localized: "Asia")
        case .europe: String(localized: "Europe")
        case .northAmerica: String(localized: "North America")
        }
    }
}

struct ExplorePreferences: Equatable {
    var region: RecommendationRegion = .anywhere
    var preferredInterests: Set<String> = []
    var avoidedInterests: Set<String> = []
    var excludedDestinationIDs: Set<String> = []
}

struct SavedDestination: Identifiable, Hashable {
    let name: String
    let country: String

    var id: String { "\(name), \(country)" }
}

enum DestinationFitEngine {
    private struct Candidate {
        let name: String
        let country: String
        let region: RecommendationRegion
        /// Values from 0...1 describe how characteristic each interest is of this destination.
        let strengths: [String: Double]

        var id: String { "\(name), \(country)" }
    }

    private struct UserSignal {
        let name: String
        let weight: Double
        let isExplicit: Bool
    }

    private static let candidates: [Candidate] = [
        Candidate(name: "Uji", country: "Japan", region: .asia, strengths: ["Matcha": 1, "Tea": 1, "Gardens": 0.7, "Architecture": 0.6, "History": 0.7]),
        Candidate(name: "Kyoto", country: "Japan", region: .asia, strengths: ["Matcha": 0.85, "Tea": 0.9, "Gardens": 1, "Architecture": 0.95, "Museums": 0.65, "History": 0.95]),
        Candidate(name: "Taipei", country: "Taiwan", region: .asia, strengths: ["Matcha": 0.45, "Tea": 0.95, "Coffee": 0.8, "Desserts": 0.8, "Hiking": 0.55]),
        Candidate(name: "Seoul", country: "South Korea", region: .asia, strengths: ["Tea": 0.65, "Coffee": 0.9, "Desserts": 0.85, "Architecture": 0.7, "Shopping": 0.9, "History": 0.65]),
        Candidate(name: "Madeira", country: "Portugal", region: .europe, strengths: ["Scenic views": 1, "Hiking": 0.9, "Nature": 0.9, "Gardens": 0.65, "Mountains": 0.75, "Coast & water": 0.85]),
        Candidate(name: "Norwegian Fjords", country: "Norway", region: .europe, strengths: ["Mountains": 1, "Coast & water": 1, "Scenic views": 1, "Hiking": 0.8, "Nature": 0.95]),
        Candidate(name: "Scottish Highlands", country: "United Kingdom", region: .europe, strengths: ["Mountains": 0.9, "History": 0.8, "Coast & water": 0.7, "Hiking": 0.9, "Forests": 0.65]),
        Candidate(name: "Copenhagen", country: "Denmark", region: .europe, strengths: ["Architecture": 0.95, "Coffee": 0.8, "Museums": 0.85, "Shopping": 0.75, "History": 0.6]),
        Candidate(name: "Lisbon", country: "Portugal", region: .europe, strengths: ["Scenic views": 0.8, "Architecture": 0.9, "Coffee": 0.75, "Museums": 0.65, "History": 0.8, "Seafood": 0.8]),
        Candidate(name: "New York City", country: "United States", region: .northAmerica, strengths: ["Matcha": 0.6, "Tea": 0.65, "Coffee": 0.9, "Desserts": 0.9, "Architecture": 0.9, "Museums": 1, "Shopping": 0.95]),
        Candidate(name: "Mexico City", country: "Mexico", region: .northAmerica, strengths: ["Architecture": 0.95, "Museums": 0.95, "Coffee": 0.75, "Desserts": 0.75, "Shopping": 0.75, "History": 0.9]),
        Candidate(name: "Vancouver", country: "Canada", region: .northAmerica, strengths: ["Scenic views": 0.9, "Hiking": 0.85, "Nature": 0.9, "Coffee": 0.8, "Mountains": 0.8, "Coast & water": 0.8, "Forests": 0.85]),
        Candidate(name: "Seattle", country: "United States", region: .northAmerica, strengths: ["Forests": 0.9, "Hiking": 0.85, "Mountains": 0.8, "Coast & water": 0.75, "Coffee": 1, "Scenic views": 0.75]),
        Candidate(name: "Vermont", country: "United States", region: .northAmerica, strengths: ["Forests": 1, "Hiking": 0.85, "Mountains": 0.7, "Nature": 0.9, "History": 0.55]),
        Candidate(name: "Maine", country: "United States", region: .northAmerica, strengths: ["National parks": 0.8, "Coast & water": 0.95, "Seafood": 1, "Forests": 0.95, "History": 0.65, "Hiking": 0.75]),
        Candidate(name: "California", country: "United States", region: .northAmerica, strengths: ["National parks": 1, "Mountains": 0.85, "Coast & water": 0.8, "Forests": 0.55, "Hiking": 0.85, "Architecture": 0.65, "Seafood": 0.7]),
        Candidate(name: "Alaska", country: "United States", region: .northAmerica, strengths: ["National parks": 0.95, "Mountains": 1, "Coast & water": 0.8, "Wildlife": 1, "Hiking": 0.8, "Forests": 0.7]),
        Candidate(name: "Kauai", country: "United States", region: .northAmerica, strengths: ["Scenic views": 1, "Hiking": 0.85, "Nature": 0.95, "Beaches": 1, "Coast & water": 1, "Mountains": 0.75])
    ]

    static func recommendations(
        from profile: InterestProfile,
        artifacts: [Artifact],
        preferences: ExplorePreferences = ExplorePreferences(),
        limit: Int = 3
    ) -> [DestinationRecommendation] {
        let signals = userSignals(from: profile, preferences: preferences)
        guard !signals.isEmpty else { return [] }
        let totalSignalWeight = signals.reduce(0) { $0 + $1.weight }
        let savedAreas = Set(artifacts.compactMap(\.place).flatMap { place in
            [place.locality, place.region, place.country].compactMap { $0?.foldedKey }
        })

        return candidates.compactMap { candidate -> DestinationRecommendation? in
            guard !preferences.excludedDestinationIDs.contains(candidate.id) else { return nil }
            guard !savedAreas.contains(candidate.name.foldedKey) else { return nil }
            guard preferences.region == .anywhere || candidate.region == preferences.region else { return nil }
            guard Set(candidate.strengths.keys).isDisjoint(with: preferences.avoidedInterests) else { return nil }

            let matches = signals.compactMap { signal -> (UserSignal, Double)? in
                candidate.strengths[signal.name].map { (signal, $0) }
            }.sorted { $0.0.weight * $0.1 > $1.0.weight * $1.1 }
            guard !matches.isEmpty else { return nil }

            let matchedWeight = matches.reduce(0) { $0 + $1.0.weight * $1.1 }
            let affinity = min(1, matchedWeight / max(totalSignalWeight, 1))
            let specificity = matches.reduce(0) { $0 + $1.1 } / Double(matches.count)
            let breadth = min(1, Double(matches.count) / 4)
            let explicitBoost = matches.contains(where: { $0.0.isExplicit }) ? 0.06 : 0
            let rawRelevance = min(0.96, 0.30 + affinity * 0.44 + specificity * 0.14 + breadth * 0.08 + explicitBoost)

            let matchedNames = matches.prefix(4).map { $0.0.name }
            let matchedSet = Set(matchedNames)
            let evidence = artifacts.filter { !Set($0.effectiveInterests).isDisjoint(with: matchedSet) }
            let confidenceValue = evidenceConfidence(for: evidence)
            let confidence = confidenceBand(for: confidenceValue)
            // Shrink uncertain relevance toward a neutral 50 instead of presenting false certainty.
            let fit = 0.5 + (rawRelevance - 0.5) * confidenceValue

            return DestinationRecommendation(
                name: candidate.name,
                country: candidate.country,
                fitPercent: Int((fit * 100).rounded()),
                relevancePercent: Int((rawRelevance * 100).rounded()),
                confidence: confidence,
                confidencePercent: Int((confidenceValue * 100).rounded()),
                matchedInterests: matchedNames,
                supportingArtifacts: evidence,
                explicitMatches: matchedNames.filter { preferences.preferredInterests.contains($0) }
            )
        }
        .sorted {
            if $0.fitPercent != $1.fitPercent { return $0.fitPercent > $1.fitPercent }
            if $0.confidencePercent != $1.confidencePercent { return $0.confidencePercent > $1.confidencePercent }
            return $0.name < $1.name
        }
        .prefix(limit)
        .map { $0 }
    }

    static func savedDestination(for id: String) -> SavedDestination? {
        candidates.first { $0.id == id }.map { SavedDestination(name: $0.name, country: $0.country) }
    }

    private static func userSignals(from profile: InterestProfile, preferences: ExplorePreferences) -> [UserSignal] {
        var signals = Dictionary(uniqueKeysWithValues: profile.interests.map { pattern in
            let spread = 1 + 0.22 * Double(min(pattern.areaCount, 4))
            let duplicateDiscount = min(1, 0.55 + 0.15 * Double(max(1, pattern.placeCount)))
            let weight = sqrt(Double(pattern.saveCount)) * spread * duplicateDiscount
            return (pattern.name, UserSignal(name: pattern.name, weight: weight, isExplicit: false))
        })
        for interest in preferences.preferredInterests {
            let existing = signals[interest]
            signals[interest] = UserSignal(name: interest, weight: (existing?.weight ?? 0) + 2.5, isExplicit: true)
        }
        return Array(signals.values)
    }

    private static func evidenceConfidence(for artifacts: [Artifact]) -> Double {
        guard !artifacts.isEmpty else { return 0.18 }
        let places = Set(artifacts.compactMap { $0.place?.id })
        let areas = Set(artifacts.compactMap { artifact -> String? in
            guard let place = artifact.place else { return nil }
            return [place.locality, place.region, place.country].compactMap { $0?.foldedKey }.joined(separator: "|")
        })
        let sourceKinds = Set(artifacts.map(\.kind))
        let richEvidence = artifacts.filter { artifact in
            let noteLength = artifact.userNote?.trimmingCharacters(in: .whitespacesAndNewlines).count ?? 0
            let summaryLength = artifact.effectiveSummary?.trimmingCharacters(in: .whitespacesAndNewlines).count ?? 0
            return noteLength >= 20 || summaryLength >= 30
        }.count

        let effectiveEvidence =
            Double(min(artifacts.count, 8)) * 0.45 +
            Double(min(places.count, 5)) * 0.8 +
            Double(min(areas.count, 4)) * 0.9 +
            Double(min(sourceKinds.count, 3)) * 0.35 +
            Double(min(richEvidence, 5)) * 0.35
        let base = 1 - exp(-effectiveEvidence / 7)
        let independence = min(1, 0.62 + 0.13 * Double(min(places.count, 3)) + 0.08 * Double(min(areas.count, 3)))
        return min(0.94, max(0.18, base * independence))
    }

    private static func confidenceBand(for value: Double) -> FitConfidence {
        if value < 0.48 { return .early }
        if value < 0.75 { return .developing }
        return .strong
    }
}

private extension String {
    var foldedKey: String { folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) }
}
