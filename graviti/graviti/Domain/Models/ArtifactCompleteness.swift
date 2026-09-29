import Foundation

struct ArtifactCompleteness: Hashable {
    enum Gap: String, Hashable, CaseIterable {
        case place, description, category, note, linkPreview

        var title: String {
            switch self {
            case .place: String(localized: "Place not identified")
            case .description: String(localized: "No description")
            case .category: String(localized: "Category uncertain")
            case .note: String(localized: "No personal note")
            case .linkPreview: String(localized: "Link preview unavailable")
            }
        }
        var symbol: String {
            switch self {
            case .place: "mappin.slash"
            case .description: "text.badge.xmark"
            case .category: "questionmark.folder"
            case .note: "note.text.badge.plus"
            case .linkPreview: "link.badge.plus"
            }
        }
    }

    let gaps: [Gap]
    var score: Int { Gap.allCases.count - gaps.count }
    var isComplete: Bool { gaps.isEmpty }

    static func evaluate(_ artifact: Artifact) -> Self {
        var gaps = [Gap]()
        if artifact.place == nil { gaps.append(.place) }
        if artifact.effectiveSummary?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false { gaps.append(.description) }
        if artifact.effectiveCategory == nil || (artifact.userDetails?.category == nil && (artifact.enrichment?.confidence ?? 0) < 0.65) {
            gaps.append(.category)
        }
        if artifact.userNote?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false { gaps.append(.note) }
        if artifact.kind == .url && artifact.linkMetadata == nil { gaps.append(.linkPreview) }
        return Self(gaps: gaps)
    }
}

extension Artifact {
    var completeness: ArtifactCompleteness { .evaluate(self) }
}
