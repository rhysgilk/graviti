import Foundation

enum RecommendationFeedbackResponse: String, Codable, CaseIterable {
    case yes, no, notSure

    var displayName: String {
        switch self {
        case .yes: String(localized: "Yes")
        case .no: String(localized: "No")
        case .notSure: String(localized: "Not sure")
        }
    }

    var symbol: String {
        switch self {
        case .yes: "hand.thumbsup.fill"
        case .no: "hand.thumbsdown.fill"
        case .notSure: "questionmark.circle.fill"
        }
    }
}

struct RecommendationFeedbackEvent: Codable, Hashable, Identifiable {
    let id: UUID
    let recommendationID: String
    let prompt: String
    let response: RecommendationFeedbackResponse
    let createdAt: Date
}

enum RecommendationFeedbackStore {
    static func decode(_ raw: String) -> [RecommendationFeedbackEvent] {
        guard let data = raw.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([RecommendationFeedbackEvent].self, from: data)) ?? []
    }

    static func appending(_ event: RecommendationFeedbackEvent, to raw: String) -> String {
        var events = decode(raw)
        events.append(event)
        if events.count > 500 { events.removeFirst(events.count - 500) }
        return encode(events, fallback: raw)
    }

    static func replacingResponse(
        for eventID: UUID,
        with response: RecommendationFeedbackResponse,
        in raw: String
    ) -> String {
        let events = decode(raw).map { event in
            guard event.id == eventID else { return event }
            return RecommendationFeedbackEvent(
                id: event.id,
                recommendationID: event.recommendationID,
                prompt: event.prompt,
                response: response,
                createdAt: event.createdAt
            )
        }
        return encode(events, fallback: raw)
    }

    static func removing(_ eventID: UUID, from raw: String) -> String {
        encode(decode(raw).filter { $0.id != eventID }, fallback: raw)
    }

    static func removingAll() -> String {
        "[]"
    }

    private static func encode(_ events: [RecommendationFeedbackEvent], fallback: String) -> String {
        guard let data = try? JSONEncoder().encode(events) else { return fallback }
        return String(decoding: data, as: UTF8.self)
    }
}
