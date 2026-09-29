import Foundation

struct LibraryDerivedIndexStore {
    private let fileURL: URL?
    private(set) var index: LibraryDerivedIndex

    init(fileURL: URL? = nil, initialIndex: LibraryDerivedIndex? = nil) {
        self.fileURL = fileURL
        self.index = initialIndex ?? .empty
    }

    static func live() -> LibraryDerivedIndexStore {
        let manager = FileManager.default
        let base = manager.containerURL(forSecurityApplicationGroupIdentifier: SharedArtifactInbox.groupIdentifier)
            ?? manager.urls(for: .cachesDirectory, in: .userDomainMask).first
        let directory = base?.appendingPathComponent("GravitiDerived", isDirectory: true)
        if let directory { try? manager.createDirectory(at: directory, withIntermediateDirectories: true) }
        return LibraryDerivedIndexStore(fileURL: directory?.appendingPathComponent("library-index.json"))
    }

    mutating func load() -> LibraryDerivedIndex {
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(LibraryDerivedIndex.self, from: data),
              decoded.schemaVersion == LibraryDerivedIndex.currentSchemaVersion else {
            return index
        }
        index = decoded
        return decoded
    }

    @discardableResult
    mutating func rebuild(from artifacts: [Artifact], guideLibraryJSON: String = "") throws -> LibraryDerivedIndex {
        let memberships = FitGuideLibraryStore.decode(guideLibraryJSON).memberships
        let rebuilt = LibraryDerivedIndex.build(from: artifacts, guideMemberships: memberships)
        index = rebuilt
        if let fileURL {
            try JSONEncoder().encode(rebuilt).write(to: fileURL, options: .atomic)
        }
        return rebuilt
    }

    mutating func removePersistedIndex() throws {
        index = .empty
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}
