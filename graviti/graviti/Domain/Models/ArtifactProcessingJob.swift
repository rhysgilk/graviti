import Foundation

enum ArtifactProcessingJobKind: String, Codable, CaseIterable, Hashable {
    case linkMetadata
    case textExtraction
    case placeIdentification
    case enrichment
    case profileIndexing
    case thumbnailGeneration

    var currentVersion: Int {
        switch self {
        case .linkMetadata: 2
        case .textExtraction: 1
        case .placeIdentification: 2
        case .enrichment: 2
        case .profileIndexing: 1
        case .thumbnailGeneration: 1
        }
    }
}

enum ArtifactProcessingJobStatus: String, Codable, Hashable {
    case pending
    case running
    case waitingForRetry
    case completed
    case unavailable
    case cancelled
}

struct ArtifactProcessingJob: Codable, Hashable, Identifiable {
    let id: UUID
    let artifactID: UUID
    let kind: ArtifactProcessingJobKind
    var version: Int
    var status: ArtifactProcessingJobStatus
    var attemptCount: Int
    var lastError: String?
    var nextRetryAt: Date?
    var dependencyKinds: [ArtifactProcessingJobKind]
    let createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var updatedAt: Date
    var outputSummary: String?
    var outputProvenance: GeneratedDataProvenance?

    init(
        id: UUID = UUID(),
        artifactID: UUID,
        kind: ArtifactProcessingJobKind,
        version: Int? = nil,
        status: ArtifactProcessingJobStatus = .pending,
        attemptCount: Int = 0,
        lastError: String? = nil,
        nextRetryAt: Date? = nil,
        dependencyKinds: [ArtifactProcessingJobKind] = [],
        createdAt: Date = .now,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        updatedAt: Date = .now,
        outputSummary: String? = nil,
        outputProvenance: GeneratedDataProvenance? = nil
    ) {
        self.id = id
        self.artifactID = artifactID
        self.kind = kind
        self.version = version ?? kind.currentVersion
        self.status = status
        self.attemptCount = attemptCount
        self.lastError = lastError
        self.nextRetryAt = nextRetryAt
        self.dependencyKinds = dependencyKinds
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.updatedAt = updatedAt
        self.outputSummary = outputSummary
        self.outputProvenance = outputProvenance
    }

    func dependenciesAreComplete(in jobs: [ArtifactProcessingJob]) -> Bool {
        dependencyKinds.allSatisfy { dependency in
            jobs.contains {
                $0.artifactID == artifactID && $0.kind == dependency &&
                    [.completed, .unavailable].contains($0.status)
            }
        }
    }

    func isReady(at date: Date, in jobs: [ArtifactProcessingJob]) -> Bool {
        guard dependenciesAreComplete(in: jobs) else { return false }
        return switch status {
        case .pending: true
        case .waitingForRetry: nextRetryAt.map { $0 <= date } ?? true
        case .running, .completed, .unavailable, .cancelled: false
        }
    }
}

enum ProcessingRetryPolicy {
    static let maximumAttempts = 6

    static func nextRetryDate(after attemptCount: Int, now: Date = .now) -> Date? {
        guard attemptCount < maximumAttempts else { return nil }
        let delays: [TimeInterval] = [2, 5, 15, 60, 5 * 60, 30 * 60]
        return now.addingTimeInterval(delays[min(max(0, attemptCount - 1), delays.count - 1)])
    }
}
