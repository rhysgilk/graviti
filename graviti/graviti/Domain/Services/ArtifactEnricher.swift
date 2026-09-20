import Foundation
import MapKit

@MainActor
struct ArtifactEnricher {
    func enrich(_ artifact: Artifact) async throws -> ArtifactEnrichment? {
        let savedText = [artifact.originalText, artifact.userNote, artifact.sourceCollectionTitle, artifact.linkMetadata?.title, artifact.linkMetadata?.summary]
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
            let interestText = interestPhrase(interests)
            if let location {
                summary = interests.isEmpty
                    ? String(localized: "\(place.name) is a \(type) in \(location).")
                    : String(localized: "\(place.name) is a \(type) in \(location), saved for \(interestText).")
            } else {
                summary = interests.isEmpty
                    ? String(localized: "\(place.name) is a \(type).")
                    : String(localized: "\(place.name) is a \(type), saved for \(interestText).")
            }
        } else if let place = artifact.place, !interests.isEmpty {
            summary = String(localized: "\(place.name) is saved for \(interestPhrase(interests)).")
        } else if !interests.isEmpty {
            summary = artifact.kind == .photo
                ? String(localized: "A saved photo about \(interestPhrase(interests)).")
                : String(localized: "A saved idea about \(interestPhrase(interests)).")
        } else if let category {
            summary = artifact.kind == .photo
                ? String(localized: "A saved photo about \(category.displayName.lowercased()).")
                : String(localized: "A saved idea about \(category.displayName.lowercased()).")
        } else {
            summary = nil
        }

        let source: ArtifactEnrichment.Source
        if item != nil, artifact.extractedText != nil {
            source = .mapKitAndDetectedText
        } else if item != nil, artifact.linkMetadata != nil {
            source = .mapKitAndLinkMetadata
        } else if item != nil {
            source = savedText.isEmpty ? .mapKit : .mapKitAndSavedText
        } else if artifact.extractedText != nil {
            source = .detectedText
        } else if artifact.linkMetadata != nil {
            source = .linkMetadata
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
        case .restaurant: (.foodAndDrink, String(localized: "restaurant"))
        case .cafe: (.foodAndDrink, String(localized: "café"))
        case .bakery: (.foodAndDrink, String(localized: "bakery"))
        case .foodMarket: (.foodAndDrink, String(localized: "food market"))
        case .brewery: (.foodAndDrink, String(localized: "brewery"))
        case .winery: (.foodAndDrink, String(localized: "winery"))
        case .museum: (.artsAndCulture, String(localized: "museum"))
        case .theater: (.artsAndCulture, String(localized: "theater"))
        case .musicVenue: (.artsAndCulture, String(localized: "music venue"))
        case .park: (.sceneryAndNature, String(localized: "park"))
        case .nationalPark: (.sceneryAndNature, String(localized: "national park"))
        case .beach: (.sceneryAndNature, String(localized: "beach"))
        case .hiking: (.sceneryAndNature, String(localized: "hiking area"))
        case .campground: (.sceneryAndNature, String(localized: "campground"))
        case .landmark: (.landmarks, String(localized: "landmark"))
        case .nationalMonument: (.landmarks, String(localized: "monument"))
        case .castle: (.landmarks, String(localized: "castle"))
        case .store: (.shopping, String(localized: "shop"))
        case .hotel: (.stay, String(localized: "hotel"))
        case .aquarium: (.activities, String(localized: "aquarium"))
        case .zoo: (.activities, String(localized: "zoo"))
        case .amusementPark: (.activities, String(localized: "amusement park"))
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
        var values: [String] = []
        for interest in interests.prefix(3) {
            values.append(InterestDisplayName.localized(interest).lowercased())
        }
        guard !values.isEmpty else { return String(localized: "this place") }
        return ListFormatter.localizedString(byJoining: values)
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
