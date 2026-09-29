import Foundation

enum ImportAttemptKind: String, Codable, Hashable {
    case csv, mapsFile, appleGuide, googleList
}

enum ImportAttemptStatus: String, Codable, Hashable {
    case processing, imported, duplicate, failed
}

struct ImportAttempt: Codable, Hashable, Identifiable {
    let id: UUID
    let kind: ImportAttemptKind
    let originalLabel: String
    let sourceURL: String?
    var displayTitle: String?
    var status: ImportAttemptStatus
    var imported: Int
    var refreshed: Int
    var duplicates: Int
    var skipped: Int
    var message: String?
    let createdAt: Date
    var updatedAt: Date
}

enum ImportAttemptStore {
    static func decode(_ raw: String) -> [ImportAttempt] {
        guard let data = raw.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([ImportAttempt].self, from: data)) ?? []
    }

    static func beginning(
        kind: ImportAttemptKind,
        label: String,
        sourceURL: String? = nil,
        in raw: inout String
    ) -> UUID {
        let id = UUID()
        var attempts = decode(raw)
        attempts.append(ImportAttempt(
            id: id,
            kind: kind,
            originalLabel: label,
            sourceURL: sourceURL,
            displayTitle: nil,
            status: .processing,
            imported: 0,
            refreshed: 0,
            duplicates: 0,
            skipped: 0,
            message: nil,
            createdAt: .now,
            updatedAt: .now
        ))
        raw = encode(Array(attempts.suffix(200)), fallback: raw)
        return id
    }

    static func completing(
        _ id: UUID,
        title: String? = nil,
        imported: Int,
        refreshed: Int = 0,
        duplicates: Int,
        skipped: Int,
        in raw: inout String
    ) {
        update(id, in: &raw) { attempt in
            attempt.displayTitle = title
            attempt.imported = imported
            attempt.refreshed = refreshed
            attempt.duplicates = duplicates
            attempt.skipped = skipped
            attempt.status = imported + refreshed > 0 ? .imported : (duplicates > 0 ? .duplicate : .imported)
            attempt.message = skipped > 0 ? String(localized: "Some items could not be imported.") : nil
        }
    }

    static func failing(_ id: UUID, message: String, in raw: inout String) {
        update(id, in: &raw) { attempt in
            attempt.status = .failed
            attempt.message = message
        }
    }

    static func markProcessing(_ id: UUID, in raw: inout String) {
        update(id, in: &raw) { attempt in
            attempt.status = .processing
            attempt.message = nil
        }
    }

    static func remove(_ id: UUID, from raw: inout String) {
        raw = encode(decode(raw).filter { $0.id != id }, fallback: raw)
    }

    private static func update(_ id: UUID, in raw: inout String, mutation: (inout ImportAttempt) -> Void) {
        var attempts = decode(raw)
        guard let index = attempts.firstIndex(where: { $0.id == id }) else { return }
        mutation(&attempts[index])
        attempts[index].updatedAt = .now
        raw = encode(attempts, fallback: raw)
    }

    private static func encode(_ attempts: [ImportAttempt], fallback: String) -> String {
        guard let data = try? JSONEncoder().encode(attempts) else { return fallback }
        return String(decoding: data, as: UTF8.self)
    }
}
