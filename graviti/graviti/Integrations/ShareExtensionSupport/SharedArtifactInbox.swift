import Foundation

struct SharedArtifactEnvelope: Codable {
    let id: UUID
    let sourceURL: String?
    let originalText: String?
    let userNote: String?
    let mediaKey: String?
    let capturedAt: Date
}

enum SharedMediaStore {
    static func store(_ data: Data, id: UUID, fileExtension: String) throws -> String {
        guard !data.isEmpty, data.count <= 50_000_000,
              ["jpg", "jpeg", "png", "heic", "heif", "webp", "gif"].contains(fileExtension.lowercased()) else {
            throw MediaStoreError.unsupportedImage
        }
        let key = "\(id.uuidString).\(fileExtension.lowercased())"
        let destination = try mediaDirectory().appendingPathComponent(key)
        try data.write(to: destination, options: .atomic)
        return key
    }

    static func url(for key: String) throws -> URL {
        guard key == URL(fileURLWithPath: key).lastPathComponent,
              !key.contains("..") else { throw MediaStoreError.unsupportedImage }
        return try mediaDirectory().appendingPathComponent(key)
    }

    static func remove(_ key: String) throws {
        try FileManager.default.removeItem(at: url(for: key))
    }

    private static func mediaDirectory() throws -> URL {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedArtifactInbox.groupIdentifier
        ) else { throw MediaStoreError.unavailable }
        let directory = container.appendingPathComponent("MediaAssets", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private enum MediaStoreError: LocalizedError {
    case unsupportedImage
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unsupportedImage: "This image format or size isn't supported yet."
        case .unavailable: "Graviti's local media storage is unavailable."
        }
    }
}

enum SharedArtifactInbox {
    static let groupIdentifier = "group.com.rhysgilk.graviti"

    static func enqueue(_ envelope: SharedArtifactEnvelope) throws {
        let directory = try inboxDirectory()
        let fileURL = directory.appendingPathComponent(envelope.id.uuidString).appendingPathExtension("json")
        try JSONEncoder().encode(envelope).write(to: fileURL, options: .atomic)
    }

    static func pendingFiles() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: inboxDirectory(),
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "json" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static func read(_ fileURL: URL) throws -> SharedArtifactEnvelope {
        try JSONDecoder().decode(SharedArtifactEnvelope.self, from: Data(contentsOf: fileURL))
    }

    static func remove(_ fileURL: URL) throws {
        try FileManager.default.removeItem(at: fileURL)
    }

    private static func inboxDirectory() throws -> URL {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupIdentifier
        ) else {
            throw InboxError.unavailable
        }
        let directory = container.appendingPathComponent("IncomingArtifacts", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

struct SharedArtifactInboxClient {
    let pendingFiles: () throws -> [URL]
    let read: (URL) throws -> SharedArtifactEnvelope
    let remove: (URL) throws -> Void

    static let live = SharedArtifactInboxClient(
        pendingFiles: SharedArtifactInbox.pendingFiles,
        read: SharedArtifactInbox.read,
        remove: SharedArtifactInbox.remove
    )
}

private enum InboxError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "Graviti's shared save storage is unavailable."
    }
}
