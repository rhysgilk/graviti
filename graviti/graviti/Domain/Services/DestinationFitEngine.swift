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
    let knowledgeConfidencePercent: Int
    let knowledgeSources: [DestinationKnowledgeSource]
    let matchedInterests: [String]
    let supportingArtifacts: [Artifact]
    let explicitMatches: [String]
    let visitedLikedMatches: [String]

    var id: String { "\(name), \(country)" }
    var scoreLabel: String { confidence == .early ? confidence.displayName : "\(fitPercent) FIT" }
}

enum RecommendationRegion: String, Codable, CaseIterable, Identifiable {
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
    var visitedLikedDestinationIDs: Set<String> = []
    var visitedNotFitDestinationIDs: Set<String> = []

    var visitedDestinationIDs: Set<String> {
        visitedLikedDestinationIDs.union(visitedNotFitDestinationIDs)
    }
}

struct SavedDestination: Identifiable, Hashable {
    let name: String
    let country: String
    let searchSpan: Double

    init(name: String, country: String, searchSpan: Double = 0.35) {
        self.name = name
        self.country = country
        self.searchSpan = searchSpan
    }

    var id: String { "\(name), \(country)" }
}

enum DestinationFitEngine {
    private struct UserSignal {
        let name: String
        let weight: Double
        let isExplicit: Bool
        let isVisitedLiked: Bool
    }

    static func recommendations(
        from profile: InterestProfile,
        artifacts: [Artifact],
        preferences: ExplorePreferences = ExplorePreferences(),
        limit: Int = 3,
        catalog: DestinationKnowledgeCatalog = DestinationKnowledgeCatalogLoader.bundled
    ) -> [DestinationRecommendation] {
        let signals = userSignals(from: profile, preferences: preferences, catalog: catalog)
        guard !signals.isEmpty else { return [] }
        let totalSignalWeight = signals.reduce(0) { $0 + $1.weight }
        let savedAreas = Set(artifacts.compactMap(\.place).flatMap { place in
            [place.locality, place.region, place.country].compactMap { $0?.foldedKey }
        })

        return catalog.destinations.compactMap { candidate -> DestinationRecommendation? in
            guard !preferences.excludedDestinationIDs.contains(candidate.id) else { return nil }
            guard !preferences.visitedDestinationIDs.contains(candidate.id) else { return nil }
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
            let visitedLikedMatches = matchedNames.filter { name in
                matches.contains { $0.0.name == name && $0.0.isVisitedLiked }
            }
            let userConfidence = evidenceConfidence(
                for: evidence,
                visitedLikedMatchCount: visitedLikedMatches.count
            )
            let combinedConfidence = min(userConfidence, candidate.dataConfidence)
            let confidence = confidenceBand(for: combinedConfidence)
            // Both personal evidence and reviewed destination knowledge limit certainty.
            let fit = 0.5 + (rawRelevance - 0.5) * combinedConfidence

            return DestinationRecommendation(
                name: candidate.name,
                country: candidate.country,
                fitPercent: Int((fit * 100).rounded()),
                relevancePercent: Int((rawRelevance * 100).rounded()),
                confidence: confidence,
                confidencePercent: Int((combinedConfidence * 100).rounded()),
                knowledgeConfidencePercent: Int((candidate.dataConfidence * 100).rounded()),
                knowledgeSources: candidate.sources,
                matchedInterests: matchedNames,
                supportingArtifacts: evidence,
                explicitMatches: matchedNames.filter { preferences.preferredInterests.contains($0) },
                visitedLikedMatches: visitedLikedMatches
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

    static func savedDestination(
        for id: String,
        catalog: DestinationKnowledgeCatalog = DestinationKnowledgeCatalogLoader.bundled
    ) -> SavedDestination? {
        catalog.destinations.first { $0.id == id }.map {
            SavedDestination(name: $0.name, country: $0.country, searchSpan: $0.searchSpan)
        }
    }

    static func fitGuide(
        for id: String,
        from profile: InterestProfile,
        preferences: ExplorePreferences = ExplorePreferences(),
        catalog: DestinationKnowledgeCatalog = DestinationKnowledgeCatalogLoader.bundled
    ) -> FitGuide? {
        guard let candidate = catalog.destinations.first(where: { $0.id == id }) else { return nil }
        let signals = userSignals(from: profile, preferences: preferences, catalog: catalog)
        let matched = signals.compactMap { signal -> (String, Double)? in
            candidate.strengths[signal.name].map { (signal.name, signal.weight * $0) }
        }
        .sorted { $0.1 > $1.1 }
        .map(\.0)

        let interests = Array((matched.isEmpty
            ? candidate.strengths.sorted { $0.value > $1.value }.map(\.key)
            : matched).prefix(4))
        return FitGuide(
            destination: SavedDestination(name: candidate.name, country: candidate.country, searchSpan: candidate.searchSpan),
            interests: interests
        )
    }

    private static func userSignals(
        from profile: InterestProfile,
        preferences: ExplorePreferences,
        catalog: DestinationKnowledgeCatalog
    ) -> [UserSignal] {
        var signals = Dictionary(uniqueKeysWithValues: profile.interests.map { pattern in
            let spread = 1 + 0.22 * Double(min(pattern.areaCount, 4))
            let duplicateDiscount = min(1, 0.55 + 0.15 * Double(max(1, pattern.placeCount)))
            let collectionDiversity = Set(pattern.artifacts.flatMap(\.sourceCollectionTitles).map(\.foldedKey)).count
            let collectionDiscount = pattern.saveCount > 2 && collectionDiversity == 1 ? 0.82 : 1
            let evidenceQuality = averageEvidenceQuality(for: pattern)
            let weight = sqrt(Double(pattern.saveCount)) * spread * duplicateDiscount * collectionDiscount * evidenceQuality
            return (pattern.name, UserSignal(
                name: pattern.name,
                weight: weight,
                isExplicit: false,
                isVisitedLiked: false
            ))
        })
        for interest in preferences.preferredInterests {
            let existing = signals[interest]
            signals[interest] = UserSignal(
                name: interest,
                weight: (existing?.weight ?? 0) + 2.5,
                isExplicit: true,
                isVisitedLiked: existing?.isVisitedLiked ?? false
            )
        }
        for destinationID in preferences.visitedLikedDestinationIDs.sorted() {
            guard let destination = catalog.destinations.first(where: { $0.id == destinationID }) else { continue }
            for (interest, strength) in destination.strengths
                .filter({ $0.value >= 0.65 })
                .sorted(by: {
                    if $0.value != $1.value { return $0.value > $1.value }
                    return $0.key < $1.key
                })
                .prefix(4) {
                let existing = signals[interest]
                signals[interest] = UserSignal(
                    name: interest,
                    weight: min(2, (existing?.weight ?? 0) + 0.8 * strength),
                    isExplicit: existing?.isExplicit ?? false,
                    isVisitedLiked: true
                )
            }
        }
        return Array(signals.values)
    }

    private static func averageEvidenceQuality(for pattern: InterestPattern) -> Double {
        let values = pattern.artifacts.map { artifact -> Double in
            guard let evidence = artifact.enrichment?.interestEvidence?.first(where: { $0.interest == pattern.name }) else {
                return 1
            }
            let sourceWeight: Double = switch evidence.source {
            case .userNote: 1.18
            case .originalText: 1.06
            case .detectedText: 1.0
            case .mapPlace: 0.94
            case .collectionTitle: 0.9
            case .linkMetadata: 0.86
            }
            return sourceWeight * max(0.65, evidence.confidence)
        }
        guard !values.isEmpty else { return 1 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func evidenceConfidence(
        for artifacts: [Artifact],
        visitedLikedMatchCount: Int = 0
    ) -> Double {
        let feedbackConfidence = visitedLikedMatchCount == 0
            ? 0.18
            : min(0.42, 0.26 + 0.05 * Double(visitedLikedMatchCount))
        guard !artifacts.isEmpty else { return feedbackConfidence }
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
        return min(0.94, max(feedbackConfidence, base * independence))
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
