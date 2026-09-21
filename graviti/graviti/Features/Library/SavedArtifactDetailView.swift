import SwiftUI

struct SavedArtifactDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let artifact: Artifact
    @ObservedObject var library: ArtifactLibrary
    @State private var showingPlaceReview = false
    @State private var actionError: String?
    @State private var isImportingCollection = false
    @State private var collectionImportMessage: String?
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var isRefreshingDetails = false
    @State private var showingDetailsEditor = false

    private var current: Artifact {
        library.artifacts.first(where: { $0.id == artifact.id }) ?? artifact
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Label(sourceLabel, systemImage: current.kind == .url ? "link" : (current.kind == .photo ? "photo" : "note.text"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GravitiColors.signalMint)

                if let mediaKey = current.mediaKey {
                    MediaPreviewView(mediaKey: mediaKey, maximumPixelSize: 1400)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }

                if let sourceURL = current.sourceURL {
                    if let url = openableURL(sourceURL) {
                        LinkPreviewView(url: url, cachedMetadata: current.linkMetadata)
                    }

                    Text(sourceURL)
                        .font(.body)
                        .textSelection(.enabled)
                        .foregroundStyle(.white)

                    if let provider = collectionProvider {
                        Text(provider == .google
                             ? String(localized: "Import or refresh every place from this Google Maps list.")
                             : String(localized: "Import or refresh every place from this Apple Maps guide."))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.68))

                        Button {
                            Task { await importCollectionPlaces(from: sourceURL, provider: provider) }
                        } label: {
                            if isImportingCollection {
                                ProgressView("Importing places")
                            } else {
                                Label("Import or refresh places", systemImage: "square.and.arrow.down")
                            }
                        }
                        .disabled(isImportingCollection)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 14))

                        if let collectionImportMessage {
                            Text(collectionImportMessage)
                                .font(.subheadline)
                                .foregroundStyle(GravitiColors.signalMint)
                        }
                    }

                    if let url = openableURL(sourceURL) {
                        Link(destination: url) {
                            Label("Open original", systemImage: "arrow.up.right")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(GravitiColors.iris, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .foregroundStyle(.white)
                    }
                }

                if let originalText = current.originalText {
                    if current.kind == .url {
                        Text("Source title")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    Text(originalText)
                        .font(.body)
                        .textSelection(.enabled)
                        .foregroundStyle(.white)
                }

                if !current.sourceCollectionTitles.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Imported from")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.65))
                        ForEach(current.sourceCollectionTitles, id: \.self) { title in
                            Label(title, systemImage: "square.stack.3d.up")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }

                if current.kind == .photo {
                    detectedTextSection
                }

                if current.enrichment != nil || current.userDetails != nil {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("About this save")
                            .font(.headline)
                        if let summary = current.effectiveSummary {
                            Text(summary)
                                .font(.subheadline)
                                .textSelection(.enabled)
                        }
                        if let category = current.effectiveCategory {
                            Label(category.displayName, systemImage: "square.grid.2x2")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(GravitiColors.signalMint)
                        }
                        if !current.effectiveInterests.isEmpty {
                            Text(InterestDisplayName.joined(current.effectiveInterests))
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Text(detailsProvenance)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                        if current.userDetails == nil,
                           let evidence = current.enrichment?.interestEvidence,
                           !evidence.isEmpty {
                            DisclosureGroup("Why these interests") {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(evidence) { item in
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(InterestDisplayName.localized(item.interest))
                                                .font(.caption.weight(.semibold))
                                            Text("\(item.source.displayName) · \(Int((item.confidence * 100).rounded()))% confidence")
                                                .font(.caption2)
                                                .foregroundStyle(.white.opacity(0.58))
                                        }
                                    }
                                }
                                .padding(.top, 6)
                            }
                            .font(.caption.weight(.semibold))
                            .tint(GravitiColors.signalMint)
                        }
                        if current.enrichment != nil {
                            Button(isRefreshingDetails ? "Refreshing…" : "Refresh suggestions") {
                                isRefreshingDetails = true
                                Task {
                                    await library.refreshEnrichment(current.id)
                                    isRefreshingDetails = false
                                }
                            }
                            .disabled(isRefreshingDetails)
                            .font(.caption.weight(.semibold))
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 16))
                } else if let enrichmentStatus {
                    Label(enrichmentStatus.text, systemImage: enrichmentStatus.symbol)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 16))
                }

                Button("Edit description and interests") { showingDetailsEditor = true }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 14))

                if let place = current.place {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Place").font(.headline)
                        Text(place.name)
                        if !place.subtitle.isEmpty {
                            Text(place.subtitle).foregroundStyle(.white.opacity(0.68))
                        }
                        Button("Change place") { showingPlaceReview = true }
                            .font(.subheadline.weight(.semibold))
                            .padding(.top, 8)
                        Button("Remove place match") {
                            Task {
                                do {
                                    try await library.removePlaceMatch(from: current.id)
                                } catch {
                                    actionError = error.localizedDescription
                                }
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(GravitiColors.opportunityCoral)
                    }
                }

                if let actionError {
                    Text(actionError)
                        .font(.subheadline)
                        .foregroundStyle(GravitiColors.opportunityCoral)
                }

                if current.place == nil {
                    if current.kind == .photo {
                        Button("Add a place to this photo") { showingPlaceReview = true }
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 14))
                    } else if let sourceURL = current.sourceURL,
                              MapLinkMetadata.provider(for: sourceURL) != nil,
                              !MapLinkMetadata.isCollectionLink(sourceURL) {
                        placeStatus
                    } else if !isCollectionSave {
                        Button("Add a place to this save") { showingPlaceReview = true }
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 14))
                    }
                }

                if let userNote = current.userNote {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(current.kind == .photo ? "Your description" : "Your note")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.65))
                        Text(userNote)
                            .textSelection(.enabled)
                            .foregroundStyle(.white)
                    }
                }

                Text("Saved \(current.capturedAt, format: .dateTime.month().day().year())")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))

                Button(role: .destructive) { showingDeleteConfirmation = true } label: {
                    Label("Delete saved item", systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                }
                .disabled(isDeleting)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(GravitiColors.appBackground)
        .navigationTitle("Saved item")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPlaceReview) {
            PlaceReviewView(artifact: current, library: library)
        }
        .sheet(isPresented: $showingDetailsEditor) {
            SavedItemDetailsEditor(artifact: current, library: library)
        }
        .confirmationDialog(
            "Delete this saved item?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete saved item", role: .destructive) {
                isDeleting = true
                Task {
                    do {
                        try await library.deleteArtifact(current.id)
                        dismiss()
                    } catch {
                        actionError = error.localizedDescription
                        isDeleting = false
                    }
                }
            }
        } message: {
            Text(deletionMessage)
        }
    }

    @ViewBuilder
    private var placeStatus: some View {
        switch current.processingState {
        case .saved, .processing:
            Label("Finding this place", systemImage: "hourglass")
                .foregroundStyle(.white.opacity(0.68))
        case .needsReview, .failed:
            VStack(alignment: .leading, spacing: 10) {
                Text(current.processingState == .needsReview
                     ? "Choose the matching place"
                     : "Place lookup didn't finish")
                    .font(.headline)
                Button("Find matching place") { showingPlaceReview = true }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 14))
                Button("Retry lookup") {
                    Task { await library.retryProcessing(current.id) }
                }
                .font(.subheadline)
            }
        case .processed:
            EmptyView()
        }
    }

    private func openableURL(_ raw: String) -> URL? {
        guard let components = URLComponents(string: raw),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host != nil else {
            return nil
        }
        return components.url
    }

    private var sourceLabel: String {
        if current.kind == .photo { return String(localized: "Photo") }
        guard current.kind == .url else { return String(localized: "Note") }
        if let sourceURL = current.sourceURL,
           let provider = MapLinkMetadata.provider(for: sourceURL) {
            return provider.displayName
        }
        return String(localized: "Link")
    }

    private var detailsProvenance: String {
        guard current.userDetails == nil else { return String(localized: "Details edited by you") }
        let source = current.enrichment?.source.displayName ?? String(localized: "saved details")
        return String(localized: "Suggested from \(source)")
    }

    private var deletionMessage: String {
        if isCollectionSave {
            return String(localized: "This removes the guide or list link. Places already imported from it remain saved.")
        }
        return String(localized: "This removes the save from your Library and updates its place and Gravity.")
    }

    private var isCollectionSave: Bool {
        collectionProvider != nil
    }

    private var collectionProvider: MapLinkMetadata.Provider? {
        guard let sourceURL = current.sourceURL,
              let provider = MapLinkMetadata.provider(for: sourceURL),
              MapLinkMetadata.isCollectionLink(sourceURL) ||
                ArtifactProcessingCoordinator.isResolvedMapCollection(current) else { return nil }
        return provider
    }

    private func importCollectionPlaces(from sourceURL: String, provider: MapLinkMetadata.Provider) async {
        isImportingCollection = true
        collectionImportMessage = nil
        defer { isImportingCollection = false }

        do {
            switch provider {
            case .apple:
                let summary = try await library.importAppleGuidePlaces(from: sourceURL)
                collectionImportMessage = importMessage(
                    title: summary.title,
                    imported: summary.imported,
                    duplicates: summary.duplicates,
                    skipped: summary.skipped
                )
            case .google:
                let summary = try await library.importGoogleMapsListPlaces(from: sourceURL)
                collectionImportMessage = importMessage(
                    title: summary.title,
                    imported: summary.imported,
                    refreshed: summary.refreshed,
                    duplicates: summary.duplicates,
                    skipped: summary.skipped
                )
            }
        } catch {
            collectionImportMessage = error.localizedDescription
        }
    }

    private func importMessage(
        title: String,
        imported: Int,
        refreshed: Int = 0,
        duplicates: Int,
        skipped: Int
    ) -> String {
        let details = [
            GravitiCopy.imported(imported),
            refreshed > 0 ? GravitiCopy.placeDetailsRefreshed(refreshed) : nil,
            duplicates > 0 ? GravitiCopy.duplicatesAvoided(duplicates) : nil,
            skipped > 0 ? GravitiCopy.couldNotImport(skipped) : nil
        ].compactMap { $0 }.joined(separator: " · ")
        return "\(title): \(details)"
    }

    private var enrichmentStatus: (text: String, symbol: String)? {
        switch current.enrichmentState {
        case .pending, .processing:
            return (String(localized: "Learning about this save…"), "sparkles")
        case .failed:
            return (String(localized: "Details will be tried again later."), "arrow.clockwise")
        case .unavailable:
            return (String(localized: "Add a description or place to help Graviti understand this save."), "text.badge.plus")
        case .processed:
            return nil
        }
    }

    @ViewBuilder
    private var detectedTextSection: some View {
        if let extractedText = current.extractedText,
           let source = current.extractedTextSource {
            DisclosureGroup {
                Text(extractedText)
                    .font(.subheadline)
                    .textSelection(.enabled)
                    .foregroundStyle(.white.opacity(0.82))
                    .padding(.top, 8)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Label("Detected text", systemImage: "text.viewfinder")
                        .font(.subheadline.weight(.semibold))
                    Text(source.displayName)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))
                }
            }
            .tint(GravitiColors.signalMint)
            .padding(16)
            .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 16))
        } else {
            switch current.textExtractionState {
            case .pending, .processing:
                Label("Reading text in this image on device…", systemImage: "text.viewfinder")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
            case .failed:
                Button {
                    Task { await library.retryTextExtraction(current.id) }
                } label: {
                    Label("Try reading image text again", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                }
            case .unavailable:
                Label("No readable text was found in this image.", systemImage: "text.viewfinder")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.58))
            case .processed:
                EmptyView()
            }
        }
    }
}
