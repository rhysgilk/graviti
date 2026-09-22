import Foundation

struct AppDiagnosticsReport: Equatable {
    let appVersion: String
    let buildNumber: String
    let operatingSystem: String
    let deviceFamily: String
    let savedItemCount: Int
    let distinctPlaceCount: Int
    let needsReviewCount: Int
    let failedProcessingCount: Int
    let pendingProcessingCount: Int
    let photoCount: Int
    let backupSchemaVersion: Int
    let destinationCatalogVersion: String

    init(
        artifacts: [Artifact],
        appVersion: String,
        buildNumber: String,
        operatingSystem: String,
        deviceFamily: String,
        backupSchemaVersion: Int = LibraryBackupArchive.currentSchemaVersion,
        destinationCatalogVersion: String = DestinationKnowledgeCatalogLoader.bundled.catalogVersion
    ) {
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.operatingSystem = operatingSystem
        self.deviceFamily = deviceFamily
        savedItemCount = artifacts.count
        distinctPlaceCount = Set(artifacts.compactMap { $0.place?.id }).count
        needsReviewCount = artifacts.filter { $0.processingState == .needsReview }.count
        failedProcessingCount = artifacts.filter { $0.processingState == .failed }.count
        pendingProcessingCount = artifacts.filter {
            $0.processingState == .saved || $0.processingState == .processing
        }.count
        photoCount = artifacts.filter { $0.kind == .photo }.count
        self.backupSchemaVersion = backupSchemaVersion
        self.destinationCatalogVersion = destinationCatalogVersion
    }

    var text: String {
        """
        Graviti diagnostics
        App: \(appVersion) (\(buildNumber))
        OS: \(operatingSystem)
        Device family: \(deviceFamily)
        Backup schema: \(backupSchemaVersion)
        Destination catalog: \(destinationCatalogVersion)
        Saved items: \(savedItemCount)
        Distinct places: \(distinctPlaceCount)
        Needs review: \(needsReviewCount)
        Processing pending: \(pendingProcessingCount)
        Processing failed: \(failedProcessingCount)
        Photos and screenshots: \(photoCount)

        This report contains aggregate counts only. It excludes saved names, links, notes, media, coordinates, and identifiers.
        """
    }
}
