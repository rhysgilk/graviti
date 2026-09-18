import SwiftUI

struct SavedArtifactDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let artifact: Artifact
    @ObservedObject var library: ArtifactLibrary
    @State private var showingPlaceReview = false
    @State private var actionError: String?
    @State private var isImportingGuide = false
    @State private var guideImportMessage: String?
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false

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
                    Text(sourceURL)
                        .font(.body)
                        .textSelection(.enabled)
                        .foregroundStyle(.white)

                    if MapLinkMetadata.isCollectionLink(sourceURL) {
                        Text(MapLinkMetadata.provider(for: sourceURL) == .google
                             ? "This saves the list link. To add each place, import its Google Saved CSV from the Save tab."
                             : "Import the places in this Apple Maps guide into your Library.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.68))

                        if MapLinkMetadata.provider(for: sourceURL) == .apple {
                            Button {
                                isImportingGuide = true
                                guideImportMessage = nil
                                Task {
                                    defer { isImportingGuide = false }
                                    do {
                                        let summary = try await library.importAppleGuidePlaces(from: sourceURL)
                                        guideImportMessage = "\(summary.title): \(summary.imported) places imported, \(summary.skipped) skipped."
                                    } catch {
                                        guideImportMessage = error.localizedDescription
                                    }
                                }
                            } label: {
                                if isImportingGuide {
                                    ProgressView("Importing guide")
                                } else {
                                    Label("Import guide places", systemImage: "square.and.arrow.down")
                                }
                            }
                            .disabled(isImportingGuide)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 14))
                        }

                        if let guideImportMessage {
                            Text(guideImportMessage)
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
                        Text("Your note")
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
        if current.kind == .photo { return "Photo" }
        guard current.kind == .url else { return "Note" }
        if let sourceURL = current.sourceURL,
           let provider = MapLinkMetadata.provider(for: sourceURL) {
            return provider.displayName
        }
        return "Link"
    }

    private var deletionMessage: String {
        if isCollectionSave {
            return "This removes the guide or list link. Places already imported from it remain saved."
        }
        return "This removes the save from your Library and updates its place and Gravity."
    }

    private var isCollectionSave: Bool {
        guard let sourceURL = current.sourceURL else { return false }
        return MapLinkMetadata.isCollectionLink(sourceURL)
    }
}
