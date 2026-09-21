import Foundation

struct DestinationReadiness: Equatable {
    enum Band: String {
        case takingShape
        case strongWeekend
        case readyForSeveralDays

        var title: String {
            switch self {
            case .takingShape:
                String(localized: "Still taking shape")
            case .strongWeekend:
                String(localized: "Strong weekend")
            case .readyForSeveralDays:
                String(localized: "Ready for 4–5 days")
            }
        }
    }

    let band: Band
    let placeCount: Int
    let categoryCount: Int
    let interestCount: Int
    let areaCount: Int
    let guidance: String

    var evidenceSummary: String {
        [
            GravitiCopy.distinctPlaces(placeCount),
            GravitiCopy.experienceTypes(categoryCount),
            GravitiCopy.interests(interestCount)
        ].joined(separator: " · ")
    }
}

enum DestinationReadinessBuilder {
    static func build(
        for node: OrbitNode,
        artifacts: [Artifact],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> DestinationReadiness {
        let evidence = DestinationOrbitBuilder.artifacts(for: node, from: artifacts)
        let placeCount = Set(evidence.compactMap(\.place?.id)).count
        let categories = Set(evidence.compactMap(\.effectiveCategory).filter { $0 != .other })
        let interests = Set(evidence.flatMap(\.effectiveInterests).map(normalized).filter { !$0.isEmpty })
        let areas = Set(evidence.compactMap { subarea(for: node, artifact: $0) })
        let recentPlaceCount = recentPlaces(in: evidence, now: now, calendar: calendar)

        let score = min(48, placeCount * 6)
            + min(24, categories.count * 6)
            + min(16, interests.count * 2)
            + min(8, max(0, areas.count - 1) * 3)
            + min(4, recentPlaceCount)

        let band: DestinationReadiness.Band
        if placeCount >= 8, categories.count >= 4, score >= 75 {
            band = .readyForSeveralDays
        } else if placeCount >= 4, categories.count >= 3, score >= 50 {
            band = .strongWeekend
        } else {
            band = .takingShape
        }

        return DestinationReadiness(
            band: band,
            placeCount: placeCount,
            categoryCount: categories.count,
            interestCount: interests.count,
            areaCount: areas.count,
            guidance: guidance(
                for: band,
                placeCount: placeCount,
                categoryCount: categories.count,
                areaCount: areas.count
            )
        )
    }

    private static func recentPlaces(
        in artifacts: [Artifact],
        now: Date,
        calendar: Calendar
    ) -> Int {
        guard let cutoff = calendar.date(byAdding: .day, value: -120, to: now) else { return 0 }
        return Set(artifacts.filter {
            $0.capturedAt >= cutoff && $0.capturedAt <= now
        }.compactMap(\.place?.id)).count
    }

    private static func subarea(for node: OrbitNode, artifact: Artifact) -> String? {
        guard let place = artifact.place else { return nil }
        let value: String?
        switch node.level {
        case .country:
            value = cleaned(place.region) ?? cleaned(place.locality)
        case .stateProvince:
            value = cleaned(place.locality)
        case .city, .district, .neighborhood:
            value = nil
        }
        return value.map(normalized)
    }

    private static func guidance(
        for band: DestinationReadiness.Band,
        placeCount: Int,
        categoryCount: Int,
        areaCount: Int
    ) -> String {
        switch band {
        case .readyForSeveralDays:
            if areaCount > 1 {
                return String(localized: "You have varied reasons to spend several days here, spread across different areas.")
            }
            return String(localized: "You have varied reasons to spend several days here.")
        case .strongWeekend:
            let placesNeeded = max(0, 8 - placeCount)
            if categoryCount < 4, placesNeeded > 0 {
                return String(localized: "Add another kind of experience and \(placesNeeded) more distinct places to support a longer trip.")
            }
            if categoryCount < 4 {
                return String(localized: "Add another kind of experience to support a longer trip.")
            }
            return String(localized: "Add \(placesNeeded) more distinct places to support a longer trip.")
        case .takingShape:
            let placesNeeded = max(0, 4 - placeCount)
            if categoryCount < 3, placesNeeded > 0 {
                return String(localized: "Add \(placesNeeded) more distinct places and broaden the mix of experiences to support a weekend.")
            }
            if categoryCount < 3 {
                return String(localized: "Broaden the mix of experiences to support a weekend.")
            }
            return String(localized: "Add \(placesNeeded) more distinct places to support a weekend.")
        }
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func cleaned(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}
