import Foundation

struct SharedArtifactEnvelope: Codable {
    let id: UUID
    let sourceURL: String?
    let originalText: String?
    let userNote: String?
    let capturedAt: Date
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

private enum InboxError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "Graviti's shared save storage is unavailable."
    }
}
