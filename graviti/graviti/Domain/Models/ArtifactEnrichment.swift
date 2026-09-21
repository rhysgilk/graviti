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

enum ArtifactEvidenceSource: String, Codable, Hashable {
    case userNote
    case originalText
    case detectedText
    case collectionTitle
    case linkMetadata
    case mapPlace

    var displayName: String {
        switch self {
        case .userNote: String(localized: "Your note or photo description")
        case .originalText: String(localized: "Original saved text")
        case .detectedText: String(localized: "Detected image text")
        case .collectionTitle: String(localized: "Source collection name")
        case .linkMetadata: String(localized: "Saved link details")
        case .mapPlace: String(localized: "Apple Maps place category")
        }
    }
}

struct ArtifactInterestEvidence: Codable, Hashable, Identifiable {
    let interest: String
    let source: ArtifactEvidenceSource
    let confidence: Double

    var id: String { "\(interest)|\(source.rawValue)" }
}

struct ArtifactEnrichment: Codable, Hashable {
    enum Source: String, Codable {
        case mapKit
        case savedText
        case mapKitAndSavedText
        case detectedText
        case mapKitAndDetectedText
        case linkMetadata
        case mapKitAndLinkMetadata

        var displayName: String {
            switch self {
            case .mapKit: String(localized: "Apple Maps place details")
            case .savedText: String(localized: "Saved text")
            case .mapKitAndSavedText: String(localized: "Apple Maps place details and saved text")
            case .detectedText: String(localized: "Detected image text")
            case .mapKitAndDetectedText: String(localized: "Apple Maps place details and detected image text")
            case .linkMetadata: String(localized: "Saved link details")
            case .mapKitAndLinkMetadata: String(localized: "Apple Maps place details and saved link details")
            }
        }
    }

    let summary: String?
    let category: ExperienceCategory?
    let interests: [String]
    let source: Source
    let confidence: Double
    let generatedAt: Date
    let interestEvidence: [ArtifactInterestEvidence]?

    init(
        summary: String?,
        category: ExperienceCategory?,
        interests: [String],
        source: Source,
        confidence: Double,
        generatedAt: Date,
        interestEvidence: [ArtifactInterestEvidence]? = nil
    ) {
        self.summary = summary
        self.category = category
        self.interests = interests
        self.source = source
        self.confidence = confidence
        self.generatedAt = generatedAt
        self.interestEvidence = interestEvidence
    }
}
