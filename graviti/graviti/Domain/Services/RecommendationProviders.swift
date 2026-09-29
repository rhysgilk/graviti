import Foundation

protocol DestinationKnowledgeProviding {
    var catalog: DestinationKnowledgeCatalog { get }
}

struct BundledDestinationKnowledgeProvider: DestinationKnowledgeProviding {
    let catalog: DestinationKnowledgeCatalog

    init(catalog: DestinationKnowledgeCatalog = DestinationKnowledgeCatalogLoader.bundled) {
        self.catalog = catalog
    }
}

protocol RecommendationRankingProviding {
    func recommendations(
        from profile: InterestProfile,
        artifacts: [Artifact],
        preferences: ExplorePreferences,
        limit: Int,
        catalog: DestinationKnowledgeCatalog
    ) -> [DestinationRecommendation]
    func savedDestination(for id: String, catalog: DestinationKnowledgeCatalog) -> SavedDestination?
    func fitGuide(
        for id: String,
        from profile: InterestProfile,
        preferences: ExplorePreferences,
        catalog: DestinationKnowledgeCatalog
    ) -> FitGuide?
}

struct DefaultRecommendationRankingProvider: RecommendationRankingProviding {
    func recommendations(
        from profile: InterestProfile,
        artifacts: [Artifact],
        preferences: ExplorePreferences,
        limit: Int,
        catalog: DestinationKnowledgeCatalog
    ) -> [DestinationRecommendation] {
        DestinationFitEngine.recommendations(
            from: profile,
            artifacts: artifacts,
            preferences: preferences,
            limit: limit,
            catalog: catalog
        )
    }

    func savedDestination(for id: String, catalog: DestinationKnowledgeCatalog) -> SavedDestination? {
        DestinationFitEngine.savedDestination(for: id, catalog: catalog)
    }

    func fitGuide(
        for id: String,
        from profile: InterestProfile,
        preferences: ExplorePreferences,
        catalog: DestinationKnowledgeCatalog
    ) -> FitGuide? {
        DestinationFitEngine.fitGuide(for: id, from: profile, preferences: preferences, catalog: catalog)
    }
}

enum LibrarySyncHealth: Codable, Equatable {
    case localOnly
    case idle(lastSuccessfulSync: Date?)
    case syncing
    case needsAttention(message: String)
}

protocol LibrarySyncProviding {
    var health: LibrarySyncHealth { get async }
    func synchronize() async throws
}

struct LocalOnlyLibrarySyncProvider: LibrarySyncProviding {
    var health: LibrarySyncHealth { get async { .localOnly } }
    func synchronize() async throws {}
}
