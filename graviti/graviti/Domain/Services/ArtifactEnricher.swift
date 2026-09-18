import Foundation
import MapKit

@MainActor
struct ArtifactEnricher {
    func enrich(_ artifact: Artifact) async -> ArtifactEnrichment? {
        let item: MKMapItem?
        if let place = artifact.place,
           let identifier = MKMapItem.Identifier(rawValue: place.id) {
            item = try? await MKMapItemRequest(mapItemIdentifier: identifier).mapItem
        } else {
            item = nil
        }

        let classification = item?.pointOfInterestCategory.flatMap(classification(for:))
        let text = [artifact.originalText, artifact.userNote]
            .compactMap { $0 }
            .joined(separator: " ")
        let interests = interestTags(in: text, category: classification?.category)
        let textCategory = categoryFromText(text)
        let category = classification?.category ?? textCategory

        guard item != nil || category != nil || !interests.isEmpty else { return nil }

        let summary: String?
        if let place = artifact.place,
           let type = classification?.typeName {
            let location = place.locality ?? place.country
            summary = location.map { "\(place.name) is a \(type) in \($0)." }
                ?? "\(place.name) is a \(type)."
        } else {
            summary = nil
        }

        let source: ArtifactEnrichment.Source
        if item != nil {
            source = text.isEmpty ? .mapKit : .mapKitAndSavedText
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
        if !words.isDisjoint(with: ["viewpoint", "scenic", "waterfall", "beach", "beaches", "mountain", "garden", "park", "parks"]) {
            return .sceneryAndNature
        }
        if !words.isDisjoint(with: ["museum", "gallery", "theater", "architecture"]) {
            return .artsAndCulture
        }
        if !words.isDisjoint(with: ["restaurant", "cafe", "café", "bakery", "ramen", "matcha", "coffee", "dessert"]) {
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
            ("Ramen", ["ramen"]), ("Scenic views", ["viewpoint", "scenic", "overlook", "waterfall"]),
            ("Hiking", ["hike", "hiking", "trail"]), ("Beaches", ["beach", "beaches"]),
            ("Architecture", ["architecture", "building"]), ("Museums", ["museum", "gallery"]),
            ("Gardens", ["garden", "botanical"]), ("Shopping", ["shopping", "boutique"])
        ]
        var tags = rules.compactMap { tag, triggers in
            words.isDisjoint(with: triggers) ? nil : tag
        }
        if category == .sceneryAndNature && !tags.contains("Scenic views") {
            tags.append("Nature")
        }
        return tags
    }

    private func positiveWords(_ text: String) -> Set<String> {
        let normalized = text
            .replacingOccurrences(of: "don't", with: "dont", options: .caseInsensitive)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let tokens = normalized
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
        let negations: Set<String> = ["not", "no", "avoid", "dislike", "hate", "dont"]
        return Set(tokens.indices.compactMap { index in
            let preceding = tokens[max(0, index - 3)..<index]
            return preceding.contains(where: { negations.contains($0) }) ? nil : tokens[index]
        })
    }
}
