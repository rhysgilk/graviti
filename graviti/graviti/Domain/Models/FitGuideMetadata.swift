import Foundation

struct FitGuideMetadata: Codable, Hashable {
    var customTitle: String?
    var note: String
    var archived: Bool
    var coverArtifactID: UUID?
    var shortlistPlaceIDs: [String]
    var orderedArtifactIDs: [UUID]
    var updatedAt: Date

    static let empty = FitGuideMetadata(
        customTitle: nil,
        note: "",
        archived: false,
        coverArtifactID: nil,
        shortlistPlaceIDs: [],
        orderedArtifactIDs: [],
        updatedAt: .distantPast
    )

    private enum CodingKeys: String, CodingKey {
        case customTitle, note, archived, coverArtifactID, shortlistPlaceIDs, orderedArtifactIDs, updatedAt
    }

    init(
        customTitle: String?,
        note: String,
        archived: Bool,
        coverArtifactID: UUID?,
        shortlistPlaceIDs: [String],
        orderedArtifactIDs: [UUID],
        updatedAt: Date
    ) {
        self.customTitle = customTitle
        self.note = note
        self.archived = archived
        self.coverArtifactID = coverArtifactID
        self.shortlistPlaceIDs = shortlistPlaceIDs
        self.orderedArtifactIDs = orderedArtifactIDs
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        customTitle = try values.decodeIfPresent(String.self, forKey: .customTitle)
        note = try values.decodeIfPresent(String.self, forKey: .note) ?? ""
        archived = try values.decodeIfPresent(Bool.self, forKey: .archived) ?? false
        coverArtifactID = try values.decodeIfPresent(UUID.self, forKey: .coverArtifactID)
        shortlistPlaceIDs = try values.decodeIfPresent([String].self, forKey: .shortlistPlaceIDs) ?? []
        orderedArtifactIDs = try values.decodeIfPresent([UUID].self, forKey: .orderedArtifactIDs) ?? []
        updatedAt = try values.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .distantPast
    }
}

enum FitGuideMetadataStore {
    static func decode(_ data: Data) -> [String: FitGuideMetadata] {
        (try? JSONDecoder().decode([String: FitGuideMetadata].self, from: data)) ?? [:]
    }

    static func metadata(for guideID: String, in data: Data) -> FitGuideMetadata {
        decode(data)[guideID] ?? .empty
    }

    static func update(_ metadata: FitGuideMetadata, for guideID: String, in data: inout Data) {
        var all = decode(data)
        all[guideID] = metadata
        data = (try? JSONEncoder().encode(all)) ?? data
    }
}

extension String {
    var trimmedNil: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
