import Foundation

struct ArtifactUserDetails: Codable, Hashable {
    let summary: String?
    let category: ExperienceCategory?
    let interests: [String]
}
