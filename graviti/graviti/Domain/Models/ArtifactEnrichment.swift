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
        case .foodAndDrink: String(localized: "Food & drink")
        case .sceneryAndNature: String(localized: "Scenery & nature")
        case .artsAndCulture: String(localized: "Arts & culture")
        case .activities: String(localized: "Activities")
        case .shopping: String(localized: "Shopping")
        case .landmarks: String(localized: "Landmarks")
        case .stay: String(localized: "Stay")
        case .other: String(localized: "Place")
        }
    }
}

struct ArtifactEnrichment: Codable, Hashable {
    enum Source: String, Codable {
        case mapKit
        case savedText
        case mapKitAndSavedText
        case detectedText
        case mapKitAndDetectedText

        var displayName: String {
            switch self {
            case .mapKit: String(localized: "Apple Maps place details")
            case .savedText: String(localized: "Saved text")
            case .mapKitAndSavedText: String(localized: "Apple Maps place details and saved text")
            case .detectedText: String(localized: "Detected image text")
            case .mapKitAndDetectedText: String(localized: "Apple Maps place details and detected image text")
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
