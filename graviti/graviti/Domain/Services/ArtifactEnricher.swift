import Foundation
import MapKit

@MainActor
struct ArtifactEnricher {
    private struct SemanticInput {
        let text: String
        let source: ArtifactEvidenceSource
        let confidence: Double
    }

    func enrich(_ artifact: Artifact) async throws -> ArtifactEnrichment? {
        let inputs = semanticInputs(for: artifact)
        let text = inputs.map(\.text).joined(separator: " ")
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
        var interestEvidence = inputs.flatMap { input in
            interestTags(in: input.text).map {
                ArtifactInterestEvidence(
                    interest: $0,
                    source: input.source,
                    confidence: input.confidence
                )
            }
        }
        if classification?.category == .sceneryAndNature,
           !interestEvidence.contains(where: { $0.interest == "Nature" }) {
            interestEvidence.append(ArtifactInterestEvidence(
                interest: "Nature",
                source: .mapPlace,
                confidence: 0.9
            ))
        }
        interestEvidence = deduplicated(interestEvidence)
        let interests = orderedInterests(from: interestEvidence)

        var categoryCandidates = inputs.compactMap { input -> (ExperienceCategory, Double)? in
            categoryFromText(input.text).map { ($0, input.confidence) }
        }
        if let classification {
            categoryCandidates.append((classification.category, 0.9))
        }
        let category = categoryCandidates.max(by: { $0.1 < $1.1 })?.0

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
            source = inputs.isEmpty ? .mapKit : .mapKitAndSavedText
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
            confidence: max(
                classification == nil ? 0 : 0.9,
                interestEvidence.map(\.confidence).max() ?? categoryCandidates.map(\.1).max() ?? 0.55
            ),
            generatedAt: .now,
            interestEvidence: interestEvidence
        )
    }

    private func semanticInputs(for artifact: Artifact) -> [SemanticInput] {
        var inputs: [SemanticInput] = []
        append(artifact.userNote, source: .userNote, confidence: 0.95, to: &inputs)
        append(artifact.originalText, source: .originalText, confidence: 0.88, to: &inputs)
        append(artifact.extractedText, source: .detectedText, confidence: 0.82, to: &inputs)
        for title in artifact.sourceCollectionTitles {
            append(title, source: .collectionTitle, confidence: 0.76, to: &inputs)
        }
        append(artifact.linkMetadata?.title, source: .linkMetadata, confidence: 0.68, to: &inputs)
        append(artifact.linkMetadata?.summary, source: .linkMetadata, confidence: 0.64, to: &inputs)
        return inputs
    }

    private func append(
        _ value: String?,
        source: ArtifactEvidenceSource,
        confidence: Double,
        to inputs: inout [SemanticInput]
    ) {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return
        }
        inputs.append(SemanticInput(text: value, source: source, confidence: confidence))
    }

    private func deduplicated(_ evidence: [ArtifactInterestEvidence]) -> [ArtifactInterestEvidence] {
        var values: [String: ArtifactInterestEvidence] = [:]
        for item in evidence {
            let key = item.id
            if item.confidence > (values[key]?.confidence ?? -1) {
                values[key] = item
            }
        }
        return values.values.sorted {
            if $0.confidence != $1.confidence { return $0.confidence > $1.confidence }
            if $0.interest != $1.interest { return $0.interest.localizedStandardCompare($1.interest) == .orderedAscending }
            return $0.source.rawValue < $1.source.rawValue
        }
    }

    private func orderedInterests(from evidence: [ArtifactInterestEvidence]) -> [String] {
        var seen = Set<String>()
        return evidence.compactMap { item in
            seen.insert(item.interest).inserted ? item.interest : nil
        }
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
        if !words.isDisjoint(with: ["viewpoint", "scenic", "waterfall", "beach", "beaches", "coast", "coastal", "ocean", "bay", "lake", "river", "mountain", "mountains", "alpine", "volcano", "forest", "redwood", "garden", "park", "parks", "wildlife", "desert", "canyon", "cliff", "cliffs"]) {
            return .sceneryAndNature
        }
        if !words.isDisjoint(with: ["museum", "gallery", "theater", "architecture", "historic", "historical", "history", "heritage", "cathedral", "palace", "modernist", "brutalist", "contemporary"]) {
            return .artsAndCulture
        }
        if !words.isDisjoint(with: ["restaurant", "cafe", "café", "bakery", "ramen", "matcha", "coffee", "dessert", "seafood", "oyster", "lobster", "crab", "sushi", "taco", "tacos", "pizza", "pasta", "pho", "dimsum", "barbecue", "bbq"]) {
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

    private func interestTags(in text: String) -> [String] {
        let words = positiveWords(text)
        var tags: [String] = []
        let hikingWords: Set<String> = ["hike", "hiking", "trail", "trails"]
        let forestWords: Set<String> = ["forest", "forests", "redwood", "redwoods", "woodland", "woods"]
        let desertWords: Set<String> = ["desert", "deserts", "canyon", "canyons", "mesa", "mesas"]
        let coastWords: Set<String> = ["coast", "coastal", "ocean", "shore", "shoreline"]
        let rockyWords: Set<String> = ["rocky", "rugged", "cliff", "cliffs", "clifftop"]
        let architectureWords: Set<String> = ["architecture", "architectural", "building", "cathedral", "palace", "design"]
        let historicWords: Set<String> = ["historic", "historical", "heritage", "ancient", "medieval"]
        let modernWords: Set<String> = ["modern", "modernist", "brutalist", "contemporary"]

        if !words.isDisjoint(with: hikingWords), !words.isDisjoint(with: forestWords) { tags.append("Forest hiking") }
        if !words.isDisjoint(with: hikingWords), !words.isDisjoint(with: desertWords) { tags.append("Desert hiking") }
        if !words.isDisjoint(with: coastWords), !words.isDisjoint(with: rockyWords) { tags.append("Rocky coast") }
        if !words.isDisjoint(with: architectureWords), !words.isDisjoint(with: historicWords) { tags.append("Historic architecture") }
        if !words.isDisjoint(with: architectureWords), !words.isDisjoint(with: modernWords) { tags.append("Modern architecture") }

        let rules: [(String, Set<String>)] = [
            ("Matcha", ["matcha"]), ("Tea", ["tea", "teahouse"]),
            ("Coffee", ["coffee", "espresso"]), ("Desserts", ["dessert", "pastry", "cake", "gelato"]),
            ("Ramen", ["ramen"]), ("Sushi", ["sushi"]), ("Tacos", ["taco", "tacos"]),
            ("Pizza", ["pizza"]), ("Pasta", ["pasta"]), ("Pho", ["pho"]),
            ("Dim sum", ["dimsum"]), ("Barbecue", ["barbecue", "bbq"]),
            ("Seafood", ["seafood", "oyster", "oysters", "lobster", "crab"]),
            ("Scenic views", ["viewpoint", "scenic", "overlook", "waterfall", "panorama"]),
            ("National parks", ["nationalpark", "nationalparks"]),
            ("Mountains", ["mountain", "mountains", "alpine", "volcano", "summit"]),
            ("Coast & water", ["coast", "coastal", "ocean", "bay", "lake", "river", "water", "waterfront", "waterfall", "waterfalls"]),
            ("Forests", forestWords),
            ("Wildlife", ["wildlife", "whale", "whales", "bird", "birds", "aquarium", "zoo"]),
            ("Hiking", ["hike", "hiking", "trail", "trails"]), ("Beaches", ["beach", "beaches"]),
            ("Architecture", ["architecture", "architectural", "building", "cathedral", "palace", "design"]),
            ("History", ["history", "historic", "historical", "heritage", "memorial", "battlefield"]),
            ("Museums", ["museum", "museums", "gallery", "galleries"]),
            ("Gardens", ["garden", "gardens", "botanical"]), ("Shopping", ["shopping", "boutique"])
        ]
        tags.append(contentsOf: rules.compactMap { tag, triggers in
            words.isDisjoint(with: triggers) ? nil : tag
        })
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
        if words.contains("dim"), words.contains("sum") {
            words.insert("dimsum")
        }
        return words
    }
}
