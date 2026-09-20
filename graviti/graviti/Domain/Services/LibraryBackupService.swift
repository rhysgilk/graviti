import Foundation

struct LibraryBackupArchive: Codable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let exportedAt: Date
    let artifacts: [LibraryBackupEntry]
}

struct LibraryBackupEntry: Codable {
    let artifact: Artifact
    let mediaData: Data?
    let mediaFileExtension: String?
}

struct LibraryRestoreSummary {
    let imported: Int
    let duplicates: Int
}

enum LibraryBackupService {
    static func encode(
        _ artifacts: [Artifact],
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
            artifacts: entries
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
        guard archive.schemaVersion == LibraryBackupArchive.currentSchemaVersion,
              archive.artifacts.count <= 100_000 else {
            throw LibraryBackupError.unsupportedVersion
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
        return archive
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
