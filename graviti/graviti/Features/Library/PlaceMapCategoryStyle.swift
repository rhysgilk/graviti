import SwiftUI

enum PlaceMapCategoryStyle {
    static func category(for placeID: String, in artifacts: [Artifact]) -> ExperienceCategory {
        let categories = artifacts.compactMap { artifact -> ExperienceCategory? in
            guard artifact.place?.id == placeID else { return nil }
            return artifact.effectiveCategory ?? .other
        }
        guard !categories.isEmpty else { return .other }
        let counts = Dictionary(grouping: categories, by: { $0 }).mapValues(\.count)
        return ExperienceCategory.allCases.max { lhs, rhs in
            let lhsCount = counts[lhs, default: 0]
            let rhsCount = counts[rhs, default: 0]
            if lhsCount != rhsCount { return lhsCount < rhsCount }
            return categoryOrder(lhs) > categoryOrder(rhs)
        } ?? .other
    }

    private static func categoryOrder(_ category: ExperienceCategory) -> Int {
        ExperienceCategory.allCases.firstIndex(of: category) ?? .max
    }
}

extension ExperienceCategory {
    var mapSymbolName: String {
        switch self {
        case .foodAndDrink: "fork.knife"
        case .sceneryAndNature: "leaf.fill"
        case .artsAndCulture: "theatermasks.fill"
        case .activities: "figure.hiking"
        case .shopping: "bag.fill"
        case .landmarks: "building.columns.fill"
        case .stay: "bed.double.fill"
        case .other: "mappin"
        }
    }

    var mapTint: Color {
        switch self {
        case .foodAndDrink: GravitiColors.opportunityCoral
        case .sceneryAndNature: GravitiColors.signalMint
        case .artsAndCulture: GravitiColors.iris
        case .activities: Color(red: 0.22, green: 0.72, blue: 0.96)
        case .shopping: Color(red: 0.96, green: 0.42, blue: 0.73)
        case .landmarks: Color(red: 0.96, green: 0.72, blue: 0.22)
        case .stay: Color(red: 0.40, green: 0.48, blue: 0.94)
        case .other: Color.gray
        }
    }
}
