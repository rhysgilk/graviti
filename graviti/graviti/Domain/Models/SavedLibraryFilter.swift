import Foundation

enum SavedLibraryNoteRule: String, Codable, CaseIterable, Identifiable {
    case any, withNote, withoutNote
    var id: Self { self }
    var title: String {
        switch self {
        case .any: String(localized: "Any note state")
        case .withNote: String(localized: "Has a personal note")
        case .withoutNote: String(localized: "Missing a personal note")
        }
    }
}

enum SavedLibrarySourceRule: String, Codable, CaseIterable, Identifiable {
    case any, instagram, maps, photo
    var id: Self { self }
    var title: String {
        switch self {
        case .any: String(localized: "Any source")
        case .instagram: String(localized: "Instagram")
        case .maps: String(localized: "Maps link")
        case .photo: String(localized: "Photo")
        }
    }
}

struct SavedLibraryFilter: Codable, Hashable, Identifiable {
    let id: UUID
    var name: String
    var category: ExperienceCategory?
    var placeQuery: String
    var interestQuery: String
    var noteRule: SavedLibraryNoteRule
    var sourceRule: SavedLibrarySourceRule
    var lifecycle: PlaceLifecycleStatus?
    var recentlyAdded: Bool
    var needsDescription: Bool
    var highPriorityOnly: Bool

    func matches(_ artifact: Artifact, now: Date = .now) -> Bool {
        if let category, artifact.effectiveCategory != category { return false }
        if !placeQuery.isEmpty {
            let placeText = [artifact.place?.name, artifact.place?.locality, artifact.place?.region, artifact.place?.country]
                .compactMap { $0 }.joined(separator: " ")
            if !placeText.localizedCaseInsensitiveContains(placeQuery) { return false }
        }
        if !interestQuery.isEmpty,
           !artifact.effectiveInterests.contains(where: { $0.localizedCaseInsensitiveContains(interestQuery) }) {
            return false
        }
        switch noteRule {
        case .any: break
        case .withNote: if artifact.userNote?.trimmedNil == nil { return false }
        case .withoutNote: if artifact.userNote?.trimmedNil != nil { return false }
        }
        switch sourceRule {
        case .any: break
        case .instagram:
            guard let host = artifact.sourceURL.flatMap({ URLComponents(string: $0)?.host?.lowercased() }),
                  host == "instagram.com" || host.hasSuffix(".instagram.com") else { return false }
        case .maps:
            guard artifact.sourceURL.flatMap(MapLinkMetadata.provider) != nil else { return false }
        case .photo:
            guard artifact.kind == .photo else { return false }
        }
        if let lifecycle, artifact.userDetails?.placeStatus != lifecycle { return false }
        if recentlyAdded,
           artifact.capturedAt < (Calendar.current.date(byAdding: .day, value: -30, to: now) ?? .distantPast) { return false }
        if needsDescription, artifact.effectiveSummary?.trimmedNil != nil { return false }
        if highPriorityOnly, artifact.userDetails?.isHighPriority != true { return false }
        return true
    }
}

enum SavedLibraryFilterStore {
    static func decode(_ raw: String) -> [SavedLibraryFilter] {
        guard let data = raw.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([SavedLibraryFilter].self, from: data)) ?? []
    }

    static func encode(_ filters: [SavedLibraryFilter], fallback: String = "") -> String {
        guard let data = try? JSONEncoder().encode(filters) else { return fallback }
        return String(decoding: data, as: UTF8.self)
    }
}
