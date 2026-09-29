import Foundation

struct ProcessingJobStore {
    private struct Archive: Codable {
        static let currentSchemaVersion = 1
        var schemaVersion: Int
        var jobs: [ArtifactProcessingJob]
    }

    private let fileURL: URL?
    private var memoryJobs: [ArtifactProcessingJob]

    init(fileURL: URL? = nil, initialJobs: [ArtifactProcessingJob] = []) {
        self.fileURL = fileURL
        self.memoryJobs = initialJobs
    }

    static func live() -> ProcessingJobStore {
        let manager = FileManager.default
        let base = manager.containerURL(forSecurityApplicationGroupIdentifier: SharedArtifactInbox.groupIdentifier)
            ?? manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let directory = base?.appendingPathComponent("GravitiProcessing", isDirectory: true)
        if let directory { try? manager.createDirectory(at: directory, withIntermediateDirectories: true) }
        return ProcessingJobStore(fileURL: directory?.appendingPathComponent("jobs.json"))
    }

    mutating func load() throws -> [ArtifactProcessingJob] {
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return memoryJobs }
        let archive = try JSONDecoder().decode(Archive.self, from: Data(contentsOf: fileURL))
        guard archive.schemaVersion == Archive.currentSchemaVersion else {
            throw ProcessingJobStoreError.unsupportedSchema
        }
        memoryJobs = archive.jobs
        return memoryJobs
    }

    @discardableResult
    mutating func reconcile(with artifacts: [Artifact], now: Date = .now) throws -> [ArtifactProcessingJob] {
        var jobs = try load()
        let artifactIDs = Set(artifacts.map(\.id))
        jobs.removeAll { !artifactIDs.contains($0.artifactID) }

        // A terminated process cannot still own a running job. Preserve its attempt
        // history and make it eligible for bounded retry on the next activation.
        for index in jobs.indices where jobs[index].status == .running {
            jobs[index].status = .waitingForRetry
            jobs[index].lastError = jobs[index].lastError ?? "Interrupted before completion"
            jobs[index].nextRetryAt = now
            jobs[index].updatedAt = now
        }

        for artifact in artifacts {
            for specification in Self.specifications(for: artifact) {
                if let index = jobs.firstIndex(where: {
                    $0.artifactID == artifact.id && $0.kind == specification.kind
                }) {
                    jobs[index].dependencyKinds = specification.dependencies
                    if jobs[index].version < specification.kind.currentVersion {
                        jobs[index].version = specification.kind.currentVersion
                        jobs[index].status = .pending
                        jobs[index].attemptCount = 0
                        jobs[index].lastError = nil
                        jobs[index].nextRetryAt = nil
                        jobs[index].completedAt = nil
                        jobs[index].updatedAt = now
                    } else if specification.isComplete {
                        jobs[index].status = specification.isUnavailable ? .unavailable : .completed
                        jobs[index].nextRetryAt = nil
                        jobs[index].completedAt = jobs[index].completedAt ?? now
                        jobs[index].updatedAt = now
                    } else if [.completed, .unavailable].contains(jobs[index].status) {
                        // The authoritative Artifact changed after this job finished.
                        // Reopen only the affected derived work and retain its history.
                        jobs[index].status = .pending
                        jobs[index].lastError = nil
                        jobs[index].nextRetryAt = nil
                        jobs[index].completedAt = nil
                        jobs[index].updatedAt = now
                    }
                } else {
                    jobs.append(ArtifactProcessingJob(
                        artifactID: artifact.id,
                        kind: specification.kind,
                        status: specification.isComplete
                            ? (specification.isUnavailable ? .unavailable : .completed)
                            : .pending,
                        dependencyKinds: specification.dependencies,
                        createdAt: artifact.capturedAt,
                        completedAt: specification.isComplete ? now : nil,
                        updatedAt: now
                    ))
                }
            }
        }
        try persist(jobs)
        return jobs
    }

    mutating func markRunning(artifactID: UUID, kind: ArtifactProcessingJobKind, now: Date = .now) throws {
        try mutate(artifactID: artifactID, kind: kind) { job in
            job.status = .running
            job.attemptCount += 1
            job.startedAt = now
            job.completedAt = nil
            job.lastError = nil
            job.nextRetryAt = nil
            job.updatedAt = now
        }
    }

    mutating func markCompleted(
        artifactID: UUID,
        kind: ArtifactProcessingJobKind,
        unavailable: Bool = false,
        outputSummary: String? = nil,
        outputProvenance: GeneratedDataProvenance? = nil,
        now: Date = .now
    ) throws {
        try mutate(artifactID: artifactID, kind: kind) { job in
            job.status = unavailable ? .unavailable : .completed
            job.lastError = nil
            job.nextRetryAt = nil
            job.completedAt = now
            job.updatedAt = now
            job.outputSummary = outputSummary
            job.outputProvenance = outputProvenance
        }
    }

    mutating func markFailed(
        artifactID: UUID,
        kind: ArtifactProcessingJobKind,
        error: Error,
        now: Date = .now
    ) throws {
        try mutate(artifactID: artifactID, kind: kind) { job in
            job.lastError = error.localizedDescription
            job.nextRetryAt = ProcessingRetryPolicy.nextRetryDate(after: job.attemptCount, now: now)
            job.status = job.nextRetryAt == nil ? .cancelled : .waitingForRetry
            job.updatedAt = now
        }
    }

    mutating func markPending(artifactID: UUID, kind: ArtifactProcessingJobKind, now: Date = .now) throws {
        try mutate(artifactID: artifactID, kind: kind) { job in
            job.status = .pending
            job.attemptCount = 0
            job.lastError = nil
            job.nextRetryAt = nil
            job.completedAt = nil
            job.updatedAt = now
        }
    }

    mutating func removeJobs(for artifactIDs: Set<UUID>) throws {
        var jobs = try load()
        jobs.removeAll { artifactIDs.contains($0.artifactID) }
        try persist(jobs)
    }

    private mutating func mutate(
        artifactID: UUID,
        kind: ArtifactProcessingJobKind,
        change: (inout ArtifactProcessingJob) -> Void
    ) throws {
        var jobs = try load()
        guard let index = jobs.firstIndex(where: { $0.artifactID == artifactID && $0.kind == kind }) else {
            return
        }
        change(&jobs[index])
        try persist(jobs)
    }

    private mutating func persist(_ jobs: [ArtifactProcessingJob]) throws {
        memoryJobs = jobs.sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            if $0.artifactID != $1.artifactID { return $0.artifactID.uuidString < $1.artifactID.uuidString }
            return $0.kind.rawValue < $1.kind.rawValue
        }
        guard let fileURL else { return }
        let archive = Archive(schemaVersion: Archive.currentSchemaVersion, jobs: memoryJobs)
        try JSONEncoder().encode(archive).write(to: fileURL, options: .atomic)
    }

    private struct Specification {
        let kind: ArtifactProcessingJobKind
        let dependencies: [ArtifactProcessingJobKind]
        let isComplete: Bool
        let isUnavailable: Bool
    }

    private static func specifications(for artifact: Artifact) -> [Specification] {
        var values = [Specification]()
        if artifact.kind == .url, artifact.sourceURL != nil {
            values.append(Specification(
                kind: .linkMetadata,
                dependencies: [],
                isComplete: [.processed, .unavailable].contains(artifact.linkMetadataState),
                isUnavailable: artifact.linkMetadataState == .unavailable
            ))
        }
        if artifact.kind == .photo, artifact.mediaKey != nil {
            values.append(Specification(
                kind: .textExtraction,
                dependencies: [],
                isComplete: [.processed, .unavailable].contains(artifact.textExtractionState),
                isUnavailable: artifact.textExtractionState == .unavailable
            ))
        }
        if ArtifactProcessingCoordinator.isPlaceResolutionSource(artifact) || artifact.place != nil {
            let dependencies: [ArtifactProcessingJobKind] = ArtifactProcessingCoordinator.isSocialPlaceResolutionSource(artifact)
                ? [.linkMetadata] : []
            values.append(Specification(
                kind: .placeIdentification,
                dependencies: dependencies,
                isComplete: artifact.place != nil || [.processed, .needsReview].contains(artifact.processingState),
                isUnavailable: artifact.place == nil && artifact.processingState == .processed
            ))
        }
        let enrichmentDependencies: [ArtifactProcessingJobKind] = {
            var result = [ArtifactProcessingJobKind]()
            if artifact.kind == .url, artifact.sourceURL != nil { result.append(.linkMetadata) }
            if artifact.kind == .photo, artifact.mediaKey != nil { result.append(.textExtraction) }
            if ArtifactProcessingCoordinator.isPlaceResolutionSource(artifact) || artifact.place != nil {
                result.append(.placeIdentification)
            }
            return result
        }()
        let hasEnrichmentInput = artifact.place != nil || artifact.originalText != nil ||
            artifact.userNote != nil || artifact.extractedText != nil || artifact.linkMetadata != nil
        let isCollectionLink: Bool
        if let sourceURL = artifact.sourceURL {
            isCollectionLink = MapLinkMetadata.isCollectionLink(sourceURL)
        } else {
            isCollectionLink = false
        }
        let canEnrich = hasEnrichmentInput && !isCollectionLink
        let enrichmentTerminal = [.processed, .unavailable].contains(artifact.enrichmentState) || !canEnrich
        values.append(Specification(
            kind: .enrichment,
            dependencies: enrichmentDependencies,
            isComplete: enrichmentTerminal,
            isUnavailable: artifact.enrichmentState == .unavailable || !canEnrich
        ))
        values.append(Specification(
            kind: .profileIndexing,
            dependencies: [.enrichment],
            isComplete: false,
            isUnavailable: false
        ))
        let thumbnailAvailable = artifact.mediaKey != nil || artifact.linkMetadata?.imageData != nil
        let thumbnailTerminal = thumbnailAvailable || artifact.kind == .manual ||
            [.processed, .unavailable].contains(artifact.linkMetadataState)
        values.append(Specification(
            kind: .thumbnailGeneration,
            dependencies: artifact.kind == .url ? [.linkMetadata] : [],
            isComplete: thumbnailTerminal,
            isUnavailable: !thumbnailAvailable && thumbnailTerminal
        ))
        return values
    }
}

private enum ProcessingJobStoreError: LocalizedError {
    case unsupportedSchema

    var errorDescription: String? {
        String(localized: "The saved processing queue was created by a newer version of Graviti.")
    }
}
