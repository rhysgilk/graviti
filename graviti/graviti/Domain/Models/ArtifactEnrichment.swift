import Foundation

enum ExperienceCategory: String, Codable, CaseIterable {
    case foodAndDrink
    case sceneryAndNature
    case artsAndCulture
    case activities
    case shopping
    case landmarks
    case stay
    case other

    var displayName: String {
        switch self {
        case .foodAndDrink: "Food & drink"
        case .sceneryAndNature: "Scenery & nature"
        case .artsAndCulture: "Arts & culture"
        case .activities: "Activities"
        case .shopping: "Shopping"
        case .landmarks: "Landmarks"
        case .stay: "Stay"
        case .other: "Place"
        }
    }
}

struct ArtifactEnrichment: Codable, Hashable {
    enum Source: String, Codable {
        case mapKit
        case savedText
        case mapKitAndSavedText

        var displayName: String {
            switch self {
            case .mapKit: "Apple Maps place details"
            case .savedText: "Saved text"
            case .mapKitAndSavedText: "Apple Maps place details and saved text"
            }
        }
    }

    let summary: String?
    let category: ExperienceCategory?
    let interests: [String]
    let source: Source
    let confidence: Double
    let generatedAt: Date
}
