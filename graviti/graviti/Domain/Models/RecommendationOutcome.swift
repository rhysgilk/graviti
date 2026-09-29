import Foundation

enum RecommendationOutcomeKind: String, Codable, CaseIterable {
    case shown
    case opened
    case saved
    case suggestedPlaceSaved
    case dismissed
    case visitedLoved
    case visitedDidNotFit

    var displayName: String {
        switch self {
        case .shown: String(localized: "Shown")
        case .opened: String(localized: "Opened")
        case .saved: String(localized: "Saved")
        case .suggestedPlaceSaved: String(localized: "Suggested place saved")
        case .dismissed: String(localized: "Not for me")
        case .visitedLoved: String(localized: "Visited and loved")
        case .visitedDidNotFit: String(localized: "Visited and didn’t fit")
        }
    }

    var symbol: String {
        switch self {
        case .shown: "eye.fill"
        case .opened: "arrow.up.right.square.fill"
        case .saved: "bookmark.fill"
        case .suggestedPlaceSaved: "mappin.and.ellipse"
        case .dismissed: "hand.thumbsdown.fill"
        case .visitedLoved: "heart.fill"
        case .visitedDidNotFit: "arrow.uturn.backward.circle.fill"
        }
    }
}

struct RecommendationOutcomeEvent: Codable, Hashable, Identifiable {
    let id: UUID
    let recommendationID: String
    let destinationName: String
    let kind: RecommendationOutcomeKind
    let score: Int
    let confidencePercent: Int
    let matchedInterests: [String]
    let createdAt: Date
    let fitEvidenceProvenance: GeneratedDataProvenance?

    init(
        id: UUID,
        recommendationID: String,
        destinationName: String,
        kind: RecommendationOutcomeKind,
        score: Int,
        confidencePercent: Int,
        matchedInterests: [String],
        createdAt: Date,
        fitEvidenceProvenance: GeneratedDataProvenance? = nil
    ) {
        self.id = id
        self.recommendationID = recommendationID
        self.destinationName = destinationName
        self.kind = kind
        self.score = score
        self.confidencePercent = confidencePercent
        self.matchedInterests = matchedInterests
        self.createdAt = createdAt
        self.fitEvidenceProvenance = fitEvidenceProvenance
    }
}

enum RecommendationOutcomeStore {
    static func decode(_ raw: String) -> [RecommendationOutcomeEvent] {
        guard let data = raw.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([RecommendationOutcomeEvent].self, from: data)) ?? []
    }

    static func recording(
        _ kind: RecommendationOutcomeKind,
        recommendation: DestinationRecommendation,
        in raw: String,
        now: Date = .now
    ) -> String {
        var events = decode(raw)
        if let latest = events.last(where: {
            $0.recommendationID == recommendation.id && $0.kind == kind
        }), kind == .shown, now.timeIntervalSince(latest.createdAt) < 86_400 {
            return raw
        }
        events.append(RecommendationOutcomeEvent(
            id: UUID(),
            recommendationID: recommendation.id,
            destinationName: recommendation.name,
            kind: kind,
            score: recommendation.fitPercent,
            confidencePercent: recommendation.confidencePercent,
            matchedInterests: recommendation.matchedInterests,
            createdAt: now,
            fitEvidenceProvenance: GeneratedDataProvenance(
                producer: "DestinationFitEngine",
                version: 2,
                generatedAt: now
            )
        ))
        if events.count > 2_000 { events.removeFirst(events.count - 2_000) }
        return encode(events, fallback: raw)
    }

    static func removing(_ id: UUID, from raw: String) -> String {
        encode(decode(raw).filter { $0.id != id }, fallback: raw)
    }

    static func recordingSuggestedPlace(
        guide: FitGuide,
        placeName: String,
        in raw: String,
        now: Date = .now
    ) -> String {
        var events = decode(raw)
        events.append(RecommendationOutcomeEvent(
            id: UUID(),
            recommendationID: guide.id,
            destinationName: "\(guide.destination.name): \(placeName)",
            kind: .suggestedPlaceSaved,
            score: 0,
            confidencePercent: 0,
            matchedInterests: guide.interests,
            createdAt: now,
            fitEvidenceProvenance: GeneratedDataProvenance(
                producer: "FitGuideSearchEngine",
                version: 1,
                generatedAt: now
            )
        ))
        if events.count > 2_000 { events.removeFirst(events.count - 2_000) }
        return encode(events, fallback: raw)
    }

    static func removingAll() -> String { "[]" }

    private static func encode(_ events: [RecommendationOutcomeEvent], fallback: String) -> String {
        guard let data = try? JSONEncoder().encode(events) else { return fallback }
        return String(decoding: data, as: UTF8.self)
    }
}

struct RecommendationPromptRecord: Codable, Hashable, Identifiable {
    let recommendationID: String
    let prompt: String
    var lastShownAt: Date
    var dismissedAt: Date?

    var id: String { "\(recommendationID)|\(prompt)" }
}

enum RecommendationPromptStore {
    static func decode(_ raw: String) -> [RecommendationPromptRecord] {
        guard let data = raw.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([RecommendationPromptRecord].self, from: data)) ?? []
    }

    static func shouldShow(recommendationID: String, prompt: String, in raw: String, now: Date = .now) -> Bool {
        guard let record = decode(raw).first(where: { $0.recommendationID == recommendationID && $0.prompt == prompt }) else {
            return true
        }
        if record.dismissedAt != nil { return false }
        return now.timeIntervalSince(record.lastShownAt) >= 7 * 86_400
    }

    static func markingShown(recommendationID: String, prompt: String, in raw: String, now: Date = .now) -> String {
        update(recommendationID: recommendationID, prompt: prompt, in: raw) {
            $0.lastShownAt = now
        } create: {
            RecommendationPromptRecord(recommendationID: recommendationID, prompt: prompt, lastShownAt: now, dismissedAt: nil)
        }
    }

    static func dismissing(recommendationID: String, prompt: String, in raw: String, now: Date = .now) -> String {
        update(recommendationID: recommendationID, prompt: prompt, in: raw) {
            $0.dismissedAt = now
        } create: {
            RecommendationPromptRecord(recommendationID: recommendationID, prompt: prompt, lastShownAt: now, dismissedAt: now)
        }
    }

    private static func update(
        recommendationID: String,
        prompt: String,
        in raw: String,
        mutation: (inout RecommendationPromptRecord) -> Void,
        create: () -> RecommendationPromptRecord
    ) -> String {
        var records = decode(raw)
        if let index = records.firstIndex(where: { $0.recommendationID == recommendationID && $0.prompt == prompt }) {
            mutation(&records[index])
        } else {
            records.append(create())
        }
        guard let data = try? JSONEncoder().encode(Array(records.suffix(500))) else { return raw }
        return String(decoding: data, as: UTF8.self)
    }
}
