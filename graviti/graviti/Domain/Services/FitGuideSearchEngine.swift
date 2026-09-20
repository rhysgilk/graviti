import Foundation

struct FitGuideSection: Identifiable, Hashable {
    let interest: String
    let places: [PlaceCandidate]

    var id: String { interest }
}

enum FitGuideSearchEngine {
    static func query(for interest: String, destination: SavedDestination) -> String {
        "\(InterestDisplayName.localized(interest)) in \(destination.name), \(destination.country)"
    }

    @MainActor
    static func search(
        guide: FitGuide,
        using provider: any PlaceSearchProviding,
        limitPerInterest: Int = 6
    ) async throws -> [FitGuideSection] {
        var seenPlaceIDs = Set<String>()
        var sections = [FitGuideSection]()

        for interest in guide.interests {
            try Task.checkCancellation()
            let matches = try await provider.search(query(for: interest, destination: guide.destination))
            let unique = matches.filter { seenPlaceIDs.insert($0.id).inserted }
            let places = Array(unique.prefix(limitPerInterest))
            if !places.isEmpty {
                sections.append(FitGuideSection(interest: interest, places: places))
            }
        }
        return sections
    }
}
