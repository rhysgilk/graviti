import SwiftUI

struct ImportInboxView: View {
    @ObservedObject var library: ArtifactLibrary
    @AppStorage("import.attempts.v1") private var importAttemptsJSON = ""

    private var importedArtifacts: [Artifact] {
        library.artifacts.filter { artifact in
            artifact.kind == .url || artifact.kind == .photo || artifact.sourceCollectionTitle != nil
        }
    }

    private var attempts: [ImportAttempt] {
        ImportAttemptStore.decode(importAttemptsJSON).sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        Group {
            if importedArtifacts.isEmpty && attempts.isEmpty {
                ContentUnavailableView(
                    "Import Inbox is clear",
                    systemImage: "tray",
                    description: Text("Links, photos, and shared items appear here while Graviti finds their places and details.")
                )
            } else {
                List {
                    Section {
                        Label("New imports appear immediately. You can keep using Graviti while place matching and details finish in the background.", systemImage: "bolt.horizontal.circle")
                            .font(GravitiTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(ImportInboxState.allCases) { state in
                        let items = importedArtifacts.filter { ImportInboxState.classify($0) == state }
                        let stateAttempts = attempts.filter { ImportInboxState.classify($0) == state }
                        if !items.isEmpty || !stateAttempts.isEmpty {
                            Section(state.title) {
                                ForEach(stateAttempts) { attempt in
                                    ImportAttemptRow(attempt: attempt, state: state)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            if state.isRetryable,
                                               attempt.sourceURL != nil,
                                               [.appleGuide, .googleList].contains(attempt.kind) {
                                                Button("Retry", systemImage: "arrow.clockwise") {
                                                    Task { await retry(attempt) }
                                                }
                                                .tint(GravitiColors.iris)
                                            }
                                            Button("Remove", systemImage: "xmark") {
                                                ImportAttemptStore.remove(attempt.id, from: &importAttemptsJSON)
                                            }
                                            .tint(.secondary)
                                        }
                                }
                                ForEach(items) { artifact in
                                    NavigationLink {
                                        SavedArtifactDetailView(artifact: artifact, library: library)
                                    } label: {
                                        ImportInboxRow(artifact: artifact, state: state)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        if state.isRetryable {
                                            Button("Retry", systemImage: "arrow.clockwise") {
                                                Task {
                                                    if artifact.processingState == .failed {
                                                        await library.retryProcessing(artifact.id)
                                                    } else if artifact.linkMetadataState == .failed {
                                                        await library.retryLinkMetadata(artifact.id)
                                                    } else if artifact.textExtractionState == .failed {
                                                        await library.retryTextExtraction(artifact.id)
                                                    } else {
                                                        await library.refreshEnrichment(artifact.id)
                                                    }
                                                }
                                            }
                                            .tint(GravitiColors.iris)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    @MainActor
    private func retry(_ attempt: ImportAttempt) async {
        guard let sourceURL = attempt.sourceURL else { return }
        ImportAttemptStore.markProcessing(attempt.id, in: &importAttemptsJSON)
        do {
            switch attempt.kind {
            case .appleGuide:
                let summary = try await library.importAppleGuidePlaces(from: sourceURL)
                ImportAttemptStore.completing(
                    attempt.id,
                    title: summary.title,
                    imported: summary.imported,
                    refreshed: summary.refreshed,
                    duplicates: summary.duplicates,
                    skipped: summary.skipped,
                    in: &importAttemptsJSON
                )
            case .googleList:
                let summary = try await library.importGoogleMapsListPlaces(from: sourceURL)
                ImportAttemptStore.completing(
                    attempt.id,
                    title: summary.title,
                    imported: summary.imported,
                    refreshed: summary.refreshed,
                    duplicates: summary.duplicates,
                    skipped: summary.skipped,
                    in: &importAttemptsJSON
                )
            case .csv, .mapsFile:
                break
            }
        } catch {
            ImportAttemptStore.failing(attempt.id, message: error.localizedDescription, in: &importAttemptsJSON)
        }
    }
}

@MainActor
private enum ImportInboxState: String, CaseIterable, Identifiable {
    case processing, placeFound, needsHelp, couldntIdentify, duplicate, retryAvailable, imported

    var id: Self { self }
    var title: String {
        switch self {
        case .processing: String(localized: "Processing")
        case .placeFound: String(localized: "Place found")
        case .needsHelp: String(localized: "Needs help")
        case .couldntIdentify: String(localized: "Couldn't identify a place")
        case .duplicate: String(localized: "Duplicate")
        case .retryAvailable: String(localized: "Retry available")
        case .imported: String(localized: "Imported successfully")
        }
    }
    var symbol: String {
        switch self {
        case .processing: "hourglass"
        case .placeFound: "mappin.and.ellipse"
        case .needsHelp: "questionmark.bubble.fill"
        case .couldntIdentify: "mappin.slash"
        case .duplicate: "square.on.square"
        case .retryAvailable: "arrow.clockwise.circle.fill"
        case .imported: "checkmark.circle.fill"
        }
    }
    var isRetryable: Bool { self == .retryAvailable }

    static func classify(_ artifact: Artifact) -> Self {
        if artifact.processingState == .failed || artifact.linkMetadataState == .failed ||
            artifact.textExtractionState == .failed || artifact.enrichmentState == .failed { return .retryAvailable }
        if artifact.processingState == .processing || artifact.linkMetadataState == .processing ||
            artifact.textExtractionState == .processing || artifact.enrichmentState == .processing { return .processing }
        if artifact.processingState == .needsReview { return .needsHelp }
        if artifact.place != nil && artifact.enrichmentState != .processed { return .placeFound }
        if artifact.processingState == .processed && artifact.place == nil &&
            artifact.sourceURL.map(MapLinkMetadata.isCollectionLink) != true { return .couldntIdentify }
        return .imported
    }

    static func classify(_ attempt: ImportAttempt) -> Self {
        switch attempt.status {
        case .processing: .processing
        case .imported: .imported
        case .duplicate: .duplicate
        case .failed: .retryAvailable
        }
    }
}

private struct ImportAttemptRow: View {
    let attempt: ImportAttempt
    let state: ImportInboxState

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: state.symbol)
                .font(.title3)
                .foregroundStyle(state == .duplicate ? GravitiColors.opportunityCoral : GravitiColors.signalMint)
                .frame(width: 42, height: 42)
                .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 4) {
                Text(attempt.displayTitle?.trimmedNil ?? attempt.originalLabel)
                    .font(GravitiTypography.headline)
                    .lineLimit(2)
                Text(summary)
                    .font(GravitiTypography.captionSemibold)
                    .foregroundStyle(.secondary)
                if let message = attempt.message {
                    Text(message)
                        .font(GravitiTypography.caption)
                        .foregroundStyle(GravitiColors.opportunityCoral)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }

    private var summary: String {
        switch attempt.status {
        case .processing:
            String(localized: "Processing")
        case .duplicate:
            String(localized: "\(attempt.duplicates) duplicates · nothing added")
        case .failed:
            String(localized: "Retry available")
        case .imported:
            String(localized: "\(attempt.imported) imported · \(attempt.refreshed) refreshed · \(attempt.duplicates) duplicates")
        }
    }
}

private struct ImportInboxRow: View {
    let artifact: Artifact
    let state: ImportInboxState

    var body: some View {
        HStack(spacing: 12) {
            ArtifactThumbnailView(artifact: artifact)
            VStack(alignment: .leading, spacing: 4) {
                Text(artifact.place?.name ?? LibrarySearchEngine.title(for: artifact))
                    .font(GravitiTypography.headline)
                    .lineLimit(2)
                Label(state.title, systemImage: state.symbol)
                    .font(GravitiTypography.captionSemibold)
                    .foregroundStyle([.needsHelp, .couldntIdentify, .retryAvailable].contains(state) ? GravitiColors.opportunityCoral : GravitiColors.signalMint)
                if let source = artifact.sourceURL.flatMap({ URL(string: $0)?.host(percentEncoded: false) }) {
                    Text(source).font(GravitiTypography.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 5)
    }
}
