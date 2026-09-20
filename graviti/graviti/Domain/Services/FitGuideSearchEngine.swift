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

    static func searchTerm(for interest: String) -> String {
        searchTerms(for: interest)[0]
    }

    static func searchTerms(for interest: String) -> [String] {
        switch interest {
        case "Matcha": ["matcha cafe", "matcha"]
        case "Tea": ["tea house", "tea"]
        case "Coffee": ["coffee shop", "cafe"]
        case "Desserts": ["dessert shop", "bakery"]
        case "Seafood": ["seafood restaurant"]
        case "Scenic views": ["scenic viewpoint", "observation deck"]
        case "Hiking": ["hiking trail", "trailhead"]
        case "Forests": ["forest", "woodland park"]
        case "Mountains": ["mountain", "mountain peak"]
        case "National parks": ["national park"]
        case "Nature": ["nature reserve", "nature park"]
        case "Beaches": ["beach"]
        case "Coast & water": ["waterfront", "lake"]
        case "Architecture": ["architectural landmark", "historic landmark"]
        case "History": ["historic site", "historical landmark"]
        case "Museums": ["museum"]
        case "Gardens": ["garden", "botanical garden"]
        case "Shopping": ["shopping", "market"]
        case "Wildlife": ["wildlife attraction", "wildlife refuge"]
        default: [InterestDisplayName.localized(interest)]
        }
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
            var matches = [PlaceCandidate]()
            for term in searchTerms(for: interest) {
                matches = try await provider.search(term, near: guide.destination)
                if !matches.isEmpty { break }
            }
            let unique = matches.filter { seenPlaceIDs.insert($0.id).inserted }
            let places = Array(unique.prefix(limitPerInterest))
            if !places.isEmpty {
                sections.append(FitGuideSection(interest: interest, places: places))
            }
        }
        return sections
    }
}
