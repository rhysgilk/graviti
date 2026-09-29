import Foundation

enum PlaceLifecycleStatus: String, Codable, CaseIterable, Identifiable {
    case saved
    case curious
    case shortlisted
    case visited
    case loved
    case didNotFit

    var id: Self { self }

    var title: String {
        switch self {
        case .saved: String(localized: "Saved")
        case .curious: String(localized: "Curious")
        case .shortlisted: String(localized: "Shortlist")
        case .visited: String(localized: "Visited")
        case .loved: String(localized: "Loved")
        case .didNotFit: String(localized: "Didn't fit")
        }
    }

    var symbol: String {
        switch self {
        case .saved: "bookmark.fill"
        case .curious: "sparkle.magnifyingglass"
        case .shortlisted: "star.fill"
        case .visited: "figure.walk"
        case .loved: "heart.fill"
        case .didNotFit: "arrow.uturn.backward.circle.fill"
        }
    }
}

struct ArtifactUserDetails: Codable, Hashable {
    let summary: String?
    let category: ExperienceCategory?
    let interests: [String]
    let placeStatus: PlaceLifecycleStatus?
    let isHighPriority: Bool
    let tags: [String]

    init(
        summary: String?,
        category: ExperienceCategory?,
        interests: [String],
        placeStatus: PlaceLifecycleStatus? = nil,
        isHighPriority: Bool = false,
        tags: [String] = []
    ) {
        self.summary = summary
        self.category = category
        self.interests = interests
        self.placeStatus = placeStatus
        self.isHighPriority = isHighPriority
        self.tags = tags
    }

    private enum CodingKeys: String, CodingKey {
        case summary, category, interests, placeStatus, isHighPriority, tags
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            summary: try values.decodeIfPresent(String.self, forKey: .summary),
            category: try values.decodeIfPresent(ExperienceCategory.self, forKey: .category),
            interests: try values.decodeIfPresent([String].self, forKey: .interests) ?? [],
            placeStatus: try values.decodeIfPresent(PlaceLifecycleStatus.self, forKey: .placeStatus),
            isHighPriority: try values.decodeIfPresent(Bool.self, forKey: .isHighPriority) ?? false,
            tags: try values.decodeIfPresent([String].self, forKey: .tags) ?? []
        )
    }
}
