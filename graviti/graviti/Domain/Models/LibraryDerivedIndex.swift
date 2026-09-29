import Foundation

struct LibraryDerivedIndex: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var sourceFingerprint: String
    var placeToArtifactIDs: [String: [UUID]]
    var destinationToPlaceIDs: [String: [String]]
    var interestToArtifactIDs: [String: [UUID]]
    var guideToArtifactIDs: [String: [UUID]]
    var processingStateToArtifactIDs: [String: [UUID]]
    var searchTermToArtifactIDs: [String: [UUID]]
    var builtAt: Date

    static let empty = LibraryDerivedIndex(
        schemaVersion: currentSchemaVersion,
        sourceFingerprint: "",
        placeToArtifactIDs: [:],
        destinationToPlaceIDs: [:],
        interestToArtifactIDs: [:],
        guideToArtifactIDs: [:],
        processingStateToArtifactIDs: [:],
        searchTermToArtifactIDs: [:],
        builtAt: .distantPast
    )

    func candidateArtifactIDs(for query: String) -> Set<UUID> {
        let terms = Self.tokens(in: query)
        guard !terms.isEmpty else { return [] }
        let matches = terms.map { term -> Set<UUID> in
            Set(searchTermToArtifactIDs.lazy
                .filter { key, _ in key.hasPrefix(term) || key.contains(term) }
                .flatMap(\.value))
        }
        return matches.dropFirst().reduce(matches.first ?? []) { $0.intersection($1) }
    }

    static func build(
        from artifacts: [Artifact],
        guideMemberships: [FitGuideMembership] = [],
        now: Date = .now
    ) -> LibraryDerivedIndex {
        var place = [String: Set<UUID>]()
        var destination = [String: Set<String>]()
        var interest = [String: Set<UUID>]()
        var guide = [String: Set<UUID>]()
        var processing = [String: Set<UUID>]()
        var search = [String: Set<UUID>]()

        for artifact in artifacts {
            if let savedPlace = artifact.place {
                place[savedPlace.id, default: []].insert(artifact.id)
                for area in [savedPlace.locality, savedPlace.region, savedPlace.country].compactMap({ $0 }) {
                    destination[normalized(area), default: []].insert(savedPlace.id)
                }
            }
            for name in artifact.effectiveInterests {
                interest[normalized(name), default: []].insert(artifact.id)
            }
            processing[artifact.processingState.rawValue, default: []].insert(artifact.id)
            processing["metadata:\(artifact.linkMetadataState.rawValue)", default: []].insert(artifact.id)
            processing["text:\(artifact.textExtractionState.rawValue)", default: []].insert(artifact.id)
            processing["enrichment:\(artifact.enrichmentState.rawValue)", default: []].insert(artifact.id)

            let searchable = [
                LibrarySearchEngine.title(for: artifact), artifact.sourceURL, artifact.userNote,
                artifact.extractedText, artifact.linkMetadata?.title, artifact.linkMetadata?.summary,
                artifact.linkMetadata?.siteName, artifact.effectiveSummary,
                artifact.effectiveCategory?.displayName, artifact.place?.name, artifact.place?.subtitle
            ].compactMap { $0 } + artifact.effectiveInterests + artifact.sourceCollectionTitles
            for token in tokens(in: searchable.joined(separator: " ")) {
                search[token, default: []].insert(artifact.id)
            }
        }
        for membership in guideMemberships {
            guide[membership.guideID, default: []].insert(membership.artifactID)
        }

        return LibraryDerivedIndex(
            schemaVersion: currentSchemaVersion,
            sourceFingerprint: fingerprint(artifacts: artifacts, memberships: guideMemberships),
            placeToArtifactIDs: sortedUUIDMap(place),
            destinationToPlaceIDs: destination.mapValues { $0.sorted() },
            interestToArtifactIDs: sortedUUIDMap(interest),
            guideToArtifactIDs: sortedUUIDMap(guide),
            processingStateToArtifactIDs: sortedUUIDMap(processing),
            searchTermToArtifactIDs: sortedUUIDMap(search),
            builtAt: now
        )
    }

    private static func fingerprint(artifacts: [Artifact], memberships: [FitGuideMembership]) -> String {
        let artifactPart = artifacts.sorted { $0.id.uuidString < $1.id.uuidString }.map {
            "\($0.id.uuidString):\($0.processingState.rawValue):\($0.place?.id ?? "-"):\($0.enrichment?.generatedAt.timeIntervalSince1970 ?? 0)"
        }.joined(separator: "|")
        let membershipPart = memberships.sorted { $0.id < $1.id }.map(\.id).joined(separator: "|")
        return "\(artifacts.count)-\(memberships.count)-\(stableHash(artifactPart + "#" + membershipPart))"
    }

    private static func stableHash(_ value: String) -> String {
        // FNV-1a is sufficient for cache invalidation and deterministic across launches.
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }

    private static func sortedUUIDMap(_ source: [String: Set<UUID>]) -> [String: [UUID]] {
        source.mapValues { $0.sorted { $0.uuidString < $1.uuidString } }
    }

    fileprivate static func tokens(in value: String) -> Set<String> {
        Set(value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count > 1 })
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
