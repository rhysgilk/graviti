import Foundation

struct FitGuideRecord: Codable, Hashable, Identifiable {
    let id: String
    let destinationID: String
    var destinationName: String
    var country: String
    var searchSpan: Double
    var interests: [String]
    let createdAt: Date
    var updatedAt: Date

    init(guide: FitGuide, id: String? = nil, createdAt: Date = .now) {
        self.id = id ?? guide.id
        destinationID = guide.destination.id
        destinationName = guide.destination.name
        country = guide.destination.country
        searchSpan = guide.destination.searchSpan
        interests = guide.interests
        self.createdAt = createdAt
        updatedAt = createdAt
    }

    var guide: FitGuide {
        FitGuide(
            id: id,
            destination: SavedDestination(name: destinationName, country: country, searchSpan: searchSpan),
            interests: interests
        )
    }
}

struct FitGuideMembership: Codable, Hashable, Identifiable {
    let guideID: String
    let artifactID: UUID
    var interest: String?
    let addedAt: Date

    var id: String { "\(guideID)|\(artifactID.uuidString)" }
}

struct FitGuideLibraryState: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var guides: [FitGuideRecord]
    var memberships: [FitGuideMembership]

    static let empty = FitGuideLibraryState(
        schemaVersion: currentSchemaVersion,
        guides: [],
        memberships: []
    )

    private enum CodingKeys: String, CodingKey { case schemaVersion, guides, memberships }

    init(schemaVersion: Int, guides: [FitGuideRecord], memberships: [FitGuideMembership]) {
        self.schemaVersion = schemaVersion
        self.guides = guides
        self.memberships = memberships
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        guides = try values.decodeIfPresent([FitGuideRecord].self, forKey: .guides) ?? []
        memberships = try values.decodeIfPresent([FitGuideMembership].self, forKey: .memberships) ?? []
    }
}

enum FitGuideLibraryStore {
    static func decode(_ raw: String) -> FitGuideLibraryState {
        guard let data = raw.data(using: .utf8),
              let state = try? JSONDecoder().decode(FitGuideLibraryState.self, from: data),
              state.schemaVersion == FitGuideLibraryState.currentSchemaVersion else { return .empty }
        return state
    }

    static func encode(_ state: FitGuideLibraryState, fallback: String = "") -> String {
        guard let data = try? JSONEncoder().encode(state) else { return fallback }
        return String(decoding: data, as: UTF8.self)
    }

    static func guides(in raw: String) -> [FitGuide] {
        decode(raw).guides.map(\.guide)
    }

    @discardableResult
    static func ensureGuide(_ guide: FitGuide, in raw: inout String) -> FitGuideRecord {
        var state = decode(raw)
        if let index = state.guides.firstIndex(where: { $0.id == guide.id }) {
            state.guides[index].destinationName = guide.destination.name
            state.guides[index].country = guide.destination.country
            state.guides[index].searchSpan = guide.destination.searchSpan
            if !guide.interests.isEmpty { state.guides[index].interests = guide.interests }
            state.guides[index].updatedAt = .now
            raw = encode(state, fallback: raw)
            return state.guides[index]
        }
        let record = FitGuideRecord(guide: guide)
        state.guides.append(record)
        raw = encode(state, fallback: raw)
        return record
    }

    static func migrateLegacyMemberships(for guide: FitGuide, artifacts: [Artifact], in raw: inout String) {
        var state = decode(raw)
        if !state.guides.contains(where: { $0.id == guide.id }) {
            state.guides.append(FitGuideRecord(guide: guide))
        }
        let existingArtifactIDs = Set(state.memberships.filter { $0.guideID == guide.id }.map(\.artifactID))
        var changed = false
        for artifact in artifacts where guide.contains(artifact) && !existingArtifactIDs.contains(artifact.id) {
            let interest = guide.interests.first { artifact.sourceCollectionTitles.contains(guide.collectionTitle(for: $0)) }
            state.memberships.append(FitGuideMembership(
                guideID: guide.id,
                artifactID: artifact.id,
                interest: interest,
                addedAt: artifact.capturedAt
            ))
            changed = true
        }
        if changed || raw.isEmpty { raw = encode(state, fallback: raw) }
    }

    static func addMembership(guideID: String, artifactID: UUID, interest: String?, to raw: inout String) {
        var state = decode(raw)
        if let index = state.memberships.firstIndex(where: { $0.guideID == guideID && $0.artifactID == artifactID }) {
            state.memberships[index].interest = interest ?? state.memberships[index].interest
        } else {
            state.memberships.append(FitGuideMembership(
                guideID: guideID,
                artifactID: artifactID,
                interest: interest,
                addedAt: .now
            ))
        }
        raw = encode(state, fallback: raw)
    }

    static func removeMembership(guideID: String, artifactID: UUID, from raw: inout String) {
        var state = decode(raw)
        state.memberships.removeAll { $0.guideID == guideID && $0.artifactID == artifactID }
        raw = encode(state, fallback: raw)
    }

    static func restoreMembership(_ membership: FitGuideMembership, in raw: inout String) {
        var state = decode(raw)
        guard !state.memberships.contains(where: { $0.guideID == membership.guideID && $0.artifactID == membership.artifactID }) else { return }
        state.memberships.append(membership)
        raw = encode(state, fallback: raw)
    }

    static func memberships(for guideID: String, in raw: String) -> [FitGuideMembership] {
        decode(raw).memberships.filter { $0.guideID == guideID }
    }

    static func duplicate(guide: FitGuide, in raw: inout String) -> FitGuide {
        var state = decode(raw)
        let duplicateID = UUID().uuidString.lowercased()
        let duplicate = FitGuide(id: duplicateID, destination: guide.destination, interests: guide.interests)
        state.guides.append(FitGuideRecord(guide: duplicate))
        let sourceMemberships = state.memberships.filter { $0.guideID == guide.id }
        state.memberships.append(contentsOf: sourceMemberships.map {
            FitGuideMembership(
                guideID: duplicateID,
                artifactID: $0.artifactID,
                interest: $0.interest,
                addedAt: .now
            )
        })
        raw = encode(state, fallback: raw)
        return duplicate
    }
}
