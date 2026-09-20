import Foundation

struct InterestPattern: Identifiable {
    let name: String
    let artifacts: [Artifact]
    let placeCount: Int
    let areaNames: [String]

    var id: String { name }
    var saveCount: Int { artifacts.count }
    var areaCount: Int { areaNames.count }

    var evidenceSummary: String {
        if areaCount > 1 {
            return GravitiCopy.savesAcrossAreas(saveCount, areaCount: areaCount)
        }
        if placeCount > 1 {
            return GravitiCopy.savesAtPlaces(saveCount, placeCount: placeCount)
        }
        return GravitiCopy.savedItems(saveCount)
    }
}

struct CategoryPattern: Identifiable {
    let category: ExperienceCategory
    let saveCount: Int

    var id: ExperienceCategory { category }
}

struct InterestProfile {
    let interests: [InterestPattern]
    let categories: [CategoryPattern]

    var strongestAcrossAreas: InterestPattern? {
        interests.first(where: { $0.areaCount > 1 })
    }
}

enum InterestProfileBuilder {
    static func build(from artifacts: [Artifact]) -> InterestProfile {
        var grouped: [String: [Artifact]] = [:]
        var categoryCounts: [ExperienceCategory: Int] = [:]

        for artifact in artifacts {
            for interest in Set(artifact.effectiveInterests) {
                grouped[interest, default: []].append(artifact)
            }
            if let category = artifact.effectiveCategory, category != .other {
                categoryCounts[category, default: 0] += 1
            }
        }

        let interests = grouped.map { name, evidence in
            var seenAreas = Set<String>()
            var areas: [String] = []
            var placeIDs = Set<String>()
            for artifact in evidence {
                guard let place = artifact.place else { continue }
                placeIDs.insert(place.id)
                let locality = place.locality?.trimmingCharacters(in: .whitespacesAndNewlines)
                let country = place.country?.trimmingCharacters(in: .whitespacesAndNewlines)
                let area = [locality, country]
                    .compactMap { $0?.isEmpty == false ? $0 : nil }
                    .joined(separator: ", ")
                guard !area.isEmpty else { continue }
                if seenAreas.insert(area.folding(options: .caseInsensitive, locale: .current)).inserted {
                    areas.append(area)
                }
            }
            return InterestPattern(
                name: name,
                artifacts: evidence,
                placeCount: placeIDs.count,
                areaNames: areas
            )
        }
        .sorted {
            if $0.areaCount != $1.areaCount { return $0.areaCount > $1.areaCount }
            if $0.saveCount != $1.saveCount { return $0.saveCount > $1.saveCount }
            return $0.name < $1.name
        }

        let categories = categoryCounts.map { CategoryPattern(category: $0.key, saveCount: $0.value) }
            .sorted {
                if $0.saveCount != $1.saveCount { return $0.saveCount > $1.saveCount }
                return $0.category.displayName < $1.category.displayName
            }
        return InterestProfile(interests: interests, categories: categories)
    }
}
