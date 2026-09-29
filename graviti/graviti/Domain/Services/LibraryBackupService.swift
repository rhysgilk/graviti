import Foundation

struct LibraryBackupArchive: Codable {
    static let currentSchemaVersion = 4
    static let supportedSchemaVersions = 1...4

    let schemaVersion: Int
    let exportedAt: Date
    let artifacts: [LibraryBackupEntry]
    let preferences: LibraryBackupPreferences?

    init(
        schemaVersion: Int,
        exportedAt: Date,
        artifacts: [LibraryBackupEntry],
        preferences: LibraryBackupPreferences? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.artifacts = artifacts
        self.preferences = preferences
    }
}

struct LibraryBackupPreferences: Codable, Equatable {
    let recommendationRegion: String
    let preferredInterests: [String]
    let avoidedInterests: [String]
    let savedDestinationIDs: [String]
    let excludedDestinationIDs: [String]
    let visitedLikedDestinationIDs: [String]
    let visitedNotFitDestinationIDs: [String]
    let fitGuideLibraryJSON: String
    let fitGuideMetadataJSON: String
    let recommendationFeedbackJSON: String
    let recommendationOutcomesJSON: String
    let recommendationPromptsJSON: String
    let importAttemptsJSON: String
    let savedLibraryFiltersJSON: String

    init(
        recommendationRegion: String,
        preferredInterests: [String],
        avoidedInterests: [String],
        savedDestinationIDs: [String],
        excludedDestinationIDs: [String],
        visitedLikedDestinationIDs: [String] = [],
        visitedNotFitDestinationIDs: [String] = [],
        fitGuideLibraryJSON: String = "",
        fitGuideMetadataJSON: String = "",
        recommendationFeedbackJSON: String = "",
        recommendationOutcomesJSON: String = "",
        recommendationPromptsJSON: String = "",
        importAttemptsJSON: String = "",
        savedLibraryFiltersJSON: String = ""
    ) {
        self.recommendationRegion = recommendationRegion
        self.preferredInterests = Self.normalized(preferredInterests)
        self.avoidedInterests = Self.normalized(avoidedInterests)
        self.savedDestinationIDs = Self.normalized(savedDestinationIDs)
        self.excludedDestinationIDs = Self.normalized(excludedDestinationIDs)
        let notFit = Self.normalized(visitedNotFitDestinationIDs)
        let notFitSet = Set(notFit)
        self.visitedLikedDestinationIDs = Self.normalized(visitedLikedDestinationIDs)
            .filter { !notFitSet.contains($0) }
        self.visitedNotFitDestinationIDs = notFit
        self.fitGuideLibraryJSON = fitGuideLibraryJSON
        self.fitGuideMetadataJSON = fitGuideMetadataJSON
        self.recommendationFeedbackJSON = recommendationFeedbackJSON
        self.recommendationOutcomesJSON = recommendationOutcomesJSON
        self.recommendationPromptsJSON = recommendationPromptsJSON
        self.importAttemptsJSON = importAttemptsJSON
        self.savedLibraryFiltersJSON = savedLibraryFiltersJSON
    }

    private enum CodingKeys: String, CodingKey {
        case recommendationRegion
        case preferredInterests
        case avoidedInterests
        case savedDestinationIDs
        case excludedDestinationIDs
        case visitedLikedDestinationIDs
        case visitedNotFitDestinationIDs
        case fitGuideLibraryJSON, fitGuideMetadataJSON, recommendationFeedbackJSON
        case recommendationOutcomesJSON, recommendationPromptsJSON, importAttemptsJSON, savedLibraryFiltersJSON
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            recommendationRegion: try container.decode(String.self, forKey: .recommendationRegion),
            preferredInterests: try container.decode([String].self, forKey: .preferredInterests),
            avoidedInterests: try container.decode([String].self, forKey: .avoidedInterests),
            savedDestinationIDs: try container.decode([String].self, forKey: .savedDestinationIDs),
            excludedDestinationIDs: try container.decode([String].self, forKey: .excludedDestinationIDs),
            visitedLikedDestinationIDs: try container.decodeIfPresent([String].self, forKey: .visitedLikedDestinationIDs) ?? [],
            visitedNotFitDestinationIDs: try container.decodeIfPresent([String].self, forKey: .visitedNotFitDestinationIDs) ?? [],
            fitGuideLibraryJSON: try container.decodeIfPresent(String.self, forKey: .fitGuideLibraryJSON) ?? "",
            fitGuideMetadataJSON: try container.decodeIfPresent(String.self, forKey: .fitGuideMetadataJSON) ?? "",
            recommendationFeedbackJSON: try container.decodeIfPresent(String.self, forKey: .recommendationFeedbackJSON) ?? "",
            recommendationOutcomesJSON: try container.decodeIfPresent(String.self, forKey: .recommendationOutcomesJSON) ?? "",
            recommendationPromptsJSON: try container.decodeIfPresent(String.self, forKey: .recommendationPromptsJSON) ?? "",
            importAttemptsJSON: try container.decodeIfPresent(String.self, forKey: .importAttemptsJSON) ?? "",
            savedLibraryFiltersJSON: try container.decodeIfPresent(String.self, forKey: .savedLibraryFiltersJSON) ?? ""
        )
    }

    private static func normalized(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
            .sorted()
    }
}

struct LibraryBackupEntry: Codable {
    let artifact: Artifact
    let mediaData: Data?
    let mediaFileExtension: String?
}

struct LibraryRestoreSummary {
    let imported: Int
    let duplicates: Int
    let preferences: LibraryBackupPreferences?
}

enum LibraryBackupService {
    static func encode(
        _ artifacts: [Artifact],
        preferences: LibraryBackupPreferences? = nil,
        mediaLoader: (String) throws -> Data = { key in
            try Data(contentsOf: SharedMediaStore.url(for: key), options: .mappedIfSafe)
        }
    ) throws -> Data {
        let entries = try artifacts.map { artifact in
            guard let mediaKey = artifact.mediaKey else {
                return LibraryBackupEntry(artifact: artifact, mediaData: nil, mediaFileExtension: nil)
            }
            let mediaData = try mediaLoader(mediaKey)
            guard !mediaData.isEmpty, mediaData.count <= 50_000_000 else {
                throw LibraryBackupError.invalidMedia
            }
            let fileExtension = URL(fileURLWithPath: mediaKey).pathExtension.lowercased()
            guard !fileExtension.isEmpty else { throw LibraryBackupError.invalidMedia }
            return LibraryBackupEntry(
                artifact: artifact,
                mediaData: mediaData,
                mediaFileExtension: fileExtension
            )
        }
        let archive = LibraryBackupArchive(
            schemaVersion: LibraryBackupArchive.currentSchemaVersion,
            exportedAt: .now,
            artifacts: entries,
            preferences: preferences
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(archive)
    }

    static func decode(_ data: Data) throws -> LibraryBackupArchive {
        guard !data.isEmpty, data.count <= 500_000_000 else { throw LibraryBackupError.invalidFile }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let archive: LibraryBackupArchive
        do {
            archive = try decoder.decode(LibraryBackupArchive.self, from: data)
        } catch {
            throw LibraryBackupError.invalidFile
        }
        guard LibraryBackupArchive.supportedSchemaVersions.contains(archive.schemaVersion),
              archive.artifacts.count <= 100_000 else {
            throw LibraryBackupError.unsupportedVersion
        }
        if archive.schemaVersion == 1, archive.preferences != nil {
            throw LibraryBackupError.invalidFile
        }
        let normalizedPreferences = archive.preferences.map {
            LibraryBackupPreferences(
                recommendationRegion: $0.recommendationRegion,
                preferredInterests: $0.preferredInterests,
                avoidedInterests: $0.avoidedInterests,
                savedDestinationIDs: $0.savedDestinationIDs,
                excludedDestinationIDs: $0.excludedDestinationIDs,
                visitedLikedDestinationIDs: $0.visitedLikedDestinationIDs,
                visitedNotFitDestinationIDs: $0.visitedNotFitDestinationIDs,
                fitGuideLibraryJSON: $0.fitGuideLibraryJSON,
                fitGuideMetadataJSON: $0.fitGuideMetadataJSON,
                recommendationFeedbackJSON: $0.recommendationFeedbackJSON,
                recommendationOutcomesJSON: $0.recommendationOutcomesJSON,
                recommendationPromptsJSON: $0.recommendationPromptsJSON,
                importAttemptsJSON: $0.importAttemptsJSON,
                savedLibraryFiltersJSON: $0.savedLibraryFiltersJSON
            )
        }
        if archive.schemaVersion < 3,
           let preferences = normalizedPreferences,
           !preferences.visitedLikedDestinationIDs.isEmpty || !preferences.visitedNotFitDestinationIDs.isEmpty {
            throw LibraryBackupError.invalidFile
        }
        if archive.schemaVersion < 4,
           let preferences = normalizedPreferences,
           (!preferences.fitGuideLibraryJSON.isEmpty
            || !preferences.fitGuideMetadataJSON.isEmpty
            || !preferences.recommendationFeedbackJSON.isEmpty
            || !preferences.recommendationOutcomesJSON.isEmpty
            || !preferences.recommendationPromptsJSON.isEmpty
            || !preferences.importAttemptsJSON.isEmpty
            || !preferences.savedLibraryFiltersJSON.isEmpty) {
            throw LibraryBackupError.invalidFile
        }
        if let preferences = archive.preferences, let normalizedPreferences {
            guard RecommendationRegion(rawValue: preferences.recommendationRegion) != nil,
                  preferences.preferredInterests.count <= 100,
                  preferences.avoidedInterests.count <= 100,
                  preferences.savedDestinationIDs.count <= 1_000,
                  preferences.excludedDestinationIDs.count <= 1_000,
                  preferences.visitedLikedDestinationIDs.count <= 1_000,
                  preferences.visitedNotFitDestinationIDs.count <= 1_000,
                  appStateIsValid(normalizedPreferences),
                  allValuesAreSafe(normalizedPreferences.preferredInterests),
                  allValuesAreSafe(normalizedPreferences.avoidedInterests),
                  allValuesAreSafe(normalizedPreferences.savedDestinationIDs),
                  allValuesAreSafe(normalizedPreferences.excludedDestinationIDs),
                  allValuesAreSafe(normalizedPreferences.visitedLikedDestinationIDs),
                  allValuesAreSafe(normalizedPreferences.visitedNotFitDestinationIDs) else {
                throw LibraryBackupError.invalidFile
            }
        }
        guard Set(archive.artifacts.map { $0.artifact.id }).count == archive.artifacts.count else {
            throw LibraryBackupError.invalidFile
        }
        for entry in archive.artifacts {
            if entry.artifact.mediaKey != nil {
                guard let media = entry.mediaData, !media.isEmpty, media.count <= 50_000_000,
                      let fileExtension = entry.mediaFileExtension, !fileExtension.isEmpty else {
                    throw LibraryBackupError.invalidMedia
                }
            } else if entry.mediaData != nil || entry.mediaFileExtension != nil {
                throw LibraryBackupError.invalidMedia
            }
        }
        return LibraryBackupArchive(
            schemaVersion: archive.schemaVersion,
            exportedAt: archive.exportedAt,
            artifacts: archive.artifacts,
            preferences: normalizedPreferences
        )
    }

    private static func allValuesAreSafe(_ values: [String]) -> Bool {
        values.allSatisfy { !$0.isEmpty && $0.count <= 200 }
    }

    private static func appStateIsValid(_ preferences: LibraryBackupPreferences) -> Bool {
        let values = [
            preferences.fitGuideLibraryJSON,
            preferences.fitGuideMetadataJSON,
            preferences.recommendationFeedbackJSON,
            preferences.recommendationOutcomesJSON,
            preferences.recommendationPromptsJSON,
            preferences.importAttemptsJSON,
            preferences.savedLibraryFiltersJSON
        ]
        guard values.allSatisfy({ $0.utf8.count <= 2_000_000 }) else { return false }
        guard validJSON(preferences.fitGuideLibraryJSON, as: FitGuideLibraryState.self),
              validJSON(preferences.fitGuideMetadataJSON, as: [String: FitGuideMetadata].self),
              validJSON(preferences.recommendationFeedbackJSON, as: [RecommendationFeedbackEvent].self),
              validJSON(preferences.recommendationOutcomesJSON, as: [RecommendationOutcomeEvent].self),
              validJSON(preferences.recommendationPromptsJSON, as: [RecommendationPromptRecord].self),
              validJSON(preferences.importAttemptsJSON, as: [ImportAttempt].self),
              validJSON(preferences.savedLibraryFiltersJSON, as: [SavedLibraryFilter].self) else { return false }
        return true
    }

    private static func validJSON<T: Decodable>(_ raw: String, as type: T.Type) -> Bool {
        raw.isEmpty || (raw.data(using: .utf8).flatMap { try? JSONDecoder().decode(type, from: $0) } != nil)
    }
}

enum LibraryBackupError: LocalizedError {
    case invalidFile
    case unsupportedVersion
    case invalidMedia

    var errorDescription: String? {
        switch self {
        case .invalidFile: String(localized: "This isn't a valid Graviti backup.")
        case .unsupportedVersion: String(localized: "This backup was created by an unsupported version of Graviti.")
        case .invalidMedia: String(localized: "A saved photo is missing or invalid, so the backup can't be completed safely.")
        }
    }
}
