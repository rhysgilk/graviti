import Foundation
import MapKit

@MainActor
struct ArtifactEnricher {
    func enrich(_ artifact: Artifact) async throws -> ArtifactEnrichment? {
        let savedText = [artifact.originalText, artifact.userNote]
            .compactMap { $0 }
            .joined(separator: " ")
        let text = [savedText, artifact.extractedText]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let item: MKMapItem?
        if let place = artifact.place,
           let identifier = MKMapItem.Identifier(rawValue: place.id) {
            do {
                item = try await MKMapItemRequest(mapItemIdentifier: identifier).mapItem
            } catch {
                guard !text.isEmpty else { throw error }
                item = nil
            }
        } else {
            item = nil
        }

        let classification = item?.pointOfInterestCategory.flatMap(classification(for:))
        let interests = interestTags(in: text, category: classification?.category)
        let textCategory = categoryFromText(text)
        let category = classification?.category ?? textCategory

        guard item != nil || category != nil || !interests.isEmpty else { return nil }

        let summary: String?
        if let place = artifact.place,
           let type = classification?.typeName {
            let location = place.locality ?? place.country
            let base = location.map { "\(place.name) is a \(type) in \($0)" }
                ?? "\(place.name) is a \(type)"
            summary = interests.isEmpty
                ? "\(base)."
                : "\(base), saved for \(interestPhrase(interests))."
        } else if let place = artifact.place, !interests.isEmpty {
            summary = "\(place.name) is saved for \(interestPhrase(interests))."
        } else if !interests.isEmpty {
            let subject = artifact.kind == .photo ? "A saved photo" : "A saved idea"
            summary = "\(subject) about \(interestPhrase(interests))."
        } else if let category {
            let subject = artifact.kind == .photo ? "A saved photo" : "A saved idea"
            summary = "\(subject) about \(category.displayName.lowercased())."
        } else {
            summary = nil
        }

        let source: ArtifactEnrichment.Source
        if item != nil, artifact.extractedText != nil {
            source = .mapKitAndDetectedText
        } else if item != nil {
            source = savedText.isEmpty ? .mapKit : .mapKitAndSavedText
        } else if artifact.extractedText != nil {
            source = .detectedText
        } else {
            source = .savedText
        }
        return ArtifactEnrichment(
            summary: summary,
            category: category,
            interests: interests,
            source: source,
            confidence: classification != nil ? 0.9 : 0.55,
            generatedAt: .now
        )
    }

    private func classification(for poi: MKPointOfInterestCategory) -> (category: ExperienceCategory, typeName: String)? {
        switch poi {
        case .restaurant: (.foodAndDrink, "restaurant")
        case .cafe: (.foodAndDrink, "café")
        case .bakery: (.foodAndDrink, "bakery")
        case .foodMarket: (.foodAndDrink, "food market")
        case .brewery: (.foodAndDrink, "brewery")
        case .winery: (.foodAndDrink, "winery")
        case .museum: (.artsAndCulture, "museum")
        case .theater: (.artsAndCulture, "theater")
        case .musicVenue: (.artsAndCulture, "music venue")
        case .park: (.sceneryAndNature, "park")
        case .nationalPark: (.sceneryAndNature, "national park")
        case .beach: (.sceneryAndNature, "beach")
        case .hiking: (.sceneryAndNature, "hiking area")
        case .campground: (.sceneryAndNature, "campground")
        case .landmark: (.landmarks, "landmark")
        case .nationalMonument: (.landmarks, "monument")
        case .castle: (.landmarks, "castle")
        case .store: (.shopping, "shop")
        case .hotel: (.stay, "hotel")
        case .aquarium: (.activities, "aquarium")
        case .zoo: (.activities, "zoo")
        case .amusementPark: (.activities, "amusement park")
        default: nil
        }
    }

    private func categoryFromText(_ text: String) -> ExperienceCategory? {
        let words = positiveWords(text)
        if !words.isDisjoint(with: ["viewpoint", "scenic", "waterfall", "beach", "beaches", "coast", "coastal", "ocean", "bay", "lake", "river", "mountain", "mountains", "alpine", "volcano", "forest", "redwood", "garden", "park", "parks", "wildlife"]) {
            return .sceneryAndNature
        }
        if !words.isDisjoint(with: ["museum", "gallery", "theater", "architecture", "historic", "historical", "history", "heritage", "cathedral", "palace"]) {
            return .artsAndCulture
        }
        if !words.isDisjoint(with: ["restaurant", "cafe", "café", "bakery", "ramen", "matcha", "coffee", "dessert", "seafood", "oyster", "lobster", "crab", "sushi"]) {
            return .foodAndDrink
        }
        if !words.isDisjoint(with: ["hike", "hiking", "surfing", "kayaking", "skiing"]) {
            return .activities
        }
        if !words.isDisjoint(with: ["shop", "shopping", "market", "boutique"]) {
            return .shopping
        }
        return nil
    }

    private func interestTags(in text: String, category: ExperienceCategory?) -> [String] {
        let words = positiveWords(text)
        let rules: [(String, Set<String>)] = [
            ("Matcha", ["matcha"]), ("Tea", ["tea", "teahouse"]),
            ("Coffee", ["coffee", "espresso"]), ("Desserts", ["dessert", "pastry", "cake", "gelato"]),
            ("Ramen", ["ramen"]), ("Seafood", ["seafood", "oyster", "oysters", "lobster", "crab", "sushi"]),
            ("Scenic views", ["viewpoint", "scenic", "overlook", "waterfall", "panorama"]),
            ("National parks", ["nationalpark", "nationalparks"]),
            ("Mountains", ["mountain", "mountains", "alpine", "volcano", "summit"]),
            ("Coast & water", ["coast", "coastal", "ocean", "bay", "lake", "river", "water", "waterfront", "waterfall", "waterfalls"]),
            ("Forests", ["forest", "forests", "redwood", "redwoods", "woodland"]),
            ("Wildlife", ["wildlife", "whale", "whales", "bird", "birds", "aquarium", "zoo"]),
            ("Hiking", ["hike", "hiking", "trail", "trails"]), ("Beaches", ["beach", "beaches"]),
            ("Architecture", ["architecture", "architectural", "building", "cathedral", "palace", "design"]),
            ("History", ["history", "historic", "historical", "heritage", "memorial", "battlefield"]),
            ("Museums", ["museum", "museums", "gallery", "galleries"]),
            ("Gardens", ["garden", "gardens", "botanical"]), ("Shopping", ["shopping", "boutique"])
        ]
        var tags = rules.compactMap { tag, triggers in
            words.isDisjoint(with: triggers) ? nil : tag
        }
        if category == .sceneryAndNature && !tags.contains("Scenic views") {
            tags.append("Nature")
        }
        return tags
    }

    private func interestPhrase(_ interests: [String]) -> String {
        let values = interests.prefix(3).map { $0.lowercased() }
        switch values.count {
        case 0: return "this place"
        case 1: return values[0]
        case 2: return "\(values[0]) and \(values[1])"
        default: return "\(values[0]), \(values[1]), and \(values[2])"
        }
    }

    private func positiveWords(_ text: String) -> Set<String> {
        let normalized = text
            .replacingOccurrences(of: "don't", with: "dont", options: .caseInsensitive)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let tokens = normalized
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
        let negations: Set<String> = ["not", "no", "avoid", "dislike", "hate", "dont"]
        var words = Set(tokens.indices.compactMap { index in
            let preceding = tokens[max(0, index - 3)..<index]
            return preceding.contains(where: { negations.contains($0) }) ? nil : tokens[index]
        })
        let joinedPhrases = words
            .intersection(["national"])
            .isEmpty || words.intersection(["park", "parks"]).isEmpty
            ? [] : ["nationalpark", "nationalparks"]
        words.formUnion(joinedPhrases)
        return words
    }
}
